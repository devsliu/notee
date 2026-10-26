import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/filesync/record_ext.dart' show isRemoteUrl, extractAssetFilename;
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/dedup_task_queue.dart';
import 'package:notee/utils/utils.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' as p;

/// Resolved descriptor for an image reference inside a document — whether it
/// points at a managed asset (`assets/{uuid}/foo.png`), a server-side asset,
/// or a network URL that must be cached locally before display.
class RecordAsset {
  const RecordAsset({required this.src, this.recordUuid, this.filename, this.cachePath = '', this.downloadUrl = ''});

  /// The display source — either a local absolute path or the original
  /// network URL (used when nothing has been downloaded yet).
  final String src;

  /// When non-null, the asset lives on the server and must be fetched via
  /// [FileStore.downloadAsset].
  final String? recordUuid;
  final String? filename;

  /// Local disk path — either the asset path itself, or a cache path for
  /// network images.  Empty when this reference doesn't map to a local file.
  final String cachePath;

  /// HTTP URL to download from.  Empty when no HTTP download is needed
  /// (already local, or [src] itself is the URL — use src in that case).
  final String downloadUrl;

  /// True when this asset lives on the server and requires an auth token on
  /// download (managed `assets/{uuid}/...` references).
  bool get needsAuth => recordUuid != null;
}

enum ContentFileEventType { create, delete, move, download }

class ContentFileEvent {
  final String uuid;
  final ContentFileEventType type;
  ContentFileEvent(this.uuid, this.type);
}

class FileStore {
  final String rootDir;
  final String appCacheRoot;
  late final String baseFilesDir;
  late final String workFilesDir;
  late final String recyclerFilesDir;
  late final String assetsDir;
  late final String imageCacheDir;
  final DedupTaskQueue<bool> _downloadQueue = DedupTaskQueue<bool>(concurrency: 4, disposeValue: false);
  final http.Client _httpClient = http.Client();
  AppDatabase? db;
  bool _closed = false;

  final _controller = StreamController<ContentFileEvent>.broadcast();
  Stream<ContentFileEvent> get onContentChanged => _controller.stream;

  Future<void> close() async {
    _closed = true;
    _downloadQueue.dispose();
    _httpClient.close();
  }

  FileStore(this.rootDir, [String? appCacheRoot]) : appCacheRoot = appCacheRoot ?? rootDir {
    baseFilesDir = join(rootDir, "base_files");
    workFilesDir = join(rootDir, "work_files");
    recyclerFilesDir = join(rootDir, "recycler");
    assetsDir = join(rootDir, "assets");
    imageCacheDir = join(this.appCacheRoot, "notee_images");
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
    files = Directory(imageCacheDir);
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
  Future<bool> downloadBaseFile(String uuid) {
    return _downloadQueue.submit(uuid, () async {
      final file = File(getBaseFile(uuid));

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
        if (result.code == HttpApi.kResultErrorFileNotFound) {
          await db?.updateRecord(uuid, fileEditAt: 0);
        }
        return false;
      }

      final meta = result.data!;
      final latestRecord = await db?.getRecord(uuid);
      final latestFileVersion = latestRecord?.local.remoteFileVersion ?? 0;
      if (meta.fileVersion < latestFileVersion) {
        AppLogger.e(
          'FileStore',
          "download uuid=$uuid fileVersion mismatch, expected>=$latestFileVersion actual=${meta.fileVersion}",
        );
        return false;
      }

      if (_closed) {
        AppLogger.i('FileStore', "download uuid=$uuid skipped post-download — fileStore closed");
        return false;
      }

      try {
        await db?.updateRecord(uuid, baseFileVersion: meta.fileVersion, remoteMd5: meta.md5);
      } catch (e) {
        AppLogger.e('FileStore', "download uuid=$uuid failed to update baseFileVersion: $e");
      }

      AppLogger.i('FileStore', "download base file $uuid");
      
      if (!isWorkFileExist(uuid)) {
        _fireChanged(uuid, ContentFileEventType.download);
      }
      return true;
    });
  }

