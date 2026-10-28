import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/config/language_manager.dart';
import 'package:provider/provider.dart';

import '../../filesync/file_store.dart';

typedef NoteeAssetResolver = RecordAsset Function(String src);

/// Custom image block builder that resolves relative `assets/...` urls into
/// absolute local paths before rendering.  The original document node is
/// never mutated — resolution is purely render-time.
class NoteeImageBlockBuilder extends BlockComponentBuilder {
  NoteeImageBlockBuilder({
    super.configuration,
    required this.fileStore,
    required this.srcResolver,
  });

  final FileStore fileStore;
  final NoteeAssetResolver srcResolver;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NoteeImageBlockWidget(
      key: node.key,
      node: node,
      showActions: showActions(node),
      configuration: configuration,
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
      fileStore: fileStore,
      srcResolver: srcResolver,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class NoteeImageBlockWidget extends BlockComponentStatefulWidget {
  const NoteeImageBlockWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    required this.fileStore,
    required this.srcResolver,
  });

  final FileStore fileStore;
  final NoteeAssetResolver srcResolver;

  @override
  State<NoteeImageBlockWidget> createState() => _NoteeImageBlockState();
}

class _NoteeImageBlockState extends State<NoteeImageBlockWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final imageKey = GlobalKey();

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  late final editorState = Provider.of<EditorState>(context, listen: false);

  late RecordAsset _resolved;
  bool _isDownloading = false;
  bool _downloadError = false;

  OverlayEntry? _menuEntry;

  @override
  void initState() {
    super.initState();
    _resolveAndDownload();
  }

  @override
  void dispose() {
    _menuEntry?.remove();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NoteeImageBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      _resolveAndDownload();
    }
  }

  void _resolveAndDownload() {
    final rawSrc =
        widget.node.attributes[ImageBlockKeys.url] as String? ?? '';
    _resolved = widget.srcResolver(rawSrc);
    _isDownloading = false;
    _downloadError = false;
    if (_resolved.cachePath.isNotEmpty &&
        !File(_resolved.cachePath).existsSync()) {
      _isDownloading = true;
      _downloadAsset();
    }
  }

  Future<void> _downloadAsset() async {
    try {
      final ok = await widget.fileStore.downloadAsset(_resolved);
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = !ok;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = true;
        });
      }
    }
  }

  void _dismissMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _showImageMenu(Offset globalPosition) {
    _dismissMenu();
    if (!mounted) return;

    HapticFeedback.mediumImpact();

    final items = <List<ContextMenuItem>>[
      [
        ContextMenuItem(
          getName: () => l10n.delete,
          onPressed: (state) {
            final transaction = state.transaction..deleteNode(widget.node);
            state.apply(transaction);
            _dismissMenu();
          },
        ),
      ],
    ];

    _menuEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissMenu,
        child: Stack(
          children: [
            Positioned.fill(child: const SizedBox.expand()),
            ContextMenu(
              position: globalPosition,
              editorState: editorState,
              items: items,
              onPressed: _dismissMenu,
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_menuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final attributes = node.attributes;

    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );
    final width = attributes[ImageBlockKeys.width]?.toDouble() ??
        MediaQuery.of(context).size.width;
    final height = attributes[ImageBlockKeys.height]?.toDouble();

    Widget imageWidget;
    if (_isDownloading) {
      imageWidget = _buildLoading(width, height);
    } else if (_downloadError) {
      imageWidget = _buildError(width, height);
    } else {
      final displaySrc = _resolved.cachePath.isNotEmpty ? _resolved.cachePath : _resolved.src;
      imageWidget = ResizableImage(
        src: displaySrc,
        width: width,
        height: height,
        editable: editorState.editable,
        alignment: alignment,
        onResize: (w) {
          final transaction = editorState.transaction
            ..updateNode(node, {ImageBlockKeys.width: w});
          editorState.apply(transaction);
        },
      );
    }

    Widget child = Padding(key: imageKey, padding: padding, child: imageWidget);

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    // Absorb pointer events so the editor's selection gesture system never
    // fires collapsed/non-collapsed selections on this block node — the
    // editor_state setter guard also rejects them, but absorbing earlier
    // avoids any IME side-effects (keyboard pop-up etc).
    child = AbsorbPointer(child: child);

    // Wrap in GestureDetector to hook both desktop right-click and mobile
    // long-press to our independent context menu (no selection required).
    child = GestureDetector(
      onSecondaryTapUp: (details) => _showImageMenu(details.globalPosition),
      onLongPressStart: (details) => _showImageMenu(details.globalPosition),
      child: child,
    );

    child = Padding(padding: margin, child: child);
    return child;
  }

  Widget _buildLoading(double width, double? height) => SizedBox(
        width: width,
        height: height ?? width * 0.6,
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _buildError(double width, double? height) => SizedBox(
        width: width,
        height: height ?? width * 0.6,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
        ),
      );

  // --- SelectableMixin delegates ---

  @override
  Position start() => Position(path: widget.node.path);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final imageBox = imageKey.currentContext?.findRenderObject();
    if (imageBox is RenderBox) return Offset.zero & imageBox.size;
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(Position position,
      {bool shiftWithBaseOffset = false}) {
    if (_renderBox == null) return null;
    final size = _renderBox!.size;
    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }

  @override
  List<Rect> getRectsInSelection(Selection selection,
      {bool shiftWithBaseOffset = false}) {
    if (_renderBox == null) return [];
    final parentBox = context.findRenderObject();
    final imageBox = imageKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && imageBox is RenderBox) {
      return [
        imageBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            imageBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);
}
