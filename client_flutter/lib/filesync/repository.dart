import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/file_store.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:notee/filesync/tag_tree.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/search_index.dart';
import 'package:notee/filesync/sync_engine.dart' show SyncEngine, SyncState;
import 'package:notee/filesync/user.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Per-user resource bundle: owns the DB, FileStore, SearchIndex, SyncEngine
/// and their stream subscriptions for one user (or guest mode).
/// Lifecycle: [open] creates all resources for a given dir; [close] tears them
/// down. Close is idempotent (safe to call on an already-closed resource) and
/// fast — it does NOT await any in-flight network work, only flips _closed
/// flags on SyncEngine/FileStore so they bail out at their next check point.
class _UserResource {
  final User user;
  final RecordTree recordTree;
  final ValueNotifier<SyncState> syncStateNotifier;
  final ValueNotifier<int> recyclerCountNotifier;

  AppDatabase? db;
  FileStore? fileStore;
  SearchIndex? searchIndex;
  SyncEngine? syncEngine;
  StreamSubscription<int>? recyclerCountSub;
  StreamSubscription<ContentFileEvent>? searchIndexSub;
  bool _disposed = false;

  /// In-flight open/close for this user's resource. Multiple calls for the
  /// same user queue on this (open waits for a prior close, close waits for a
  /// prior open); different users are never serialized against each other.
  Future<void>? _pending;

  _UserResource(
    this.user, {
    required this.recordTree,
    required this.syncStateNotifier,
    required this.recyclerCountNotifier,
  });

  bool get isOpen => db != null;

  /// Serialize [work] against any in-flight open/close on this same resource.
  Future<void> _serialize(Future<void> Function() work) async {
    final pending = _pending;
    final completer = Completer<void>();
    _pending = completer.future;
    try {
      if (pending != null) await pending;
      await work();
    } finally {
      completer.complete();
    }
  }

  Future<void> clearExpiredRecycler() async {
    if (db == null) return;
    final threshold = DateTime.now().millisecondsSinceEpoch - Repository.recyclerExpireDays * 24 * 60 * 60 * 1000;
    final expired = await db!.purgeRecycleRecordsBefore(threshold);
    for (final row in expired) {
      fileStore?.deleteRecyclerFile(row.uuid);
      fileStore?.deleteAssetsDir(row.uuid);
    }
    if (expired.isNotEmpty) {
      AppLogger.w('Repository', "auto-purged ${expired.length} expired recycler entries (>30d)");
    }
  }

  Future<void> open() async {
    _disposed = false;
    await _serialize(() async {
      if (isOpen) return;
      final dir = user.dirAbsPath;
      AppLogger.i('Repository', "_UserResource.open dir=$dir");

      final cacheDir = (await getApplicationCacheDirectory()).path;
      fileStore = FileStore(dir, cacheDir);
      db = createRecordsDatabase(File(join(dir, 'records0.db')));
      fileStore!.db = db!;

      await clearExpiredRecycler();
      searchIndex = SearchIndex(File(join(dir, 'search0.db')), fileStore!);
      await searchIndex!.open();

      searchIndexSub = fileStore!.onContentChanged.listen((event) async {
        if (_disposed) return;
        await searchIndex?.refresh(event.uuid);
      });

      recyclerCountSub = db!.watchRecycleCount().listen((c) => recyclerCountNotifier.value = c);

      syncEngine = SyncEngine(
        db: db!,
        fileStore: fileStore!,
        recordTree: recordTree,
        syncStateNotifier: syncStateNotifier,
      );
    });
  }

