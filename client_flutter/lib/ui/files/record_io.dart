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
import 'dart:math' as math;
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
import 'package:uuid/uuid.dart';

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
  static List<String> collectAssetNames(Document document) {
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
// Part 1.5 — Document link (href) walking + rewriting (pure format)
// ============================================================================

class DocumentLink {
  /// Recursively walk [document] and return every href attribute value found
  /// in text deltas.  Used by the import preprocessor to discover linked
  /// `.md` / `.txt` files that must also be imported.
  static List<String> collectHrefs(Document document) {
    final hrefs = <String>[];
    void visit(Node node) {
      final delta = node.delta;
      if (delta != null) {
        for (final op in delta) {
          if (op is TextInsert) {
            final href = op.attributes?[AppFlowyRichTextKeys.href] as String?;
            if (href != null && href.isNotEmpty) hrefs.add(href);
          }
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in document.root.children) {
      visit(child);
    }
    return hrefs;
  }

  /// Rewrite every href attribute in [document] by passing it through [rewrite].
  /// When [rewrite] returns null the original href is kept unchanged.
  static void rewriteHrefs(Document document, String? Function(String href) rewrite) {
    void visit(Node node) {
      final delta = node.delta;
      if (delta != null) {
        bool changed = false;
        final newOps = <TextOperation>[];
        for (final op in delta) {
          if (op is TextInsert) {
            final attrs = op.attributes;
            if (attrs != null && attrs.containsKey(AppFlowyRichTextKeys.href)) {
              final href = attrs[AppFlowyRichTextKeys.href] as String?;
              if (href != null) {
                final replaced = rewrite(href);
                if (replaced != null) {
                  changed = true;
                  newOps.add(TextInsert(op.text, attributes: {...attrs, AppFlowyRichTextKeys.href: replaced}));
                  continue;
                }
              }
            }
          }
          newOps.add(op);
        }
        if (changed) {
          node.updateAttributes({'delta': Delta(operations: newOps).toJson()});
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in document.root.children) {
      visit(child);
    }
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
    String? Function(String href)? hrefRewriter,
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
        if (hrefRewriter != null) {
          DocumentLink.rewriteHrefs(doc, hrefRewriter);
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
}

// ============================================================================
// Part 3 — Import business glue (Repository + FileStore + FilePicker)
// ============================================================================

/// Progress callback for import: current file path being processed (or null),
/// preprocessProgress is 0..1, done/success/skipped count saved so far.
typedef RecordImportProgressCallback = void Function({
  String? currentPath,
  double preprocessProgress,
  int done,
  int success,
  int skipped,
  int total,
});

/// Internal: a single document queued for import after preprocessing.
class _PreImportItem {
  final String uuid;
  final String noteeFolder;
  final String originalPath;

  String cacheFile = '';
  final List<(String name, String srcPath)> assets = [];
  bool cached = false;

  _PreImportItem({required this.uuid, required this.noteeFolder, required this.originalPath});
}

class RecordImport {
  /// Returns true if [href] points at a local `.md` / `.txt` file (relative
  /// path, no network scheme).  Used during import preprocessing to discover
  /// linked documents that must also be imported.
  /// Parse [href] into ([path], [rest]) where [rest] is `#fragment` and/or
  /// `?query` preserved verbatim.  Returns null if the path part is empty.
  static (String path, String rest)? _splitHref(String href) {
    final decoded = Uri.decodeFull(href);
    // Split off #fragment (takes priority over ?query per RFC 3986).
    final hashIdx = decoded.indexOf('#');
    String path;
    String rest;
    if (hashIdx >= 0) {
      path = decoded.substring(0, hashIdx);
      rest = decoded.substring(hashIdx); // "#section" or "#s?q=1"
    } else {
      final qIdx = decoded.indexOf('?');
      if (qIdx >= 0) {
        path = decoded.substring(0, qIdx);
        rest = decoded.substring(qIdx); // "?q=1"
      } else {
        path = decoded;
        rest = '';
      }
    }
    if (path.isEmpty) return null;
    return (path, rest);
  }

  static bool _isLocalDocLink(String href) {
    if (href.isEmpty || isRemoteUrl(href)) return false;
    if (href.startsWith(recordLinkPrefix)) return false;
    final split = _splitHref(href);
    if (split == null) return false;
    final lower = split.$1.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.txt');
  }

  /// Return a filename unique within a single document, appending `_1`, `_2`,
  /// … when [basename] is already present in [taken].  Registers the result.
  static String _dedupAssetName(String basename, Set<String> taken) {
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

  /// Preprocess seed files for import.
  ///
  /// Parses each seed file and any `.md`/`.txt` files reachable via relative
  /// href links, assigns a UUID to each, rewrites local-doc hrefs to
  /// `record://<uuid>`, rewrites image URLs to `assets://<name>`, and writes
  /// each body to a flat temp cache folder.  Only one `Document` is held in
  /// memory at a time.
  ///
  /// [seeds] maps an absolute file path to `(target notee folder, base dir)`.
  /// The base dir is used to compute the relative folder for linked docs.
  static Future<List<_PreImportItem>> _preprocess({required Map<String, (String folder, String baseDir)> seeds}) async {
    // absPath -> item.  Single source of truth for uuid, folder, state.
    final items = <String, _PreImportItem>{};
    final queue = <String>[];
    // absPath -> baseDir.  Seeds get their own; linked docs inherit parent's.
    final baseDirMap = <String, String>{};

    void enqueue(String absPath, String noteeFolder, String baseDir) {
      if (items.containsKey(absPath)) return;
      items[absPath] = _PreImportItem(uuid: const Uuid().v4(), noteeFolder: noteeFolder, originalPath: absPath);
      baseDirMap[absPath] = baseDir;
      queue.add(absPath);
    }

    for (final entry in seeds.entries) {
      enqueue(entry.key, entry.value.$1, entry.value.$2);
    }

    final cacheDir = Directory(
      p.join(Directory.systemTemp.path, 'notee_import_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}'),
    );
    await cacheDir.create(recursive: true);

    while (queue.isNotEmpty) {
      final absPath = queue.removeAt(0);
      final item = items[absPath];
      if (item == null || item.cached) continue;

      final file = File(absPath);
      if (!file.existsSync()) continue;

      final bytes = await file.readAsBytes();
      final content = await DocumentIO.decodeBytes(bytes);
      if (content.isEmpty) continue;

      final document = markdownToDocument(content, markdownParsers: const [CustomMarkdownCodeBlockParser()]);
      final sourceDir = p.dirname(absPath);

      // Discover linked local docs — allocate uuid + compute noteeFolder eagerly.
      for (final href in DocumentLink.collectHrefs(document)) {
        if (!_isLocalDocLink(href)) continue;
        final split = _splitHref(href);
        if (split == null) continue;
        final linkedAbs = p.normalize(p.join(sourceDir, split.$1));
        if (items.containsKey(linkedAbs)) continue;

        // Compute linked doc's noteeFolder from this item's perspective.
        final baseDir = baseDirMap[absPath] ?? sourceDir;
        String linkedFolder;
        final seedEntry = seeds[linkedAbs];
        if (seedEntry != null) {
          linkedFolder = seedEntry.$1;
        } else {
          final relPath = p.relative(linkedAbs, from: baseDir);
          final relDir = p.dirname(relPath);
          if (relDir != '.' && relDir.isNotEmpty) {
            final normalized = relDir.replaceAll('\\', '/');
            linkedFolder = item.noteeFolder + (item.noteeFolder.endsWith('/') ? '' : '/') + normalized;
            if (!linkedFolder.endsWith('/')) linkedFolder += '/';
          } else {
            linkedFolder = item.noteeFolder;
          }
        }
        enqueue(linkedAbs, linkedFolder, baseDir);
      }

      // Rewrite this doc's local hrefs using the naming map.
      DocumentLink.rewriteHrefs(document, (href) {
        if (!_isLocalDocLink(href)) return null;
        final split = _splitHref(href);
        if (split == null) return null;
        final linkedAbs = p.normalize(p.join(sourceDir, split.$1));
        final targetUuid = items[linkedAbs]?.uuid;
        if (targetUuid == null) return null;
        return '$recordLinkPrefix$targetUuid${split.$2}';
      });

      // Rewrite image URLs + record asset sources.
      final taken = <String>{};
      for (final node in DocumentImage.collectImageNodes(document)) {
        final url = node.attributes[ImageBlockKeys.url] as String?;
        if (url == null || url.isEmpty) continue;
        if (isRemoteUrl(url) || isNoteeAssetUrl(url)) continue;

        final split = _splitHref(url);
        if (split == null) continue;
        final absoluteSrc = p.normalize(p.join(sourceDir, split.$1));
        final srcFile = File(absoluteSrc);
        if (!srcFile.existsSync()) {
          AppLogger.w('Import', "image not found, skipping: $absoluteSrc");
          continue;
        }

        final dedupName = _dedupAssetName(p.basename(absoluteSrc), taken);
        node.updateAttributes({ImageBlockKeys.url: buildAssetUrl(dedupName)});
        item.assets.add((dedupName, absoluteSrc));
      }

      // Write rewritten body to cache, mark done.
      item.cacheFile = p.join(cacheDir.path, item.uuid);
      await File(item.cacheFile).writeAsString(DocumentIO.documentToBody(document));
      item.cached = true;
    }

    return items.values.where((e) => e.cached).toList();
  }

  /// Persist a preprocessed [item] as a new record.  Body and assets are
  /// copied into the filestore only after `createRecord` succeeds.
  static Future<void> _savePreprocessedItem(_PreImportItem item) async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return;

    final body = await File(item.cacheFile).readAsString();
    // Parse only for the title; asset URLs are already final in the body.
    final document = Document.fromJson(jsonDecode(body) as Map<String, dynamic>);

    String name = RecordUtils.getDocumentTitle(document);
    if (name.isEmpty) name = RecordUtils.generateRecordName();

    await Repository.get().recordTree.createFolder(item.noteeFolder);

    final record = await Repository.get().createRecord(
      item.noteeFolder,
      name,
      false,
      DateTime.now().millisecondsSinceEpoch,
      uuid: item.uuid,
    );
    if (record == null) return;

    try {
      final assetNames = item.assets.map((a) => a.$1).toList();
      final writeContent = RecordSections.buildRecordContent(assetNames, body);
      await fileStore.createWorkFile(record.uuid, writeContent);

      if (item.assets.isNotEmpty) {
        final assetDir = Directory(fileStore.getAssetDir(record.uuid));
        await assetDir.create(recursive: true);
        for (final (assetName, srcPath) in item.assets) {
          final dest = File(fileStore.getAssetPath(record.uuid, assetName));
          try {
            await File(srcPath).copy(dest.path);
          } catch (e) {
            AppLogger.e('Import', "asset copy failed $srcPath → ${dest.path}: $e");
          }
        }
      }
    } catch (e) {
      AppLogger.e('Import', "savePreprocessedItem failed uuid=${record.uuid}: $e");
      await Repository.get().purgeUnsyncedRecord(record.uuid);
      rethrow;
    } finally {
      try {
        await File(item.cacheFile).delete();
      } catch (_) {}
    }
  }

  // ---- Instance API ----

  final Map<String, (String folder, String baseDir)> seeds;
  RecordImport({required this.seeds});

  Future<void> run({RecordImportProgressCallback? onProgress, bool Function()? isCancelled}) async {
    int success = 0;
    int skipped = 0;

    onProgress?.call(currentPath: null, preprocessProgress: 0.0, done: 0, success: 0, skipped: 0, total: 0);

    final items = await _preprocess(seeds: seeds);
    final total = items.length;

    onProgress?.call(currentPath: null, preprocessProgress: 1.0, done: 0, success: 0, skipped: 0, total: total);

    for (int i = 0; i < items.length; i++) {
      if (isCancelled != null && isCancelled()) break;
      final item = items[i];
      onProgress?.call(
        currentPath: item.originalPath,
        preprocessProgress: 1.0,
        done: i,
        success: success,
        skipped: skipped,
        total: total,
      );
      try {
        await _savePreprocessedItem(item);
        success++;
      } catch (_) {
        skipped++;
      }
      onProgress?.call(
        currentPath: null,
        preprocessProgress: 1.0,
        done: i + 1,
        success: success,
        skipped: skipped,
        total: total,
      );
    }

    onProgress?.call(
      currentPath: null,
      preprocessProgress: 1.0,
      done: total,
      success: success,
      skipped: skipped,
      total: total,
    );
    if (success > 0) Repository.get().syncRecords(false);
  }

  /// Pick one or more .md / .txt files and import each as a record.
  /// Linked local documents (relative `.md`/`.txt` hrefs) are imported too.
  static Future<void> pickAndImportDocuments(
    BuildContext context,
    String folderPath,
  ) async {
    if (!context.mounted) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: ['md', 'txt'],
      );
      if (result == null) return;

      final seeds = <String, (String, String)>{};
      for (final file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;
        final ext = file.extension?.toLowerCase() ??
            p.extension(filePath).toLowerCase().replaceFirst('.', '');
        if (ext != 'md' && ext != 'txt') continue;
        seeds[filePath] = (folderPath, p.dirname(filePath));
      }
      if (seeds.isEmpty) return;

      if (!context.mounted) return;
      await showDialog(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(seeds: seeds),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n.importFailed} $e")),
        );
      }
    }
  }

  /// Recursively import all `.md` / `.txt` files under a user-chosen folder,
  /// mirroring the on-disk relative path into the notee tree.  Linked local
  /// documents are imported alongside, preserving their relative location.
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

    final rootName = p.basename(rootDir.path);
    final targetRoot = rootName.isNotEmpty
        ? (folderPath.endsWith('/') ? '$folderPath$rootName/' : '$folderPath/$rootName/')
        : folderPath;

    final seeds = <String, (String, String)>{};
    for (final file in mdFiles) {
      final relPath = p.relative(file.path, from: rootDir.path);
      final relDir = p.dirname(relPath);

      String noteeFolder = targetRoot;
      if (relDir != '.' && relDir.isNotEmpty) {
        final normalized = relDir.replaceAll('\\', '/');
        noteeFolder = targetRoot + (targetRoot.endsWith('/') ? '' : '/') + normalized;
        if (!noteeFolder.endsWith('/')) noteeFolder += '/';
      }

      seeds[file.path] = (noteeFolder, rootDir.path);
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(seeds: seeds),
    );
  }
}

// ============================================================================
// Part 3.5 — Import progress dialog
// ============================================================================

class _ImportProgressDialog extends StatefulWidget {
  final Map<String, (String folder, String baseDir)> seeds;
  const _ImportProgressDialog({required this.seeds});

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  bool _finished = false;
  bool _cancelled = false;
  int _done = 0;
  int _success = 0;
  int _skipped = 0;
  int _total = 0;
  double _preprocessProgress = 0.0;
  String? _currentPath;
  String _error = '';

  @override
  void initState() {
    super.initState();
    Timer.run(() {
      final importer = RecordImport(seeds: widget.seeds);
      importer
          .run(onProgress: _onProgress, isCancelled: () => _cancelled)
          .then((_) {
            if (!mounted) return;
            setState(() => _finished = true);
          })
          .catchError((e) {
            if (!mounted) return;
            setState(() {
              _error = '$e';
              _finished = true;
            });
          });
    });
  }

  void _onProgress({
    String? currentPath,
    double preprocessProgress = 0.0,
    int done = 0,
    int success = 0,
    int skipped = 0,
    int total = 0,
  }) {
    if (!mounted) return;
    setState(() {
      _currentPath = currentPath;
      _preprocessProgress = preprocessProgress;
      _done = done;
      _success = success;
      _skipped = skipped;
      _total = total;
    });
  }

  void _cancel() => setState(() => _cancelled = true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inPreprocess = _total == 0 || _preprocessProgress < 1.0;
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: _finished,
      child: AlertDialog(
        title: const Text('Import Notes'),
        content: SizedBox(
          width: math.min(400, media.size.width * 0.85),
          height: math.min(200, media.size.height * 0.8),
          child: _buildContent(theme, inPreprocess),
        ),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool inPreprocess) {
    if (_finished) {
      if (_error.isNotEmpty) {
        return Text("${l10n.importFailed}: $_error", style: TextStyle(color: theme.colorScheme.error));
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.importCompleted(_success, _skipped))),
            ],
          ),
        ],
      );
    }

    final saveProgress = _total == 0 ? 0.0 : _done / _total;
    final overall = inPreprocess ? _preprocessProgress * 0.3 : 0.3 + saveProgress * 0.7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          inPreprocess ? 'Discovering linked documents...' : 'Importing ($_done/$_total)',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: overall),
        const SizedBox(height: 10),
        if (_currentPath != null)
          Text(
            _currentPath!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
        if (_cancelled) ...[
          const SizedBox(height: 8),
          const Text('Cancelled', style: TextStyle(fontSize: 12, color: Colors.red)),
        ],
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_finished) {
      return [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close))];
    }
    return [TextButton(onPressed: _cancelled ? null : _cancel, child: Text(l10n.cancel))];
  }
}

