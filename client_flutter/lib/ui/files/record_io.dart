// ============================================================================
// record_io.dart — Import + Export + supporting format helpers, all in one file.
//
// Four responsibilities, stacked top-to-bottom:
//   1. DocumentImage   — walk appflowy Document tree for image nodes (shared
//                        by import flow AND editor save flow).
//   2. DocumentIO      — pure-format helpers: encoding detection, body JSON ↔
//                        markdown, import-side image rewriting (takes a
//                        copyFile callback so it never touches disk).
//   3. RecordImport    — business glue: Repository + FileStore + FilePicker.
//   4. RecordExport    — business glue + progress dialog + password dialog.
//
// No file-picker, dialog, or RecordTree imports leak into DocumentImage /
// DocumentIO — the split between "pure format" and "business + UI" is sharp.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_utils.dart';
import 'package:notee/ui/editor/flow_editor/custom_code_block_parser.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/app_logger.dart';
import '../../utils/utils.dart';

// ============================================================================
// Part 1 — Document image node walking (pure format, no business deps)
// ============================================================================

class DocumentImage {
  /// Recursively walk [document] and collect every image node.  Collects into
  /// a list first so callers can safely mutate [node.attributes] while iterating
  /// (import flow rewrites URLs in place).
  static List<Node> collectImageNodes(Document document) {
    final nodes = <Node>[];
    void visit(Node node) {
      if (node.type == ImageBlockKeys.type) nodes.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }
    for (final child in document.root.children) {
      visit(child);
    }
    return nodes;
  }

  /// Collect bare filenames from every image node whose URL is a managed
  /// asset `assets/{uuid}/{filename}`.  The `assets/{uuid}/` prefix is
  /// stripped.  URLs pointing at http/https/ftp are skipped.
  static List<String> collectAssetNames(Document document, String uuid) {
    final names = <String>[];
    for (final node in collectImageNodes(document)) {
      final url = node.attributes[ImageBlockKeys.url] as String?;
      final filename = url != null ? extractAssetFilename(url) : null;
      if (filename != null) {
        names.add(filename);
      }
    }
    return names;
  }
}

// ============================================================================
// Part 2 — Format-level helpers (pure, no Repository / FileStore / UI)
// ============================================================================