  /// Close all owned resources. Idempotent — safe to call multiple times or on
  /// an already-null resource. Serialized against in-flight open() on this same
  /// resource so a close never tears down a half-initialized resource.
  Future<void> close() async {
    // Mark disposed BEFORE awaiting the serialize lock. If open() is still
    // running, close() will queue behind it; setting _disposed early lets
    // in-flight listeners bail out immediately instead of continuing to call
    // searchIndex.refresh while we wait for the lock.
    _disposed = true;
    await _serialize(() async {
      if (!isOpen) return;
      // Step 1: set _closed flags — in-flight work bails out at its next check point
      AppLogger.i('Repository', "_UserResource.close userId=${user.id}");
      await syncEngine?.close();
      await fileStore?.close();

      // Step 2: cancel subscriptions (fire-and-forget, they do minimal teardown)
      await recyclerCountSub?.cancel();
      recyclerCountSub = null;
      await searchIndexSub?.cancel();
      searchIndexSub = null;

      // Step 3: close DB-backed resources
      try {
        await searchIndex?.close();
      } catch (e) {
        AppLogger.w('Repository', "_UserResource.close searchIndex ignored: $e");
      }
      searchIndex = null;
      syncEngine = null;
      fileStore = null;

      try {
        await db?.close();
      } catch (e) {
        AppLogger.w('Repository', "_UserResource.close db ignored: $e");
      }
      db = null;
    });
  }
}

class Repository {
  static const recyclerExpireDays = 30;
  static const int fetchLimit = 200;

  static Repository? _instance;

  /// Per-user resource cache. Each user's open/close is serialized independently
  /// via [_UserResource._pending]; switching users closes the old resource and
  /// opens (or reopens) the target one. Keyed by UserManager.userKey(user).
  final Map<String, _UserResource> _resources = {};

  _UserResource? _resource;

  AppDatabase? get db => _resource?.db;
  FileStore? get fileStore => _resource?.fileStore;
  SearchIndex? get searchIndex => _resource?.searchIndex;

  final RecordTree recordTree = RecordTree();
  final ReminderTree reminderTree = ReminderTree();
  final TagTree tagTree = TagTree();
  final ValueNotifier<SyncState> syncStateNotifier = ValueNotifier(SyncState(state: SyncState.idle));

  /// Recycle bin entry count, for the list page entry badge.
  final ValueNotifier<int> recyclerCountNotifier = ValueNotifier(0);

  /// True while a user switch (close old resource + open new + initial sync)
  /// is in progress. UI uses this to show a blocking loading overlay so the
  /// user cannot interact with half-torn-down resources.
  final ValueNotifier<bool> userSwitchingNotifier = ValueNotifier(false);

  Repository._() {
    reminderTree.bind(recordTree);
    tagTree.bind(recordTree);
  }
  static Repository get() => _instance!;

  static Future<void> init(String appRootDir) async {
    if (_instance != null) return;
    await UserManager.init(appRootDir);
    _instance = Repository._();
    _instance!._onUserChanged(UserManager.stateNotifier.value);
    UserManager.stateNotifier.addListener(() {
      _instance?._onUserChanged(UserManager.stateNotifier.value);
    });
  }

  // =========================================================================
  // 🎯 USER SWITCH — activate the resource for userId (open on first use)
  // =========================================================================

  Future<void> _onUserChanged(UserLoginState state) async {
    HttpApi.setBaseUrl(state.user.apiUrl ?? '');
    final currUser = state.user;
    final prevUser = _resource?.user;
    final resource = _resources[currUser.key] ??= _UserResource(
      currUser,
      recordTree: recordTree,
      syncStateNotifier: syncStateNotifier,
      recyclerCountNotifier: recyclerCountNotifier,
    );

    AppLogger.i('Repository', "_onUserChanged $state (active=${_resource?.user.id})");

    // Same active user (e.g. token refresh) — already open & active, just sync.
    if (identical(_resource, resource)) {
      if (state.isLogin) await syncRecords(true);
      return;
    } 

    // Real user switch: block UI until close+open+initial-sync completes.
    userSwitchingNotifier.value = true;
    try {
      if (_resource != null) {
        // Close the previous resource.
        AppLogger.i('Repository', "_onUserChanged close start prevId=${prevUser?.id}");
        await _resource!.close();
        AppLogger.i('Repository', "_onUserChanged close done prevId=${prevUser?.id}");
      }

      _resource = resource;
      //清空三棵树
      recordTree.rebuild([]);
      reminderTree.rebuild([]);
      tagTree.rebuild([]);

      AppLogger.i('Repository', "_onUserChanged open start id=${currUser.id}");
      await _resource!.open();
      AppLogger.i('Repository', "_onUserChanged open done id=${currUser.id}");

      if (!currUser.isGuest && prevUser != null && prevUser.isGuest) {
        AppLogger.i('Repository', "_onUserChanged merge guest data start");
        await _mergeGuestData();
        AppLogger.i('Repository', "_onUserChanged merge guest data done");
      }

      recordTree.rebuild(await db!.getAllRecords());
      AppLogger.i('Repository', "_onUserChanged rebuild done count ${recordTree.countNotifier.value}");

      userSwitchingNotifier.value = false;
      if (!currUser.isGuest && state.isLogin) {
        AppLogger.i('Repository', "_onUserChanged initial sync start");
        await syncRecords(true);
        AppLogger.i('Repository', "_onUserChanged initial sync done");
      }
    } finally {
      userSwitchingNotifier.value = false;
    }
  }