// ============================================================================
// Part 4 — Export (business glue + progress dialog + password dialog)
// ============================================================================

class RecordExport {
  /// Start export: pick destination folder, then show a progress dialog
  /// exporting every record under [folderPath] (recursive).
  static Future<void> start(BuildContext context, String folderPath) async {
    final root = RecordPath.normalizePath(folderPath);
    final files = Repository.get().recordTree.sortedFiles.where((f) {
      String p = f.path;
      if (!p.endsWith('/')) p += '/';
      return p.startsWith(root);
    }).toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportNoRecords)));
      return;
    }
    await startWithFiles(context, files, RecordPath.dirname(root));
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
      AppLogger.e('Export', "cannot create target dir $resolvedTarget: $e");
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
  bool _finished = false;
  bool _cancelled = false;
  int _done = 0;
  int _success = 0;
  int _skipped = 0;
  TreeContentFile? _current;

  /// Precomputed export .md path for each record uuid, so record:// links
  /// can be rewritten to real relative paths during markdown export.
  final Map<String, String> _uuidToMdPath = {};

  @override
  void initState() {
    super.initState();
    Timer.run(() => _run());
  }

  Future<void> _run() async {
    // Pre-compute export paths for every record (handles filename collisions)
    // so record://uuid hrefs can be resolved to real relative paths.
    _precomputeExportPaths();

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
        final exportDir = _recordExportDir(file);
        final markdown = DocumentIO.bodyToMarkdown(
          plain,
          assetUuid: file.uuid,
              exportAssetDir: p.join(exportDir, 'assets'),
              hrefRewriter: (href) => _rewriteRecordLink(href, exportDir),
        ) ?? plain;
        await _writeFile(file, markdown);
        _success++;
      } catch (e) {
        AppLogger.e('Export', "failed to export ${file.path}${file.name}: $e");
        _skipped++;
      }
      _advance();
    }

    if (mounted) setState(() => _finished = true);
  }

  /// Pre-compute the deduplicated .md export path for every record and store
  /// it in [_uuidToMdPath].  Runs before the export loop so href rewriting and
  /// file writing share the same resolved paths.
  void _precomputeExportPaths() {
    final written = <String>{};
    for (final file in widget.files) {
      String candidate;
      int n = 0;
      do {
        final suffix = n == 0 ? '' : '$n';
        candidate = p.join(
          _recordExportDir(file),
          '${_sanitizeSegment(file.name.isEmpty ? 'untitled' : file.name)}$suffix.md',
        );
        n++;
      } while (written.contains(candidate.toLowerCase()));
      written.add(candidate.toLowerCase());
      _uuidToMdPath[file.uuid] = candidate;
    }
  }

  /// Rewrite a `record://<uuid>` href to a relative path from [fromDir] to
  /// the target record's exported .md file.  Returns null for non-record
  /// links or when the target uuid isn't part of this export batch.
  String? _rewriteRecordLink(String href, String fromDir) {
    if (!href.startsWith(recordLinkPrefix)) return null;
    final targetUuid = href.substring(recordLinkPrefix.length);
    final targetMdPath = _uuidToMdPath[targetUuid];
    if (targetMdPath == null) return null;
    return p.relative(targetMdPath, from: fromDir).replaceAll('\\', '/');
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
      AppLogger.e('Export', "read failed uuid=${record.uuid}: $e");
      return null;
    }
  }

  Future<void> _writeFile(TreeContentFile file, String markdown) async {
    final out = File(_uuidToMdPath[file.uuid]!);
    await out.parent.create(recursive: true);
    await out.writeAsString(markdown);
  }

  /// The directory this record exports to (also the parent of its assets/).
  String _recordExportDir(TreeContentFile file) {
    final root = _strip(widget.rootPath);
    final fp = _strip(file.path);
    final relative = root.isEmpty ? fp : fp.substring(root.length);
    final segments = relative.split('/').where((s) => s.isNotEmpty).map(_sanitizeSegment).toList();
    return p.joinAll([widget.targetDir, ...segments]);
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
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: _finished,
      child: AlertDialog(
        title: Text(l10n.exportMd),
        content: SizedBox(
          width: math.min(400, media.size.width * 0.85),
          height: math.min(200, media.size.height * 0.8),
          child: _buildContent(theme, total),
        ),
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