class DocumentIO {
  /// Convert a stored body string (either appflowy document JSON or legacy
  /// plaintext) to markdown.  Returns null when [body] is empty.
  ///
  /// When [assetUuid] and [exportAssetDir] are set, every managed asset URL
  /// `assets/{assetUuid}/filename` inside the document is rewritten to
  /// `assets/filename` and the source file is copied into [exportAssetDir].
  /// Files are flat (no uuid sub-folder) — each export goes into its own
  /// record directory so filenames never collide across records.
  static String? bodyToMarkdown(
    String body, {
    String? assetUuid,
    String? exportAssetDir,
  }) {
    if (body.isEmpty) return null;
    final trimmed = body.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final doc = Document.fromJson(map);
        if (assetUuid != null && exportAssetDir != null) {
          _prepareAssetsForExport(doc, assetUuid, exportAssetDir);
        }
        return documentToMarkdown(doc);
      } catch (_) {
        // fall through → not valid JSON, treat as plaintext
      }
    }
    return body;
  }

  /// Copy managed assets referenced by [doc] from `assets/{assetUuid}/` into
  /// [exportAssetDir] and rewrite node URLs to `assets/{basename}`.
  static void _prepareAssetsForExport(Document doc, String assetUuid, String exportAssetDir) {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return;

    final srcDir = Directory(fileStore.getAssetDir(assetUuid));
    final destDir = Directory(exportAssetDir);

    for (final node in DocumentImage.collectImageNodes(doc)) {
      final url = node.attributes[ImageBlockKeys.url] as String?;
      final filename = url != null ? extractAssetFilename(url) : null;
      if (filename == null) continue;
      final srcFile = File(srcDir.path + Platform.pathSeparator + filename);
      if (!srcFile.existsSync()) continue;

      destDir.createSync(recursive: true);
      final destFile = File(destDir.path + Platform.pathSeparator + filename);
      try {
        srcFile.copySync(destFile.path);
        node.updateAttributes({ImageBlockKeys.url: './assets/$filename'});
      } catch (e) {
        AppLogger.e('Export', "asset copy failed $srcFile → $destFile: $e");
      }
    }
  }

  /// Serialize a Document to the JSON body string stored in notee files.
  static String documentToBody(Document document) => jsonEncode(document.toJson());

  /// Best-effort UTF-8 decode with GBK, gb2312, and latin-1 fallbacks.
  static Future<String> decodeBytes(Uint8List bytes) async {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return await CharsetConverter.decode('GBK', bytes);
      } catch (_) {
        try {
          return await CharsetConverter.decode('gb2312', bytes);
        } catch (_) {
          return latin1.decode(bytes);
        }
      }
    }
  }

  /// Walk every local relative image URL in [document] (not http/https/ftp,
  /// not already `assets/`) — copy the file into `assets/{uuid}/`, rewrite
  /// the node URL, and return the list of copied filenames.  Preserves
  /// original basenames; appends `_1`, `_2`, … only on collision.
  static Future<List<String>> rewriteImportImages({
    required Document document,
    required String sourceDir,
    required String uuid,
  }) async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return [];

    final rewrittenFilenames = <String>[];
    final taken = <String>{};
    final assetDir = Directory(fileStore.getAssetDir(uuid));
    await assetDir.create(recursive: true);

    String suggestName(String basename) {
      if (!taken.contains(basename)) {
        taken.add(basename);
        return basename;
      }
      final ext = p.extension(basename);
      final base = p.basenameWithoutExtension(basename);
      int i = 1;
      while (taken.contains('${base}_$i$ext')) {
        i++;
      }
      final name = '${base}_$i$ext';
      taken.add(name);
      return name;
    }

    for (final node in DocumentImage.collectImageNodes(document)) {
      final url = node.attributes['url'];
      if (url == null || url.isEmpty) continue;
      if (isRemoteUrl(url) || isNoteeAssetUrl(url)) continue;

      final decodedUrl = Uri.decodeFull(url);
      final absoluteSrc = p.normalize(p.join(sourceDir, decodedUrl));
      final srcFile = File(absoluteSrc);
      if (!srcFile.existsSync()) {
        AppLogger.w('Import', "image not found, skipping: $absoluteSrc");
        continue;
      }

      final name = suggestName(p.basename(absoluteSrc));
      final destFile = File(fileStore.getAssetPath(uuid, name));
      try {
        srcFile.copySync(destFile.path);
      } catch (e) {
        AppLogger.e('Import', "image copy failed $absoluteSrc → ${destFile.path}: $e");
        continue;
      }

      node.updateAttributes({ImageBlockKeys.url: buildAssetUrl(name)});
      rewrittenFilenames.add(name);
    }

    return rewrittenFilenames;
  }
}

// ============================================================================
// Part 3 — Import business glue (Repository + FileStore + FilePicker)
// ============================================================================

class RecordImport {
  /// Persist a parsed [document] as a new record under [folderPath].
  /// Creates the DB record first (to obtain a uuid), then walks the document
  /// copying local images into `assets/{uuid}/` and rewriting their URLs to
  /// the managed `assets/{uuid}/filename` form, then writes the work file.
  static Future<void> saveImportDocument(
    String folderPath,
    Document document, {
    required String sourceDir,
  }) async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return;

    String name = RecordUtils.getDocumentTitle(document);
    if (name.isEmpty) name = RecordUtils.generateRecordName();

    final record = await Repository.get().createRecord(
      folderPath, name, false, DateTime.now().millisecondsSinceEpoch,
    );
    if (record == null) return;

