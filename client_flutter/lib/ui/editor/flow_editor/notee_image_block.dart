import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/config/language_manager.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../filesync/file_store.dart';

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
    final dir = await FilePicker.getDirectoryPath();
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

  /// 将菜单位置限制在编辑器可见区域内（editor viewport bounds in screen space）。
  /// 同时处理左右/上下放不下时的自动翻转。
  Offset _clampToScreen(Offset position) {
    if (!mounted) return position;

    final editorBox = editorState.renderBox;
    if (editorBox == null) return position; // 拿不到就不 clamp

    // editor viewport 在屏幕坐标系下的可见矩形
    final editorRect = Rect.fromPoints(
      editorBox.localToGlobal(Offset.zero),
      editorBox.localToGlobal(editorBox.size.bottomRight(Offset.zero)),
    );

    const menuW = 160.0;
    const menuH = 90.0;
    const margin = 8.0;

    // 可用区域：editor 可见矩形 - 边距
    final availLeft = editorRect.left + margin;
    final availTop = editorRect.top + margin;
    final availRight = editorRect.right - margin;
    final availBottom = editorRect.bottom - margin;

    double dx, dy;

    // 水平：优先显示在点击位置左侧
    if (position.dx - menuW >= availLeft) {
      dx = position.dx - menuW;
    } else if (position.dx + margin + menuW <= availRight) {
      dx = position.dx; // 左侧放不下 → 翻到右侧
    } else {
      dx = position.dx.clamp(availLeft, availRight - menuW);
    }

    // 垂直：优先显示在点击位置上方
    if (position.dy - menuH >= availTop) {
      dy = position.dy - menuH;
    } else if (position.dy + margin + menuH <= availBottom) {
      dy = position.dy; // 上方放不下 → 翻到下方
    } else {
      dy = position.dy.clamp(availTop, availBottom - menuH);
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

    // AbsorbPointer 已内聚到 ResizableImage 内部（只包裹图片本体），
    // edge resize handles 需能收到 pointer 事件才能生效。

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