  /// Resolve a raw image URL into a [RecordAsset].
  ///
  /// | URL form | Behavior |
  /// |---|---|
  /// | `assets/{recordUuid}/filename` | Local/Server asset: `src = absolute local path`, `recordUuid+filename` set, `cachePath = local path` |
  /// | `http(s)://...` / `ftp(s)://...` | Network image: `src = url`, `cachePath = {imageCacheDir}/{md5(url)}.{ext}` (downloaded on demand) |
  /// | Anything else | Passed through as-is, no caching |
  RecordAsset resolveRecordAsset(String src, String recordUuid) {
    final filename = extractAssetFilename(src);
    if (filename != null) {
      final localPath = getAssetPath(recordUuid, filename);
      final downloadUrl = '${HttpApi.baseUrl}/asset/$recordUuid/${Uri.encodeComponent(filename)}';
      return RecordAsset(
        src: localPath,
        recordUuid: recordUuid,
        filename: filename,
        cachePath: localPath,
        downloadUrl: downloadUrl,
      );
    }
    if (isRemoteUrl(src)) {
      final uri = Uri.parse(src);
      final ext = uri.pathSegments.isNotEmpty ? p.extension(uri.pathSegments.last).replaceFirst('.', '') : '';
      final md5 = Utils.generateMd5(src).toLowerCase();
      final name = ext.isEmpty ? md5 : '$md5.$ext';
      return RecordAsset(src: src, cachePath: join(imageCacheDir, name), downloadUrl: src);
    }
    return RecordAsset(src: src, cachePath: src);
  }

  /// Download [asset.downloadUrl] (falling back to [asset.src]) and atomically
  /// write the bytes to [asset.cachePath].
  /// Carries the auth token iff [asset.needsAuth] is true (server assets).
  /// All downloads share a single dedup+semaphore queue so identical URLs
  /// collapse into one request and concurrency stays bounded.
  Future<bool> downloadAsset(RecordAsset asset) {
    final url = asset.downloadUrl.isNotEmpty ? asset.downloadUrl : asset.src;
    final localPath = asset.cachePath;
    return _downloadQueue.submit(url, () async {
      if (localPath.isEmpty) return false;
      if (!isRemoteUrl(url)) return File(localPath).existsSync();
      if (File(localPath).existsSync()) {
        if (asset.recordUuid != null && asset.filename != null) markAssetUploaded(asset.recordUuid!, asset.filename!);
        return true;
      }
      try {
        final request = http.Request('GET', Uri.parse(url));
        if (asset.needsAuth) await HttpApi.setTokenToRequest(request);
        final response = await _httpClient.send(request).timeout(const Duration(seconds: 120));
        if (response.statusCode != 200) {
          await response.stream.drain();
          return false;
        }
        final file = File(localPath);
        await file.parent.create(recursive: true);
        await Utils.atomicWriteFile(file, (tmp) async {
          final sink = tmp.openWrite();
          try {
            await response.stream.pipe(sink).timeout(const Duration(seconds: 120));
          } finally {
            await sink.close();
          }
        });
        if (asset.recordUuid != null && asset.filename != null) markAssetUploaded(asset.recordUuid!, asset.filename!);
        return true;
      } catch (e) {
        AppLogger.e('FileStore', "[downloadAsset] $url → $localPath failed: $e");
        return false;
      }
    });
  }

  /// Batch download base files with concurrency limit.  Each call goes through
  /// [DedupTaskQueue.submit], so identical uuids from overlapping calls
  /// deduplicate to a single HTTP request.

  Future<void> downloadBaseFiles(Iterable<String> uuids) async {
    final Set<String> unique = uuids.toSet();
    if (unique.isEmpty || _closed) return;

    final tasks = <Future<void>>[];
    for (final uuid in unique) {
      if (_closed) break;
      tasks.add(downloadBaseFile(uuid).then((_) {}).catchError((_) {}));
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