    try {
      final assetNames = await DocumentIO.rewriteImportImages(
        document: document,
        sourceDir: sourceDir,
        uuid: record.uuid,
      );

      final writeContent = RecordSections.buildNoteContent(
        assetNames, DocumentIO.documentToBody(document),
      );
      await fileStore.createWorkFile(record.uuid, writeContent);
    } catch (e) {
      AppLogger.e('Import', "saveImportDocument failed uuid=${record.uuid}: $e");
      await Repository.get().purgeUnsyncedRecord(record.uuid);
      rethrow;
    }
  }

  /// Pick one or more .md / .txt files and import each as a record.
  static Future<void> pickAndImportDocuments(
    BuildContext context,
    String folderPath,
  ) async {
    if (!context.mounted) return;
    int importCount = 0;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: ['md', 'txt'],
      );
      if (result == null) return;

      for (final file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;
        var bytes = file.bytes;
        bytes ??= await File(filePath).readAsBytes();
        final content = await DocumentIO.decodeBytes(bytes);
        if (content.isEmpty) continue;

        final ext = file.extension?.toLowerCase() ??
            p.extension(filePath).toLowerCase().replaceFirst('.', '');
        if (ext != 'md' && ext != 'txt') continue;

        final delta = markdownToDocument(
          content, markdownParsers: const [CustomMarkdownCodeBlockParser()],
        );
        await saveImportDocument(folderPath, delta, sourceDir: p.dirname(filePath));
        importCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n.importFailed} $e")),
        );
      }
    } finally {
      if (importCount > 0) Repository.get().syncRecords(false);
    }
  }

  /// Recursively import all `.md` / `.txt` files under a user-chosen folder,
  /// mirroring the on-disk relative path into the notee tree.  The picked
  /// folder's own basename becomes the top-level segment so the full subtree
  /// structure is preserved.
  static Future<void> pickAndImportFolder(
    BuildContext context,
    String folderPath,
  ) async {
    if (!context.mounted) return;
    final picked = await FilePicker.platform.getDirectoryPath();
    if (picked == null || picked.isEmpty) return;

    final rootDir = Directory(picked);
    if (!rootDir.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.importFailed}: $picked not found')),
        );
      }
      return;
    }

    final mdFiles = <File>[];
    await for (final entry in rootDir.list(recursive: true, followLinks: false)) {
      if (entry is File) {
        final ext = p.extension(entry.path).toLowerCase().replaceFirst('.', '');
        if (ext == 'md' || ext == 'txt') mdFiles.add(entry);
      }
    }
    if (mdFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importNoFiles)),
        );
      }
      return;
    }

    int importCount = 0;
    int skipped = 0;
    try {
      final rootName = p.basename(rootDir.path);
      final targetRoot = rootName.isNotEmpty
          ? (folderPath.endsWith('/') ? '$folderPath$rootName/' : '$folderPath/$rootName/')
          : folderPath;

      for (final file in mdFiles) {
        final relPath = p.relative(file.path, from: rootDir.path);
        final relDir = p.dirname(relPath);

        String noteeFolder = targetRoot;
        if (relDir != '.' && relDir.isNotEmpty) {
          final normalized = relDir.replaceAll('\\', '/');
          noteeFolder = targetRoot + (targetRoot.endsWith('/') ? '' : '/') + normalized;
          if (!noteeFolder.endsWith('/')) noteeFolder += '/';
        }

        await Repository.get().recordTree.createFolder(noteeFolder);

        final bytes = await file.readAsBytes();
        final content = await DocumentIO.decodeBytes(bytes);
        if (content.isEmpty) {
          skipped++;
          continue;
        }

        final delta = markdownToDocument(
          content, markdownParsers: const [CustomMarkdownCodeBlockParser()],
        );
        await saveImportDocument(noteeFolder, delta, sourceDir: p.dirname(file.path));
        importCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importCompleted(importCount, skipped))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n.importFailed} $e")),
        );
      }
    } finally {
      if (importCount > 0) Repository.get().syncRecords(false);
    }
  }
}

