import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/utils.dart';
import 'package:path/path.dart';



class _DownloadFile {
  final String uuid;
  final Future<void> future;
  _DownloadFile(this.uuid, this.future);
}

/// Simple semaphore to limit concurrent operations (await acquire() before use, release() when done).
class _Semaphore {
  final List<Completer<void>> _waiters = [];
  int _available;

  _Semaphore(int limit) : _available = limit;

  Future<void> acquire() {
    if (_available > 0) {
      _available--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _available++;
    }
  }
}

enum ContentFileEventType { create, delete, move, download }

class ContentFileEvent {
  final String uuid;
  final ContentFileEventType type;
  ContentFileEvent(this.uuid, this.type);
}

class FileStore {
  final String rootDir;
  late final String baseFilesDir;
  late final String workFilesDir;
  late final String recyclerFilesDir;
  late final String assetsDir;
  final Map<String, _DownloadFile> _downloadFiles = {};
  AppDatabase? db;
  bool _closed = false;

  final _controller = StreamController<ContentFileEvent>.broadcast();
  Stream<ContentFileEvent> get onContentChanged => _controller.stream;

  Future<void> close() async {
    _closed = true;
    // Do NOT await in-flight downloads. HttpApi.downloadFile has no Dart-side
    // cancellation; they'll complete naturally but downloadBaseFile's _closed
    // guards and the db?. nullable access protect against using closed DB.
    _downloadFiles.clear();
  }