  /// Merge guest-mode data (created before any login) into the freshly opened
  /// account database, then remove the guest directory. Guest rows carry no
  /// remote_* state, so the next sync pushes them as brand-new records.
  Future<void> _mergeGuestData() async {
    final guestDir = Directory(UserManager.guest.dirAbsPath);
    if (!guestDir.existsSync()) return;
    final guestDbPath = join(guestDir.path, 'records0.db');
    if (!File(guestDbPath).existsSync()) return;
    final guestDb = createRecordsDatabase(File(guestDbPath));
    try {
      final records = await guestDb.select(guestDb.localRecords).get();
      final recycles = await guestDb.select(guestDb.recycleRecords).get();
      await db!.batch((b) {
        b.insertAllOnConflictUpdate(db!.localRecords, records);
        b.insertAllOnConflictUpdate(db!.recycleRecords, recycles);
      });
    } finally {
      await guestDb.close();
    }
    // Move attachment files (uuid-named, collisions mean same content → drop source)
    const subDirs = [FileStore.baseFilesDirName, FileStore.workFilesDirName, FileStore.recyclerFilesDirName];
    for (final sub in subDirs) {
      final src = Directory(join(guestDir.path, sub));
      if (!src.existsSync()) continue;
      final dst = join(fileStore!.rootDir, sub);
      await for (final f in src.list()) {
        if (f is! File) continue;
        final fileName = f.path.split(Platform.pathSeparator).last;
        final target = File(join(dst, fileName));
        if (target.existsSync()) {
          await f.delete();
        } else {
          await f.rename(target.path);
        }
      }
    }
    // Move assets: per-record dirs assets/{recordUuid}/{filename}
    final guestAssets = Directory(join(guestDir.path, FileStore.assetsDirName));
    if (guestAssets.existsSync()) {
      await Directory(fileStore!.assetsDir).create(recursive: true);
      await for (final uuidDir in guestAssets.list()) {
        if (uuidDir is! Directory) continue;
        final recordUuid = uuidDir.path.split(Platform.pathSeparator).last;
        final dstDir = Directory(join(fileStore!.assetsDir, recordUuid));
        await dstDir.create(recursive: true);
        await for (final f in uuidDir.list()) {
          if (f is! File) continue;
          final fileName = f.path.split(Platform.pathSeparator).last;
          final target = File(join(dstDir.path, fileName));
          if (target.existsSync()) {
            await f.delete();
          } else {
            await f.rename(target.path);
          }
        }
      }
    }
    try {
      await guestDir.delete(recursive: true);
    } catch (e) {
      AppLogger.e('Repository', "Failed to delete guest dir: $e");
    }
  }

  Future<void> syncFromBackground() async {
    if (_resource?.syncEngine?.shouldSyncFromBackground() ?? false) await syncRecords(false);
  }

  Future<void> waitForSync() async => await _resource?.syncEngine?.waitForSync();

  // =========================================================================
  // 🎯 CREATE / EDIT / DELETE — local write operations
  // =========================================================================

