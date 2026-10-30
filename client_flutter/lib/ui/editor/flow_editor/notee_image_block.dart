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
import '../../common/popup_menu.dart';
import 'notee_resizable_image.dart';

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

  @override
  void initState() {
    super.initState();
    _resolveAndDownload();
  }

  @override
  void dispose() {
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
    if (!mounted) return;

    HapticFeedback.mediumImpact();

    final popupItems = <PopupItem>[
      if (_sourceLocalFile != null)
        PopupItem(
          icon: const Icon(Icons.save_outlined, size: 18),
          label: l10n.save,
          onTap: () {
            unawaited(_saveImage());
          },
        ),
      PopupItem(
        icon: const Icon(Icons.delete_outline, size: 18),
        label: l10n.delete,
        onTap: () {
          final transaction = editorState.transaction..deleteNode(widget.node);
          editorState.apply(transaction);
        },
      ),
    ];

    showPopup(
      context: context,
      position: globalPosition,
      items: popupItems,
    );
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
      imageWidget = NoteeResizableImage(
        image: Image.file(File(_resolved.cachePath.isNotEmpty ? _resolved.cachePath : _resolved.src)),
        width: width,
        height: height,
        dragSensitivity: alignment == Alignment.center ? 2.0 : 1.0,
        editable: editorState.editable,
        onResize: (w) {
          final transaction = editorState.transaction..updateNode(node, {ImageBlockKeys.width: w});
          editorState.apply(transaction);
        },
        onLongPressStart: (details) => _showImageMenu(details.globalPosition),
        onSecondaryTapUp: (details) => _showImageMenu(details.globalPosition),
      );
    }
    imageWidget = Align(alignment: alignment, child: imageWidget);

    Widget child = Padding(
      padding: margin + padding,
      child: imageWidget,
    );
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
