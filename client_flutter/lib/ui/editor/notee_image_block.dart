import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/config/language_manager.dart';
import 'package:path/path.dart' as p;
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
      configuration: configuration,
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
    with BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

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

  /// Best-effort local source file for saving. Returns null when the image
  /// has not been downloaded yet (network URL without a cache file).
  File? get _sourceLocalFile {
    final cache = _resolved.cachePath;
    if (cache.isNotEmpty && File(cache).existsSync()) return File(cache);
    final src = _resolved.src;
    if (src.isNotEmpty && !src.startsWith('http') && File(src).existsSync()) {
      return File(src);
    }
    return null;
  }

  Future<void> _saveImage() async {
    final source = _sourceLocalFile;
    if (source == null) return;
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || dir.isEmpty) return; // user cancelled
    try {
      final destination = p.join(dir, p.basename(source.path));
      await source.copy(destination);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveRecordFailed)),
        );
      }
    }
  }

  void _showImageMenu(Offset globalPosition) {
    _dismissMenu();
    if (!mounted) return;

    HapticFeedback.mediumImpact();

    final items = <List<ContextMenuItem>>[
      [
        ContextMenuItem(
          getName: () => l10n.save,
          isApplicable: (_) => _sourceLocalFile != null,
          onPressed: (state) {
            _dismissMenu();
            unawaited(_saveImage());
          },
        ),
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

    // Clamp menu position inside screen bounds so it doesn't land off-screen
    // when the user long-presses near an edge.
    final menuPosition = _clampToScreen(globalPosition);

    _menuEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissMenu,
        child: Stack(
          children: [
            Positioned.fill(child: const SizedBox.expand()),
            ContextMenu(
              position: menuPosition,
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

  /// Prefer showing the menu to the LEFT of the finger, above the finger —
  /// mirroring how native iOS/Android long-press menus position themselves.
  /// Flip only when that side doesn't have enough room; if neither side fits,
  /// clamp to screen edge.
  Offset _clampToScreen(Offset position) {
    if (!mounted) return position;
    final size = MediaQuery.sizeOf(context);
    const menuW = 160.0;
    const menuH = 80.0;
    const margin = 8.0;

    // Horizontal: prefer left side (dx - menuW) if it fits
    double dx = margin;
    if (position.dx - menuW >= margin) {
      dx = position.dx - menuW; // default to LEFT of finger
    } else if (position.dx + menuW + margin <= size.width) {
      dx = position.dx; // left didn't fit → fall back to RIGHT
    } else {
      dx = position.dx.clamp(margin, size.width - menuW - margin); // neither → clamp
    }

    // Vertical: prefer above the finger (dy - menuH) if it fits
    double dy = margin;
    if (position.dy - menuH >= margin) {
      dy = position.dy - menuH; // default ABOVE finger
    } else if (position.dy + menuH + margin <= size.height) {
      dy = position.dy; // above didn't fit → fall back BELOW
    } else {
      dy = position.dy.clamp(margin, size.height - menuH - margin); // neither → clamp
    }

    return Offset(dx, dy);
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

    Widget child = Padding(padding: padding, child: imageWidget);

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
}