  Future<RecordEntry?> createRecord(
    String path,
    String name,
    bool sync,
    int fileEditAt, {
    String? uuid,
    String? reminder,
    String? tags,
  }) async {
    if (db == null || fileStore == null) return null;
    int time = DateTime.now().millisecondsSinceEpoch;
    final recordUuid = uuid ?? Uuid().v4();
    await db!.insertRecord(
      uuid: recordUuid,
      name: name,
      path: path,
      fileEditAt: fileEditAt,
      fileDirty: fileEditAt > 0 ? 1 : 0,
      editAt: time,
      createAt: time,
      reminder: reminder,
      tags: tags,
    );
    final record = (await db!.getRecord(recordUuid))!;
    await recordTree.insertRecord(record);
    AppLogger.i('Repository', "create record $recordUuid ${record.local.path}${record.local.name}");
    fileStore!.deleteWorkFile(recordUuid);
    if (sync) await syncRecords(false);
    return record;
  }

  /// Edit existing record. fileEdit=true means work file content also changed.
  /// md5: md5 of the work file content (post-encryption if locked).
  /// path/name/locked/md5: optional; when null the field is left unchanged.
  /// reminder: optional JSON string of reminder tasks; pass null to leave it unchanged.
  /// tags: optional comma-separated tag string; pass null to leave it unchanged.
  Future<RecordEntry?> editRecord(
    String uuid,
    bool fileEdit,
    int time, {
    String? path,
    String? name,
    int? locked,
    String? md5,
    String? reminder,
    String? tags,
  }) async {
    if (this.db == null) return null;
    AppDatabase db = this.db!;

    final existing = await db.getRecord(uuid);
    if (existing == null) return null;

    await db.updateRecord(
      uuid,
      path: path,
      name: name,
      md5: md5,
      editType: LocalEditType.edit,
      editAt: time,
      fileEditAt: fileEdit ? time : null,
      fileDirty: fileEdit ? 1 : null,
      locked: locked,
      reminder: reminder,
      tags: tags,
    );

    AppLogger.i(
      'Repository',
      "edit record ${existing.uuid} ${existing.local.path}${existing.local.name} version:${existing.local.version}, fileEdit:$fileEdit",
    );
    final r = await db.getRecord(uuid);
    if (r != null) await recordTree.insertRecord(r);
    final record = r;
    if (record != null) {
      unawaited(
        syncRecords(false).catchError((e) {
          AppLogger.e('Repository', "editRecord sync failed: $e");
        }),
      );
    }
    return record;
  }

  /// Soft delete: mark editType=delete and capture into recycle bin immediately
  /// (works offline too). Push conflict will undo the capture and restore the record.
  Future<void> deleteRecord(String uuid) async {
    if (this.db == null) return;
    AppDatabase db = this.db!;
    RecordEntry? record = await db.getRecord(uuid);
    int time = DateTime.now().millisecondsSinceEpoch;
    int count = await db.updateRecord(uuid, editType: LocalEditType.delete, editAt: time);
    if (count > 0) {
      // Records with no content at all (no work file and remoteMd5 empty)
      // skip the recycle bin capture.
      final hasContent = (fileStore?.isWorkFileExist(uuid) ?? false) || (record?.local.remoteMd5.isNotEmpty ?? false);
      if (hasContent) {
        await _captureToRecycler(record?.local, time);
      }
      await recordTree.deleteRecord(uuid);
      AppLogger.i(
        'Repository',
        "delete record ${record?.local.uuid} ${record?.local.path}${record?.local.name} version:${record?.local.remoteVersion}",
      );
      await syncRecords(false);
    }
  }

  /// Capture a (deleted) record into the recycle bin: metadata snapshot + move content file
  /// into the recycler folder (work file preferred, base file as fallback).
  /// Failure only logs and must not block the delete flow.
  Future<void> _captureToRecycler(LocalRecord? record, int deleteAt, {String groupId = ''}) async {
    if (record == null || db == null) return;
    try {
      await db!.insertRecycleRecord(
        uuid: record.uuid,
        path: record.path,
        name: record.name,
        reminder: record.reminder,
        tags: record.tags,
        locked: record.locked,
        deleteAt: deleteAt,
        groupId: groupId,
      );
      fileStore?.moveFileToRecycler(record.uuid);
    } catch (e) {
      AppLogger.e('Repository', "capture to recycler failed uuid=${record.uuid}: $e");
    }
  }