  FileStore(this.rootDir) {
    baseFilesDir = join(rootDir, "base_files");
    workFilesDir = join(rootDir, "work_files");
    recyclerFilesDir = join(rootDir, "recycler");
    assetsDir = join(rootDir, "assets");
    var files = Directory(baseFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
    files = Directory(workFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
    files = Directory(recyclerFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
    files = Directory(assetsDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
  }

  /// Per-record asset directory: assets/{uuid}/
  String getAssetDir(String uuid) => join(assetsDir, uuid);

  /// Full path to a single asset file: assets/{uuid}/{filename}
  String getAssetPath(String uuid, String filename) => join(assetsDir, uuid, filename);

  /// Marker file `<asset>.1` — an empty file signifying the asset has already
  /// been uploaded to the server (or downloaded from it). Lets the sync loop
  /// skip an HTTP HEAD check before re-uploading.
  String getAssetMarkerPath(String uuid, String filename) => '${getAssetPath(uuid, filename)}.1';

  /// Returns true if the upload marker exists for this asset.
  bool hasAssetMarker(String uuid, String filename) => File(getAssetMarkerPath(uuid, filename)).existsSync();

  /// Creates (or touches) the upload marker for an asset.
  void markAssetUploaded(String uuid, String filename) {
    try {
      File(getAssetMarkerPath(uuid, filename)).writeAsBytesSync(<int>[]);
    } catch (_) {}
  }

  /// Extract the asset filename list from a note file's content.
  /// Supports the file-level header format [[tag:len,...]] and the legacy
  /// first-line-JSON-array format. Returns [] when none.
  static List<String> extractAssetNames(String content) {
    List<String> parseAssetJson(String json) {
      try {
        return (jsonDecode(json) as List).map((e) => e.toString()).toList();
      } catch (_) {
        return const <String>[];
      }
    }

    final bytes = utf8.encode(content);
    if (bytes.length >= 2 && bytes[0] == 0x5B && bytes[1] == 0x5B) {
      int closeIdx = -1;
      const int limit = 4096;
      final int n = bytes.length < limit ? bytes.length : limit;
      for (int i = 1; i < n; i++) {
        if (bytes[i - 1] == 0x5D && bytes[i] == 0x5D) {
          closeIdx = i;
          break;
        }
      }
      if (closeIdx > 1) {
        final headerEnd = closeIdx + 1;
        final headerStr = utf8.decode(bytes.sublist(2, closeIdx));
        final sections = <(String tag, int len)>[];
        for (final part in headerStr.split(',')) {
          final colon = part.indexOf(':');
          if (colon <= 0 || colon == part.length - 1) continue;
          final tag = part.substring(0, colon).trim();
          final lenStr = part.substring(colon + 1).trim();
          final len = int.tryParse(lenStr);
          if (tag.isEmpty || len == null || len < 0) continue;
          sections.add((tag, len));
        }
        int cur = headerEnd;
        for (final (tag, len) in sections) {
          if (tag == 'image') {
            if (cur + len <= bytes.length) {
              return parseAssetJson(utf8.decode(bytes.sublist(cur, cur + len)));
            }
            break;
          }
          cur += len;
        }
      }
    }
    // Legacy format: first line may be a JSON-array asset header.
    final nl = content.indexOf('\n');
    if (nl < 0) return const <String>[];
    final firstLine = content.substring(0, nl);
    if (!firstLine.trimLeft().startsWith('[')) return const <String>[];
    return parseAssetJson(firstLine);
  }

  /// Ensure the per-record asset directory exists and return its path.
  String ensureAssetDir(String uuid) {
    final dir = Directory(getAssetDir(uuid));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  /// Delete the entire per-record asset directory (used when the record is deleted).
  void deleteAssetsDir(String uuid) {
    final dir = Directory(getAssetDir(uuid));
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (e) {
        AppLogger.e('FileStore', "[deleteAssetsDir] uuid=$uuid failed: $e");
      }
    }
  }

  /// Remove all "already uploaded" markers (*.1 files) from the per-record
  /// asset directory, while preserving the actual image files.
  ///
  /// Used after the server has confirmed the record deletion — the server also
  /// deletes its copy of the assets, so if the user restores from recycle bin
  /// the images must be re-uploaded. Leaving stale .1 markers would silently
  /// skip the re-upload and permanently orphan the images on the server.
  void deleteAssetMarkers(String uuid) {
    final dir = Directory(getAssetDir(uuid));
    if (!dir.existsSync()) return;
    try {
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.1')) {
          entity.deleteSync();
        }
      }
    } catch (e) {
      AppLogger.e('FileStore', "[deleteAssetMarkers] uuid=$uuid failed: $e");
    }
  }

  /// Keep only asset files whose basename (after stripping the optional ".1"
  /// marker suffix) is in [keep]. Everything else — orphan images, stale
  /// markers, or stale marker-image pairs — is deleted.
  ///
  /// Used at keepRemote conflict resolution: the remote version's asset list
  /// wins, so we prune local additions that did not make it to the server.
  void pruneAssetsKeepOnly(String uuid, Set<String> keep) {
    final dir = Directory(getAssetDir(uuid));
    if (!dir.existsSync()) return;
    try {
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = basename(entity.path);
        final base = name.endsWith('.1') ? name.substring(0, name.length - 2) : name;
        if (!keep.contains(base)) {
          entity.deleteSync();
        }
      }
    } catch (e) {
      AppLogger.e('FileStore', "[pruneAssetsKeepOnly] uuid=$uuid failed: $e");
    }
  }

  bool isWorkFileExist(String uuid) {
    return File(getWorkFile(uuid)).existsSync();
  }

  bool isBaseFileExist(String uuid) {
    return File(getBaseFile(uuid)).existsSync();
  }

  String getWorkFile(String uuid) {
    return join(workFilesDir, uuid);
  }

  void deleteWorkFile(String uuid) {
    final file = File(getWorkFile(uuid));
    if (file.existsSync()) {
      file.deleteSync();
      _fireChanged(uuid, ContentFileEventType.delete);
    }
  }

  String getBaseFile(String uuid) {
    return join(baseFilesDir, uuid);
  }

  void deleteBaseFile(String uuid) {
    final file = File(getBaseFile(uuid));
    if (file.existsSync()) {
      file.deleteSync();
      _fireChanged(uuid, ContentFileEventType.delete);
    }
  }

  String getRecyclerFile(String uuid) {
    return join(recyclerFilesDir, uuid);
  }

  bool isRecyclerFileExist(String uuid) {
    return File(getRecyclerFile(uuid)).existsSync();
  }

  void deleteRecyclerFile(String uuid) {
    final file = File(getRecyclerFile(uuid));
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  void moveBaseFileToWorkIfWorkFileNotExist(String uuid) {
    var workFile = File(getWorkFile(uuid));
    if (!workFile.existsSync()) {
      var baseFile = File(getBaseFile(uuid));
      if (baseFile.existsSync()) {
        try {
          baseFile.renameSync(workFile.absolute.path);
        } on FileSystemException {
          // When base/work are on different filesystems (e.g. mounted drives/removable storage),
          // rename will fail; fall back to copy+delete to ensure content is not lost
          baseFile.copySync(workFile.absolute.path);
          baseFile.deleteSync();
        }
        _fireChanged(uuid, ContentFileEventType.move);
      }
    }
  }

  /// Promote work file to base file after successful upload (prefer rename on same disk,
  /// fall back to copy+delete across disks).
  /// On Windows, rename does not overwrite existing files, so use "backup old base → replace → cleanup backup"
  /// pattern to avoid base file loss caused by delete-then-rename failure
  void moveWorkFileToBase(String uuid) {
    final workFile = File(getWorkFile(uuid));
    if (!workFile.existsSync()) return;
    final basePath = getBaseFile(uuid);
    final baseFile = File(basePath);
    final bakPath = '$basePath.bak';
    final bakFile = File(bakPath);
    // 1. Back up old base to .bak (Windows rename does not overwrite, must move it first)
    if (baseFile.existsSync()) {
      try {
        baseFile.renameSync(bakPath);
      } catch (e) {
        AppLogger.e('FileStore', "[moveWorkFileToBase] uuid=$uuid failed to back up old base: $e");
      }
    }
    // 2. work → base
    try {
      workFile.renameSync(basePath);
    } on FileSystemException {
      workFile.copySync(basePath);
      try {
        workFile.deleteSync();
      } catch (e) {
        // copy succeeded but delete work failed: work file remains, will be re-uploaded next sync,
        // but base file is correctly written, does not affect user reading
        AppLogger.e('FileStore', "[moveWorkFileToBase] uuid=$uuid copy succeeded but deleting work failed: $e");
      }
    }
    // 3. Clean up backup
    if (bakFile.existsSync()) {
      try {
        bakFile.deleteSync();
      } catch (e) {
        AppLogger.e('FileStore', "[moveWorkFileToBase] uuid=$uuid failed to clean up backup: $e");
      }
    }
    _fireChanged(uuid, ContentFileEventType.move);
  }

  /// Move the record's content file into the recycler folder (work file preferred, base file as
  /// fallback). The base file is not kept: it is the stale synced baseline, and restore re-creates
  /// the record as a pure local edit (next sync pushes it as new, base is re-derived from work).
  void moveFileToRecycler(String uuid) {
    final workFile = File(getWorkFile(uuid));
    final baseFile = File(getBaseFile(uuid));
    if (workFile.existsSync()) {
      Utils.moveFile(workFile, File(getRecyclerFile(uuid)));
      // Base is the stale synced baseline; delete it so it cannot be mistaken for live content.
      if (baseFile.existsSync()) {
        try {
          baseFile.deleteSync();
        } catch (e) {
          AppLogger.e('FileStore', "[moveFileToRecycler] uuid=$uuid failed to delete stale base file: $e");
        }
      }
      _fireChanged(uuid, ContentFileEventType.move);
    } else if (baseFile.existsSync()) {
      Utils.moveFile(baseFile, File(getRecyclerFile(uuid)));
      _fireChanged(uuid, ContentFileEventType.move);
    }
  }

  /// Move the recycler content file back into the work folder.
  void moveRecyclerFileToWork(String uuid) {
    final src = File(getRecyclerFile(uuid));
    if (!src.existsSync()) return;
    Utils.moveFile(src, File(getWorkFile(uuid)));
    _fireChanged(uuid, ContentFileEventType.move);
  }

  /// Move a work content file back into the recycler folder (rollback compensation).
  void moveWorkFileToRecycler(String uuid) {
    final src = File(getWorkFile(uuid));
    if (!src.existsSync()) return;
    Utils.moveFile(src, File(getRecyclerFile(uuid)));
    _fireChanged(uuid, ContentFileEventType.move);
  }

  /// Download base file. Determine whether download is needed by comparing server-side remoteFileVersion
  /// with local baseFileVersion (remoteFileVersion > baseFileVersion or file does not exist).
  /// Save baseFileVersion after successful download, never clear it.
  Future<bool> downloadBaseFile(String uuid) async {
    File file = File(getBaseFile(uuid));

    if (_closed) {
      AppLogger.i('FileStore', "download uuid=$uuid skipped — fileStore closed");
      return false;
    }

    // Register placeholder completer first (synchronous, no await, guarantees atomicity).
    // Subsequent concurrent calls will wait on previous.future, eliminating races where two calls download simultaneously.
    final completer = Completer<void>();
    final entry = _DownloadFile(uuid, completer.future);
    final previous = _downloadFiles[uuid];
    _downloadFiles[uuid] = entry;

    try {
      if (previous != null) {
        await previous.future;
      }

      if (_closed) {
        AppLogger.i('FileStore', "download uuid=$uuid aborted — fileStore closed");
        return false;
      }

      final record = await db?.getRecord(uuid);

      if (file.existsSync() && record != null && record.local.remoteFileVersion <= record.local.baseFileVersion) {
        return true;
      }

      if (_closed) return false;
      final result = await HttpApi.downloadFile(uuid, getBaseFile(uuid));

      if (!result.isSuccess() || result.data == null) {
        AppLogger.e('FileStore', "download uuid=$uuid download failed ${result.message}");
        // Server returned "file not found", meaning this record has no file; reset local flag
        // to avoid retrying download on next loadContent
        if (result.code == HttpApi.kResultErrorFileNotFound) {
          await db?.updateRecord(uuid, fileEditAt: 0);
        }
        return false;
      }

      final meta = result.data!;
      // During download, the record in DB may have been updated by sync flow; re-read latest expected state
      final latestRecord = await db?.getRecord(uuid);
      final latestFileVersion = latestRecord?.local.remoteFileVersion ?? 0;
      // Verify fileVersion: downloaded file version must >= latest expected to prevent stale files
      if (meta.fileVersion < latestFileVersion) {
        AppLogger.e('FileStore', 
          "download uuid=$uuid fileVersion mismatch, expected>=$latestFileVersion actual=${meta.fileVersion}",
        );
        return false;
      }

      // 切换用户/关闭资源后, fileStore._closed 已置位, 跳过 DB 更新和事件派发:
      // 避免对正在关闭的 db 写入 (拖慢 db.close), 也避免触发已关闭的 searchIndex.refresh 报错
      if (_closed) {
        AppLogger.i('FileStore', "download uuid=$uuid skipped post-download — fileStore closed");
        return false;
      }

      // Download succeeded, update DB: write server fileVersion to baseFileVersion, never clear.
      // Also update remoteMd5 to current file md5.
      // DB update failure does not affect download result: file is already written to disk,
      // just means it will be re-downloaded next time, no data loss.
      try {
        await db?.updateRecord(uuid, baseFileVersion: meta.fileVersion, remoteMd5: meta.md5);
      } catch (e) {
        AppLogger.e('FileStore', "download uuid=$uuid failed to update baseFileVersion: $e");
      }

      try {
        AppLogger.i('FileStore', "download base file $uuid");
      } catch (e) {
        AppLogger.e('FileStore', "download uuid=$uuid failed to record operate log: $e");
      }
      if (!isWorkFileExist(uuid)) {
        _fireChanged(uuid, ContentFileEventType.download);
      }
      // Assets are now downloaded on-demand when the user opens the note, so
      // the previous fire-and-forget downloadRecordAssets call is removed.
      return true;
    } catch (e) {
      rethrow;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      // Only remove our own entry; a newer concurrent call may have overwritten
      // it, and removing theirs would break the dedup chain.
      if (identical(_downloadFiles[uuid], entry)) {
        _downloadFiles.remove(uuid);
      }
    }
  }

  /// Parse the base file's plaintext asset header line and download any
  /// referenced asset files that are missing locally. Failures are logged,
  /// never thrown (a missing image should not break the sync flow).
  Future<void> downloadRecordAssets(String uuid) async {
    if (_closed) return;
    final file = File(getBaseFile(uuid));
    if (!file.existsSync()) return;
    String content;
    try {
      content = file.readAsStringSync();
    } catch (e) {
      AppLogger.e('FileStore', "[downloadRecordAssets] uuid=$uuid read base failed: $e");
      return;
    }
    final names = FileStore.extractAssetNames(content);
    if (names.isEmpty) return;
    ensureAssetDir(uuid);
    for (final name in names) {
      if (_closed) break;
      final localPath = getAssetPath(uuid, name);
      if (File(localPath).existsSync()) {
        // Already present locally — make sure it has the upload marker too
        // (it came from a previous download, or was inserted locally and
        // uploaded). Idempotent.
        markAssetUploaded(uuid, name);
        continue;
      }
      final ok = await HttpApi.downloadAsset(uuid, name, localPath);
      if (ok) {
        markAssetUploaded(uuid, name);
      } else {
        AppLogger.e('FileStore', "[downloadRecordAssets] uuid=$uuid name=$name download failed");
      }
    }
  }

  /// Batch download base files with concurrency limit. Internally deduplicates by uuid;
  /// failures only log, do not throw. All downloads are guaranteed to not race on the
  /// same uuid by downloadBaseFile's own _downloadFiles deduplication.
  static const int _downloadConcurrency = 4;

  Future<void> downloadBaseFiles(Iterable<String> uuids) async {
    final Set<String> unique = uuids.toSet();
    if (unique.isEmpty || _closed) return;

    final queue = List<String>.from(unique);
    final sem = _Semaphore(_downloadConcurrency);
    final List<Future<void>> tasks = [];

    for (final uuid in queue) {
      if (_closed) break;
      final task = sem.acquire().then((_) async {
        try {
          if (!_closed) await downloadBaseFile(uuid);
        } catch (e) {
          if (!_closed) {
            AppLogger.e('FileStore', "downloadBaseFiles failed uuid=$uuid: $e");
          }
        } finally {
          sem.release();
        }
      });
      tasks.add(task);
    }

    await Future.wait(tasks).catchError((e) {
      if (!_closed) {
        AppLogger.e('FileStore', "downloadBaseFiles batch failed: $e");
      }
      return <void>[];
    });
  }

  /// Create/overwrite work file. Write to temp file first then rename (back up old file to .bak first),
  /// to avoid "delete then write" leaving missing or corrupted target file on write failure/process interruption
  Future<void> createWorkFile(String uuid, String content) async {
    await createWorkFileBytes(uuid, utf8.encode(content));
  }

  Future<void> createWorkFileBytes(String uuid, List<int> bytes) async {
    final file = File(getWorkFile(uuid));
    await Utils.atomicWriteFile(
      file,
      (tmp) => tmp.writeAsBytes(bytes),
      onBackupFailed: (e) {
        AppLogger.e(
          'FileStore',
          "[createWorkFileBytes] uuid=$uuid failed to back up old file (locked/permission) or restore backup: $e",
        );
      },
    );
    _fireChanged(uuid, ContentFileEventType.create);
  }

  void _fireChanged(String uuid, ContentFileEventType type) {
    _controller.add(ContentFileEvent(uuid, type));
  }
}