// ============================================================================
// Part 4 — Export (business glue + progress dialog + password dialog)
// ============================================================================

class RecordExport {
  /// Start export: pick destination folder, then show a progress dialog
  /// exporting every record under [folderPath] (recursive).
  static Future<void> start(BuildContext context, String folderPath) async {
    final root = normalizePath(folderPath);
    final files = Repository.get().recordTree.sortedFiles.where((f) {
      String p = f.path;
      if (!p.endsWith('/')) p += '/';
      return p.startsWith(root);
    }).toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportNoRecords)));
      return;
    }
    await startWithFiles(context, files, dirname(root));
  }

  /// Export a single record to markdown.
  static Future<void> startSingle(BuildContext context, TreeContentFile file) async {
    await startWithFiles(context, [file], file.path);
  }

  static Future<void> startWithFiles(
    BuildContext context,
    List<TreeContentFile> files,
    String root,
  ) async {
    final picked = await FilePicker.platform.getDirectoryPath(dialogTitle: l10n.exportSelectFolder);
    if (picked == null) return;

    String resolvedTarget;
    if (picked.startsWith('content://')) {
      final base = await getExternalStorageDirectory() ?? await getApplicationSupportDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
      resolvedTarget = p.join(base.path, 'notee_export', stamp);
    } else {
      resolvedTarget = picked;
    }

    final targetDir = Directory(resolvedTarget);
    try {
      await targetDir.create(recursive: true);
    } catch (e) {
      AppLogger.e('Export', "[RecordExport] cannot create target dir $resolvedTarget: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportFailed}: $e')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => _ExportProgressDialog(files: files, rootPath: root, targetDir: resolvedTarget),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

class _ExportProgressDialog extends StatefulWidget {
  final List<TreeContentFile> files;
  final String rootPath;
  final String targetDir;

  const _ExportProgressDialog({required this.files, required this.rootPath, required this.targetDir});

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  final Set<String> _writtenFiles = {};

  bool _finished = false;
  bool _cancelled = false;
  int _done = 0;
  int _success = 0;
  int _skipped = 0;
  TreeContentFile? _current;

  @override
  void initState() {
    super.initState();
    Timer.run(() => _run());
  }

  Future<void> _run() async {
    for (final file in widget.files) {
      if (_cancelled) break;
      setState(() => _current = file);

      String? content = await _readRecordFile(file);
      if (content == null || content.isEmpty) {
        _skipped++;
        _advance();
        continue;
      }
      final (_, body) = RecordSections.splitContent(content);

      String? plain;
      if (file.locked != 0) {
        if (!mounted) break;
        plain = await showDialog<String>(
          context: context,
          useRootNavigator: false,
          barrierDismissible: false,
          builder: (_) => _ExportPasswordDialog(file: file, encryptedRaw: body),
        );
        if (!mounted || plain == null) {
          _skipped++;
          _advance();
          continue;
        }
      } else {
        plain = body;
      }

      try {
        // Each record gets a flat assets/ sub-folder inside its own export
        // directory — collisions are impossible across records this way.
        final exportDir = _recordExportDir(file);
        final exportAssetDir = p.join(exportDir, 'assets');
        final markdown = DocumentIO.bodyToMarkdown(
          plain,
          assetUuid: file.uuid,
          exportAssetDir: exportAssetDir,
        ) ?? plain;
        await _writeFile(file, markdown);
        _success++;
      } catch (e) {
        AppLogger.e('Export', "[RecordExport] failed to export ${file.path}${file.name}: $e");
        _skipped++;
      }
      _advance();
    }

    if (mounted) setState(() => _finished = true);
  }

  void _advance() {
    _done++;
    if (mounted) setState(() {});
  }

  void _cancel() => setState(() => _cancelled = true);

  Future<String?> _readRecordFile(TreeContentFile record) async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return null;
    File file = File(fileStore.getWorkFile(record.uuid));
    if (record.version > 0 && !file.existsSync()) {
      file = File(fileStore.getBaseFile(record.uuid));
      if (!file.existsSync()) {
        await fileStore.downloadBaseFile(record.uuid);
      }
    }
    if (!file.existsSync()) return null;
    try {
      return await file.readAsString();
    } catch (e) {
      AppLogger.e('Export', "[RecordExport] read failed uuid=${record.uuid}: $e");
      return null;
    }
  }

  Future<void> _writeFile(TreeContentFile file, String markdown) async {
    final out = File(_mdCandidate(file));
    await out.parent.create(recursive: true);
    await out.writeAsString(markdown);
    _writtenFiles.add(out.path.toLowerCase());
  }

  /// The directory this record exports to (also the parent of its assets/).
  String _recordExportDir(TreeContentFile file) {
    final root = _strip(widget.rootPath);
    final fp = _strip(file.path);
    final relative = root.isEmpty ? fp : fp.substring(root.length);
    final segments = relative.split('/').where((s) => s.isNotEmpty).map(_sanitizeSegment).toList();
    return p.joinAll([widget.targetDir, ...segments]);
  }

  /// Deduplicated .md candidate path — ensures we never overwrite.
  String _mdCandidate(TreeContentFile file) {
    String candidate;
    int n = 0;
    do {
      final suffix = n == 0 ? '' : '$n';
      candidate = p.join(_recordExportDir(file), '${_sanitizeSegment(file.name.isEmpty ? 'untitled' : file.name)}$suffix.md');
      n++;
    } while (_writtenFiles.contains(candidate.toLowerCase()));
    return candidate;
  }

  static String _strip(String s) {
    if (s == '/') return '';
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (s.startsWith('/')) s = s.substring(1);
    return s;
  }

  String _sanitizeSegment(String name) {
    var result = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    result = result.replaceAll(RegExp(r'^\.+|\.+$'), '');
    return result.isEmpty ? 'untitled' : result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.files.length;

    return PopScope(
      canPop: _finished,
      child: AlertDialog(
        title: Text(l10n.exportMd),
        content: SizedBox(width: 400, child: _buildContent(theme, total)),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, int total) {
    if (_finished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.exportCompleted(_success, _skipped))),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.targetDir, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
        ],
      );
    }

    final current = _current;
    final progress = total == 0 ? 0.0 : _done / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.exportingProgress(_done, total), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 10),
        if (current != null)
          Text(
            '${current.path}${current.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
        if (_cancelled) ...[
          const SizedBox(height: 8),
          Text(l10n.exportCancelled, style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_finished) {
      return [
        TextButton(onPressed: () => OpenFilex.open(widget.targetDir), child: Text(l10n.exportOpenFolder)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close)),
      ];
    }
    return [TextButton(onPressed: _cancel, child: Text(l10n.cancel))];
  }
}

/// Password prompt for one encrypted record during export.  Pops with the
/// decrypted plaintext on confirm, or null when the record is skipped.
class _ExportPasswordDialog extends StatefulWidget {
  final TreeContentFile file;
  final String encryptedRaw;

  const _ExportPasswordDialog({required this.file, required this.encryptedRaw});

  @override
  State<_ExportPasswordDialog> createState() => _ExportPasswordDialogState();
}

class _ExportPasswordDialogState extends State<_ExportPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _controller.text.trim();
    if (password.isEmpty) return;
    final decrypted = Utils.decryptContent(widget.encryptedRaw, password);
    if (decrypted == null) {
      setState(() => _error = l10n.passwordIncorrect);
      return;
    }
    Navigator.of(context).pop(decrypted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.exportEncryptedTitle, style: const TextStyle(fontSize: 15))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.file.path}${widget.file.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: l10n.enterUnlockPassword,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.exportSkip)),
        TextButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}