  /// Physically purge local records that have never been successfully synced (remoteVersion==0) and their work files.
  Future<void> purgeUnsyncedRecord(String uuid) async {
    if (db == null) return;
    final rows = await (db!.delete(
      db!.localRecords,
    )..where((t) => t.uuid.equals(uuid) & t.remoteVersion.equals(0))).go();
    if (rows == 0) return;
    fileStore?.deleteWorkFile(uuid);
    fileStore?.deleteAssetsDir(uuid);
    await recordTree.deleteRecord(uuid);
    AppLogger.w('Repository', "purge unsynced record $uuid (local creation rolled back)");
  }

  // =========================================================================
  // 🎯 RENAME FOLDER — path prefix replacement (SQL SUBSTR)
  // =========================================================================

  Future<void> renameFolder(String oldPath, String newPath) async {
    if (this.db == null) return;
    AppDatabase db = this.db!;
    final likePattern = '$oldPath%';
    final time = DateTime.now().millisecondsSinceEpoch;
    AppLogger.i('Repository', "rename folder $oldPath to $newPath");

    final tableName = db.localRecords.actualTableName;
    final localPathCol = db.localRecords.path.name;
    final editAtCol = db.localRecords.editAt.name;
    final typeCol = db.localRecords.editType.name;

    await db.customUpdate(
      'UPDATE $tableName '
      'SET $localPathCol = ? || SUBSTR($localPathCol, ?), '
      '    $editAtCol = ?, '
      '    $typeCol = ${LocalEditType.edit} '
      'WHERE $localPathCol LIKE ? AND $typeCol != ${LocalEditType.delete}',
      variables: [
        Variable.withString(newPath),
        Variable.withInt(oldPath.runes.length + 1),
        Variable.withInt(time),
        Variable.withString(likePattern),
      ],
      updates: {db.localRecords},
    );

    await recordTree.renameFolder(oldPath, newPath, time);
    await syncRecords(false);
  }

  Future<void> deleteFolder(String path) async {
    if (this.db == null || this.fileStore == null) return;
    AppDatabase db = this.db!;
    if (path.isEmpty || path == '/' || !path.endsWith('/') || !path.startsWith('/')) {
      return;
    }

    final time = DateTime.now().millisecondsSinceEpoch;
    final toCapture = await db.getUndeletedRecordsByPathPrefix(path);
    final groupId = '$path#$time';

    // DB writes in one transaction → watch fires exactly once on commit.
    try {
      await db.transaction(() async {
        final table = db.localRecords.actualTableName;
        final localPathCol = db.localRecords.path.name;
        final typeCol = db.localRecords.editType.name;
        final editAtCol = db.localRecords.editAt.name;

        await db.customUpdate(
          'UPDATE $table '
          'SET $typeCol = ${LocalEditType.delete}, $editAtCol = ? '
          'WHERE $localPathCol LIKE ?',
          variables: [Variable.withInt(time), Variable.withString('$path%')],
          updates: {db.localRecords},
        );
        for (final record in toCapture) {
          await db.insertRecycleRecord(
            uuid: record.local.uuid,
            path: record.local.path,
            name: record.local.name,
            reminder: record.local.reminder,
            tags: record.local.tags,
            locked: record.local.locked,
            deleteAt: time,
            groupId: groupId,
          );
        }
        AppLogger.w('Repository', "delete folder $path, records count:${toCapture.length}");
      });
    } catch (e) {
      AppLogger.e('Repository', "deleteFolder transaction failed path=$path: $e");
      return; // DB 失败 → 不挪文件，零 orphan
    }

    // DB 成功 → 挪文件
    for (final record in toCapture) {
      fileStore!.moveFileToRecycler(record.local.uuid);
    }

    await recordTree.deleteFolder(path);
    await syncRecords(false);
  }

  // =========================================================================
  // 🎯 CONFLICT — detection and resolution
  // =========================================================================

  Future<List<RecordEntry>> getConflictRecords() async {
    if (db == null) return [];
    return db!.getConflictRecords();
  }

  /// Resolve conflict.
  /// keepLocal=true:  keep local edits, align baseline, next push overwrites remote
  /// keepLocal=false: discard local edits, overwrite with remote version
  Future<void> resolveConflict(String uuid, bool keepLocal) async {
    if (this.db == null || this.fileStore == null) return;
    final db = this.db!;
    final fileStore = this.fileStore!;
    final record = await db.getRecord(uuid);
    if (record == null || !record.local.syncConflict) return;

    if (keepLocal) {
      // Only align baseline version, keep all local edits.
      //
      // CRITICAL: clear .1 "already uploaded" markers. The remote side may have
      // changed since our baseline (e.g. the other party edited away an image,
      // and cleanupOrphanAssets deleted it from server). KeepLocal means our
      // local content's asset list wins, and every image on that list must be
      // re-uploaded on the next push — stale .1 markers would silently skip
      // the upload and orphan images on the server forever.
      await db.updateRecord(uuid, version: record.local.remoteVersion);
      fileStore.deleteAssetMarkers(uuid);
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) await recordTree.insertRecord(refreshed);
      AppLogger.i(
        'Repository',
        "resolveConflict keepLocal uuid=$uuid align baseline to v${record.local.remoteVersion}",
      );
    } else {
      // Discard local edits, fully overwrite with remote.
      //
      // Asset handling: the remote base file (downloaded by _applyEditConflict
      // earlier in the conflict flow) is already on disk. Parse its asset
      // header and prune local assets to that set — images referenced by
      // BOTH sides are kept (no redundant download later), only local
      // additions that did not make it to the server are removed.
      await db.markSynced(uuid);
      fileStore.deleteWorkFile(uuid);
      try {
        final basePath = fileStore.getBaseFile(uuid);
        final remoteAssets = RecordSections.extractAssetNamesFromPath(basePath).toSet();
        fileStore.pruneAssetsKeepOnly(uuid, remoteAssets);
      } catch (e) {
        AppLogger.e('Repository', "resolveConflict keepRemote uuid=$uuid asset prune failed: $e");
        // Prune failure is non-fatal — leave assets as-is, user can re-sync
      }
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) await recordTree.insertRecord(refreshed);
      AppLogger.w('Repository', "resolveConflict keepRemote uuid=$uuid overwritten, remoteV=${record.remote.version}");
    }

    final remaining = await db.getConflictRecords();
    if (remaining.isEmpty) {
      syncStateNotifier.value = SyncState(state: SyncState.success);
    }
    await syncRecords(false);
  }

  // =========================================================================
  // 🎯 SYNC — delegate to SyncEngine
  // =========================================================================

  Future<void> syncRecords(bool forcePull) async {
    final engine = _resource?.syncEngine;
    if (engine == null) return;
    await engine.sync(forcePull);
  }

  // =========================================================================
  // 🎯 RECYCLE BIN — list / restore / purge / clear
  // =========================================================================

  /// All recycle bin entries, newest deletion first.
  Future<List<RecycleRecord>> getRecycleRecords() async => await db?.getRecycleRecords() ?? [];

  Future<List<({String folderPath, int deleteAt, int count, String groupId})>> getRecycleFolderGroups() async =>
      await db?.getRecycleFolderGroups() ?? [];

  Future<List<RecycleRecord>> getRecycleSingleRecords() async => await db?.getRecycleSingleRecords() ?? [];

  /// Restore a single recycle bin entry: move the content file back into the work folder
  /// and bring the record back as a local edit (uuid unchanged), pushed to the server on next sync.
  /// Always restores ONLY this one entry — if you deleted a whole folder, use [restoreRecycleGroup] instead.
  Future<bool> restoreRecycleRecord(String uuid) async {
    final db = this.db;
    final fileStore = this.fileStore;
    if (db == null || fileStore == null) return false;

    final entry = await db.getRecycleRecord(uuid);
    if (entry == null) return false;
    final ok = await _restoreRecycleRecords([
      entry,
    ], operateLabel: "restore record ${entry.uuid} ${entry.path}${entry.name}");
    if (ok) unawaited(syncRecords(false));
    return ok;
  }

  /// Restore all entries from a folder-delete group. The groupId format is `/Folder/#timestamp`.
  /// Files are moved first (atomic rename), then DB transaction writes — never a window where
  /// DB says restored but the file is still missing from the work dir.
  Future<bool> restoreRecycleGroup(String groupId) async {
    final db = this.db;
    final fileStore = this.fileStore;
    if (db == null || fileStore == null) return false;

    final groupEntries = await db.getRecycleRecordsByGroup(groupId);
    if (groupEntries.isEmpty) return false;
    final folderPath = groupId.split('#').first;
    final ok = await _restoreRecycleRecords(
      groupEntries,
      operateLabel: "restore folder group $folderPath, count:${groupEntries.length}",
    );
    if (ok) unawaited(syncRecords(false));
    return ok;
  }

  /// Shared restore pipeline for any batch of recycle entries.
  /// Phase 1: validate + rename recycler → work (atomic per file).
  /// Phase 2: one DB transaction — rollback file moves on failure.
  /// Phase 3: refresh tree.
  Future<bool> _restoreRecycleRecords(List<RecycleRecord> entries, {required String operateLabel}) async {
    final db = this.db;
    final fileStore = this.fileStore;
    if (db == null || fileStore == null) return false;
    
    // Phase 1: validate + rename files from recycler → work.
    final time = DateTime.now().millisecondsSinceEpoch;
    final okEntries = <RecycleRecord>[];
    for (final entry in entries) {
      final existing = await db.getRecord(entry.uuid);
      if (existing != null && existing.local.editType != LocalEditType.delete) continue;
      fileStore.moveRecyclerFileToWork(entry.uuid);
      okEntries.add(entry);
    }
    if (okEntries.isEmpty) return false;

    // Phase 2: DB transaction — watch fires exactly once on commit.
    try {
      await db.transaction(() async {
        for (final entry in okEntries) {
          final hasFile = fileStore.isWorkFileExist(entry.uuid);
          await db.restoreRecord(
            uuid: entry.uuid,
            name: entry.name,
            path: entry.path,
            locked: entry.locked,
            reminder: entry.reminder,
            tags: entry.tags,
            fileEditAt: hasFile ? time : 0,
            fileDirty: hasFile ? 1 : 0,
            baseFileVersion: 0,
            editAt: time,
            createAt: time,
          );
          await db.deleteRecycleRecord(entry.uuid);
        }
        AppLogger.i('Repository', operateLabel);
      });
    } catch (_) {
      // DB rolled back — move files back to recycler so they match DB state.
      for (final entry in okEntries) {
        fileStore.moveWorkFileToRecycler(entry.uuid);
      }
      rethrow;
    }

    // Phase 3: refresh tree — insertRecord auto-creates parent folders
    for (final entry in okEntries) {
      final record = await db.getRecord(entry.uuid);
      if (record != null) await recordTree.insertRecord(record);
    }
    return true;
  }

  /// Permanently delete a single recycle bin entry (metadata row + recycler content file).
  /// Always purges ONLY this one entry — for folder groups, use [purgeRecycleGroup].
  Future<void> purgeRecycleRecord(String uuid) async {
    final db = this.db;
    if (db == null) return;
    await db.deleteRecycleRecord(uuid);
    fileStore?.deleteRecyclerFile(uuid);
    fileStore?.deleteAssetsDir(uuid);
    AppLogger.w('Repository', "purge recycler record $uuid");
  }

  /// Permanently delete all entries from a folder-delete group.
  Future<void> purgeRecycleGroup(String groupId) async {
    final db = this.db;
    if (db == null) return;
    final groupEntries = await db.getRecycleRecordsByGroup(groupId);
    await db.deleteRecycleRecordsByGroup(groupId);
    for (final e in groupEntries) {
      fileStore?.deleteRecyclerFile(e.uuid);
      fileStore?.deleteAssetsDir(e.uuid);
    }
    AppLogger.w('Repository', "purge folder recycler group $groupId, count:${groupEntries.length}");
  }

  /// Empty the recycle bin: delete all metadata rows and recycler content files.
  Future<void> clearRecycleRecords() async {
    final db = this.db;
    if (db == null) return;
    final rows = await db.getRecycleRecords();
    await db.clearRecycleRecords();
    for (final row in rows) {
      fileStore?.deleteRecyclerFile(row.uuid);
      fileStore?.deleteAssetsDir(row.uuid);
    }
    AppLogger.w('Repository', "clear recycler records, count:${rows.length}");
  }
  
}
