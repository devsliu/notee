// Sync engine: complete sync state machine (lock + state + pull + push), Repository only does thin forwarding.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/file_store.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/remote_record.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/filesync/sync_exception.dart';
import 'package:notee/filesync/user.dart';
import 'package:notee/utils/serial_task_queue.dart';
class SyncState {
  static const int idle = 0;
  static const int syncing = 1;
  static const int success = 2;
  static const int error = 3;
  final int state;
  final String message;
  final int errorCode; // Only present when state=error, from SyncException.code

  SyncState({required this.state, this.message = "", this.errorCode = SyncException.unknown});
  bool get isError => state == error;
  bool get isConflict => state == error && errorCode == HttpApi.kResultErrorRecordConflict;
  bool get isAuthError => state == error && (errorCode == 401 || errorCode == HttpApi.kResultErrorUserPasswordError);
}

class SyncEngine {
  static const int fetchLimit = 200;

  final AppDatabase db;
  final FileStore fileStore;
  RecordTree? recordTree;
  final ValueNotifier<SyncState> syncStateNotifier;

  final _syncQueue = SingleSerialTaskQueue();
  bool _pendingForcePull = false;
  DateTime? _lastSuccessfulPullTime;
  final Duration _syncInterval = Duration(minutes: 1);
  bool _closed = false;

  DateTime? get lastSuccessfulPullTime => _lastSuccessfulPullTime;

  SyncEngine({required this.db, required this.fileStore, required this.recordTree, required this.syncStateNotifier});

  Future<void> close() async {
    _closed = true;
    recordTree = null;
    // Await the in-flight sync task so pullRecords/pushRecords finish their
    // current DB transaction (or bail at the next _closed check) BEFORE
    // Repository.close() shuts down the db. Closing the db mid-transaction
    // causes CouldNotRollBackException and an unhandled "database already
    // closed" error in drift's isolate. The HTTP request in flight will
    // complete (subject to _receiveTimeout), then the queue drains on _closed.
    await _syncQueue.wait();
  }

  Future<void> waitForSync() async {
    await _syncQueue.wait();
  }

  bool shouldSyncFromBackground() {
    if (_lastSuccessfulPullTime == null) return true;
    return DateTime.now().difference(_lastSuccessfulPullTime!) >= _syncInterval;
  }

  // =========================================================================
  // 🎯 SYNC — queue-based state machine (lock + state + pull + push)
  // =========================================================================

  Future<void> sync(bool forcePull) async {
    if (_closed) {
      AppLogger.i('SyncEngine', "sync skipped — engine closed");
      return;
    }
    if (!UserManager.current.isLoggedIn) {
      AppLogger.i('SyncEngine', "sync skipped — user not logged in");
      return;
    }

    if (forcePull) {
      _lastSuccessfulPullTime = null;
      _pendingForcePull = true;
    }

    // If a sync is already in flight, coalesce: don't enqueue another; just
    // wait for the queue to drain. The _pendingForcePull flag is already set
    // above — the executing task (or the next queued one) will pick it up.
    if (!_syncQueue.isIdle) {
      AppLogger.i('SyncEngine', "sync coalesced — waiting for queue drain");
      return _syncQueue.wait();
    }

    return _syncQueue.submit(() async {
      // Capture forcePull flag at the START of execution so queued tasks also
      // pick up forcePull requests made while they were pending.
      if (_pendingForcePull) {
        _lastSuccessfulPullTime = null;
        _pendingForcePull = false;
      }
      if (_closed) return;
      try {
        await _runSync();
      } catch (e) {
        AppLogger.e('SyncEngine', e.toString());
        if (e is SyncException) {
          syncStateNotifier.value = SyncState(state: SyncState.error, message: e.message, errorCode: e.code);
        } else {
          syncStateNotifier.value = SyncState(
            state: SyncState.error,
            message: e.toString(),
            errorCode: SyncException.unknown,
          );
        }
      }
    });
  }

  Future<void> _runSync() async {
    syncStateNotifier.value = SyncState(state: SyncState.syncing);

    DateTime now = DateTime.now();
    if (_lastSuccessfulPullTime == null || now.difference(_lastSuccessfulPullTime!) >= _syncInterval) {
      if (!_closed) await pullRecords();
      _lastSuccessfulPullTime = now;
    } else {
      AppLogger.i('SyncEngine', "pull skipped (interval not reached)");
    }

    if (!_closed) await pushRecords();
    if (_closed) return;

    // Check conflicts again after push
    var conflictList = await db.getConflictRecords();
    if (conflictList.isNotEmpty) {
      syncStateNotifier.value = SyncState(
        state: SyncState.error,
        message: "Note conflict",
        errorCode: HttpApi.kResultErrorRecordConflict,
      );
      return;
    }

    syncStateNotifier.value = SyncState(state: SyncState.success);
    AppLogger.i('SyncEngine', "sync completed successfully");
  }

  // =========================================================================
  // 🎯 PULL — pull remote data, write to remote_*, detect conflicts
  // =========================================================================

  Future<void> saveRemoteRecords(List<RemoteRecord> remoteRecords, int? batchNo, AppDatabase db) async {
    if (remoteRecords.isEmpty) return;
    final List<String> deleteUuids = [];
    final List<String> upsertUuids = [];
    int conflictCount = 0;
    int skipCount = 0;
    // Local file operations (fast, no network): delete/move files
    final List<void Function()> fileActions = [];
    // Base file downloads (slow, need HTTP): dedup with Set, only download once per uuid
    final Set<String> downloadUUids = {};

    await db.transaction(() async {
      final remoteUuids = remoteRecords.map((e) => e.uuid).toList();
      final localList = await (db.select(db.localRecords)..where((t) => t.uuid.isIn(remoteUuids))).get();
      final localMap = {for (var e in localList) e.uuid: e};

      for (var remote in remoteRecords) {
        var local = localMap.remove(remote.uuid);

        // === Local does not exist ===
        if (local == null) {
          if (remote.deleteAt > 0) {
            // Remote already deleted, no need to handle
            skipCount++;
            continue;
          }
          // Remote not deleted, save directly
          var newRecord = remote.toLocalRecord(batchNo ?? 0);
          await db.replaceRecord(newRecord);
          upsertUuids.add(newRecord.uuid);
          downloadUUids.add(remote.uuid);
        }
        // === Remote already deleted ===
        else if (remote.deleteAt > 0) {
          if (local.editType == LocalEditType.delete || local.editType == LocalEditType.none) {
            // Local deleted or local not modified: delete directly
            await db.deleteRecord(remote.uuid);
            deleteUuids.add(remote.uuid);
            fileActions.add(() {
              fileStore.deleteBaseFile(remote.uuid);
              fileStore.deleteWorkFile(remote.uuid);
              fileStore.deleteAssetsDir(remote.uuid);
            });
          } else {
            // Local modified, remote deleted, will push later
            // Remote already deleted, this one needs to be pushed to server later
            // Clear remote_* so push treats it as a new record via upsertRecord
            await db.clearRecordRemote(remote.uuid, batchNo: batchNo);
            upsertUuids.add(remote.uuid);
            // If local has no work file, try to copy downloaded source file to work file directory
            fileActions.add(() => fileStore.moveBaseFileToWorkIfWorkFileNotExist(remote.uuid));
          }
        }
        // === Remote not deleted ===
        else if (local.editType == LocalEditType.delete || local.editType == LocalEditType.none) {
          // ---- Local deleted or local not modified ----
          if (remote.version > local.remoteVersion) {
            // Remote version updated, undo local delete / align local state (handled by one replaceLocalRecord)
            var newRecord = remote.toLocalRecord(batchNo ?? 0, baseFileVersion: local.baseFileVersion);
            await db.replaceRecord(newRecord);
            // Record is alive again from remote: undo the recycle-bin capture made at delete time
            await db.deleteRecycleRecord(remote.uuid);
            upsertUuids.add(newRecord.uuid);
            fileActions.add(() {
              fileStore.deleteRecyclerFile(remote.uuid);
              fileStore.deleteWorkFile(remote.uuid);
            });
            // Server file updated, download latest base (judge by fileVersion)
            if (local.baseFileVersion < remote.fileVersion) {
              downloadUUids.add(remote.uuid);
            }
          } else {
            // Remote version unchanged: record exists locally and is up to date.
            // During full sync, refresh batchNo so cleanup doesn't delete it.
            // During incremental sync, nothing to write — skip the DB call.
            skipCount++;
            if (batchNo != null) {
              await db.updateRecord(remote.uuid, batchNo: batchNo);
            }
          }
        }
        // Remote modified, local modified → conflict
        else if (remote.version > local.remoteVersion) {
          final version = local.version;
          // Remote version advanced → conflict
          await db.updateRecordRemote(remote.uuid, remote, batchNo: batchNo);
          // Base file modified, download latest base for diff comparison (judge by fileVersion)
          if (local.baseFileVersion < remote.fileVersion) {
            downloadUUids.add(remote.uuid);
          }
          upsertUuids.add(remote.uuid);
          conflictCount++;
          AppLogger.w(
            'SyncEngine',
            "conflict record ${remote.uuid} ${remote.path}${remote.name} remoteV:${remote.version} localV:$version",
          );
        }
        // Remote version unchanged (local has edits): keep local edits.
        // During full sync, refresh batchNo so cleanup treats it as seen;
        // during incremental sync, no DB write needed.
        else {
          skipCount++;
          if (batchNo != null) {
            await db.updateRecord(remote.uuid, batchNo: batchNo);
          }
        }
      }
    }); // transaction ends, release DB lock

    // Re-read the latest records from DB before updating the tree. A concurrent
    // local edit (editRecord/deleteRecord etc.) blocks on the DB lock during our
    // transaction and runs right after commit, so the rows written inside the
    // transaction may already be stale. Feeding stale snapshots to the tree
    // would desync it from DB (e.g. tree shows editType=none while DB has
    // editType=edit). Re-reading guarantees tree always mirrors DB.
    final List<RecordEntry> finalRecords = upsertUuids.isEmpty
        ? <RecordEntry>[]
        : await db.getRecordsByUuids(upsertUuids);

    await recordTree?.batchUpdateRecords(deleteUuids, finalRecords);
    // UI already updated, run file actions in background without blocking sync return.
    // When user opens a record, loadContent will wait for downloadBaseFile internally (dedup by uuid).
    // Download failures must log, otherwise file loss goes unnoticed until user opens the record.

    // 1. Local file operations (fast, no network, synchronous execution)
    for (final action in fileActions) {
      try {
        action();
      } catch (e) {
        AppLogger.e('SyncEngine', "saveRemoteRecords local file action failed: $e");
      }
    }

    // 2. Base file downloads (slow, need HTTP, fire-and-forget)
    // When user opens a record, loadContent will wait for downloadBaseFile internally (dedup by uuid).
    unawaited(fileStore.downloadBaseFiles(downloadUUids));

    AppLogger.log(
      conflictCount > 0 || deleteUuids.isNotEmpty ? AppLogger.levelWarn : AppLogger.levelInfo,
      'SyncEngine',
      "saveRemoteRecords done: total=${remoteRecords.length} "
          "saved=${upsertUuids.length} deleted=${deleteUuids.length} "
          "conflict=$conflictCount skip=$skipCount download=${downloadUUids.length}",
    );
  }

  Future<void> pullRecords() async {
    var batchNo = DateTime.now().millisecondsSinceEpoch;
    var lastVersion = await db.getConfigInt(KVConfigs.lastSyncedVersion, 0);
    var maxVersion = 0;
    bool isInFullPull = lastVersion <= 0;
    int purgedVersion = 0;
    int totalPulled = 0;

    while (true) {
      if (_closed) {
        AppLogger.w('SyncEngine', "pullRecords aborted — engine closed");
        break;
      }
      var fetchRecords = await HttpApi.fetchRecords(lastVersion, fetchLimit, fullSync: isInFullPull);
      if (!fetchRecords.isSuccess()) {
        // 服务端 537: 客户端 version 低于 purgedVersion, 墓碑已被物理删除,
        // 必须重置 lastVersion=0 走全量同步, 否则会出现幽灵记录
        if (fetchRecords.code == HttpApi.kResultErrorNeedFullSync) {
          AppLogger.w('SyncEngine', "server require full pull (537)");
          isInFullPull = true;
          lastVersion = 0;
          purgedVersion = 0; // 全量拉取时从返回结果中获取
          continue;
        }
        throw SyncException(fetchRecords.message, null, fetchRecords.code);
      }

      // 全量模式下记录 purgedVersion, 用于同步完成后清理本地已被服务端 purge 的记录
      if (isInFullPull && purgedVersion == 0) {
        purgedVersion = fetchRecords.data!.purgedVersion;
      }

      final remoteRecords = fetchRecords.data!.records;
      if (remoteRecords.isNotEmpty) {
        await saveRemoteRecords(remoteRecords, isInFullPull ? batchNo : null, db);
        totalPulled += remoteRecords.length;
        lastVersion = remoteRecords.map((t) => t.version).reduce(math.max);
        maxVersion = lastVersion;
      } else {
        // 之前用 remoteRecords.length < fetchLimit 判断结束: 若服务端提前返回部分批次
        // (实际还有数据), 会导致循环提前退出、lastSyncedVersion 被保存为不完整值,
        // 下次增量同步跳过剩余记录, 出现"同步成功但笔记缺失"的问题。
        await db.setIntValue(KVConfigs.lastSyncedVersion, lastVersion);
        break;
      }
    }

    // 仅在全量拉取完整完成时才清理: 若拉取被中断(_closed 或版本号不前进),
    // 本地仍有未拉取的服务端记录, 此时清理会误删 batchNo 不匹配的有效记录。
    if (isInFullPull) {
      var list =
          await (db.select(db.localRecords)..where(
                (t) =>
                    (t.batchNo.equals(batchNo).not()) &
                    (t.remoteVersion.isSmallerOrEqualValue(math.min(maxVersion, purgedVersion))) &
                    (t.editType.equals(LocalEditType.none)),
              ))
              .get();
      var uuids = list.map((e) => e.uuid).toList();
      // DB 先删, 成功后再刷树、删文件: DB 失败时树与文件原样保留, 下次全量同步重试, 不留幽灵行
      int count = await db.deleteRecordsByUuids(uuids);
      if (count > 0) {
        await recordTree?.batchUpdateRecords(uuids, []);

        for (var uuid in uuids) {
          fileStore.deleteBaseFile(uuid);
          fileStore.deleteWorkFile(uuid);
          fileStore.deleteAssetsDir(uuid);
        }
      }
      AppLogger.w('SyncEngine', "full pull and delete $count records, purge version:$purgedVersion");
    }
    AppLogger.i('SyncEngine', "pullRecords done, totalPulled=$totalPulled");
  }

  // =========================================================================
  // 🎯 PUSH — upload local edits to server
  // =========================================================================

  /// Build an UpsertRecordItem from a local edit entry, sending only the
  /// metadata fields that actually changed (so the server leaves the rest
  /// untouched). File-related fields (md5/fileEditAt) are NOT included —
  /// batch upsert is metadata-only.
  UpsertRecordItem _buildUpsertItem(RecordEntry entry) {
    final isNewRecord = entry.local.version == 0;
    return UpsertRecordItem(
      uuid: entry.uuid,
      editAt: entry.local.editAt,
      version: entry.local.version,
      path: entry.local.path != entry.remote.path ? entry.local.path : null,
      name: entry.local.name != entry.remote.name ? entry.local.name : null,
      createAt: isNewRecord ? entry.local.createAt : null,
      locked: entry.local.locked != entry.remote.locked ? entry.local.locked : null,
      reminder: entry.local.reminder != entry.remote.reminder ? entry.local.reminder : null,
      tags: entry.local.tags != entry.remote.tags ? entry.local.tags : null,
    );
  }

  /// Apply a successful upsert result to the local DB / tree.
  /// [fileUploaded] indicates whether a content file was uploaded (controls
  /// baseFileVersion update and work→base file move).
  /// Returns (pushed, logMsg): pushed=true if the edit was counted (rows > 0),
  /// logMsg is the per-record log line when pushed (null on concurrent edit).
  Future<(bool, String?)> _applyEditSuccess(RecordEntry entry, RemoteRecord newRemote, bool fileUploaded) async {
    final newRecord = newRemote.toLocalRecord(
      0,
      baseFileVersion: fileUploaded ? newRemote.fileVersion : entry.local.baseFileVersion,
    );
    final rows =
        await (db.update(db.localRecords)..where(
              (t) =>
                  t.uuid.equals(entry.local.uuid) &
                  t.editAt.equals(entry.local.editAt) &
                  t.editType.equals(entry.local.editType),
            ))
            .write(newRecord);
    if (rows == 0) {
      // Concurrent edit: only update remote_*, keep local edits
      await db.updateRecordRemote(entry.local.uuid, newRemote, version: newRemote.version);
      final merged = await db.getRecord(entry.local.uuid);
      if (merged != null) await recordTree?.insertRecord(merged);
      return (false, null);
    }
    final logMsg =
        "edit record ${newRecord.uuid} ${newRecord.path}${newRecord.name} version:${newRecord.remoteVersion}";
    await recordTree?.insertRecord(RecordEntry(newRecord));
    if (fileUploaded) {
      fileStore.moveWorkFileToBase(entry.local.uuid);
    }
    return (true, logMsg);
  }

  /// Apply a conflict (531) result: refresh remote fields and download the
  /// base file if the server has a newer file version.
  Future<void> _applyEditConflict(RecordEntry entry, RemoteRecord remote) async {
    await db.updateRecordRemote(entry.local.uuid, remote);
    if (entry.local.baseFileVersion < remote.fileVersion) {
      await fileStore.downloadBaseFile(entry.local.uuid);
    }
    final refreshed = await db.getRecord(entry.local.uuid);
    if (refreshed != null) await recordTree?.insertRecord(refreshed);
  }

  /// Upload the assets referenced by a record's work file to the server.
  /// Reads the plaintext asset header line, then for each filename: HEAD-check
  /// the server and PUT only missing files. Failures are logged, not thrown.
  Future<void> _uploadRecordAssets(String uuid, String workFilePath) async {
    final file = File(workFilePath);
    if (!file.existsSync()) return;
    final names = RecordSections.extractAssetNamesFromPath(workFilePath);
    if (names.isEmpty) return;
    for (final name in names) {
      if (_closed) break;
      final localPath = fileStore.getAssetPath(uuid, name);
      if (!File(localPath).existsSync()) continue;
      // Local marker `<name>.1` means the asset is already on the server;
      // skip the HTTP HEAD check entirely.
      if (fileStore.hasAssetMarker(uuid, name)) continue;
      // HTTP HEAD first — if the server already has this asset, skip PUT.
      try {
        if (await HttpApi.headAsset(uuid, name)) {
          fileStore.markAssetUploaded(uuid, name);
          continue;
        }
      } catch (_) {} // offline / retry exhausted → fall through to PUT
      try {
        final result = await HttpApi.uploadAsset(uuid, name, localPath);
        if (result.isSuccess()) {
          fileStore.markAssetUploaded(uuid, name);
        } else {
          AppLogger.e('SyncEngine', "upload asset failed uuid=$uuid name=$name: ${result.message}");
        }
      } catch (e) {
        AppLogger.e('SyncEngine', "upload asset exception uuid=$uuid name=$name: $e");
      }
    }
  }

  Future<void> pushRecords() async {
    int pushedDeletes = 0;
    int pushedEdits = 0;
    int conflicts = 0;
    // Push deletions first (batch)
    final deleteEntries = await db.getDeleteRecords();
    if (deleteEntries.isNotEmpty) {
      if (_closed) return;
      final items = deleteEntries.map((e) => (uuid: e.local.uuid, version: e.local.remoteVersion)).toList();
      final deleteResp = await HttpApi.deleteRecords(items);
      if (!deleteResp.isSuccess()) {
        throw SyncException(deleteResp.message, null, deleteResp.code);
      }
      final results = deleteResp.data!;
      final resultByUuid = {for (final r in results) r.uuid: r};
      final errors = <String>[];
      final logs = <String>[];
      for (final entry in deleteEntries) {
        final result = resultByUuid[entry.local.uuid];
        if (result == null) {
          errors.add("missing delete result for ${entry.local.uuid}");
          continue;
        }
        if (result.isSuccess() || result.code == HttpApi.kResultErrorRecordNotFound) {
          await db.deleteRecord(entry.local.uuid);
          await recordTree?.deleteRecord(entry.local.uuid);
          fileStore.deleteBaseFile(entry.local.uuid);
          fileStore.deleteWorkFile(entry.local.uuid);
          //dont delete asset files, only delete markers, so restore can re-upload assets
          fileStore.deleteAssetMarkers(entry.local.uuid);
          pushedDeletes++;
          logs.add(
            "delete record ${entry.local.uuid} ${entry.local.path}${entry.local.name} version:${entry.local.remoteVersion}",
          );
        } else if (result.code == HttpApi.kResultErrorRecordConflict) {
          conflicts++;
          try {
            fileStore.moveRecyclerFileToWork(entry.local.uuid);
            await db.deleteRecycleRecord(entry.local.uuid);
            fileStore.deleteAssetMarkers(entry.local.uuid);
            logs.add("undo recycler capture uuid=${entry.local.uuid}");
          } catch (e) {
            logs.add("undo recycler capture failed uuid=${entry.local.uuid}: $e");
          }
          final remote = result.data!;
          final newRecord = remote.toLocalRecord(0, baseFileVersion: entry.local.baseFileVersion);
          int rows = await db.replaceRecord(newRecord);
          if (entry.local.baseFileVersion < remote.fileVersion) {
            await fileStore.downloadBaseFile(entry.local.uuid);
          }
          if (rows > 0) await recordTree?.insertRecord(RecordEntry(newRecord));
        } else {
          errors.add("delete ${entry.local.uuid} failed: code=${result.code} ${deleteResp.message}");
        }
      }
      if (logs.isNotEmpty) {
        AppLogger.w('SyncEngine', logs.join("\n"));
      }
      if (errors.isNotEmpty) {
        throw SyncException(errors.join("; "), null, 0);
      }
    }

    final noFileEdits = (await db.getEditRecordsWithoutFileEdit()).where((e) => !e.local.syncConflict).toList();
    if (noFileEdits.isNotEmpty) {
      if (_closed) return;
      final items = noFileEdits.map(_buildUpsertItem).toList();
      final batchResp = await HttpApi.upsertRecords(items);
      if (!batchResp.isSuccess()) {
        throw SyncException(batchResp.message, null, batchResp.code);
      }
      final results = batchResp.data!;
      final resultByUuid = {for (final r in results) r.uuid: r};
      final errors = <String>[];
      final logs = <String>[];
      for (final entry in noFileEdits) {
        final result = resultByUuid[entry.local.uuid];
        if (result == null) {
          errors.add("missing upsert result for ${entry.local.uuid}");
          continue;
        }
        if (result.isSuccess()) {
          final (pushed, logMsg) = await _applyEditSuccess(entry, result.data!, false);
          if (pushed) pushedEdits++;
          if (logMsg != null) logs.add(logMsg);
        } else if (result.code == HttpApi.kResultErrorRecordConflict) {
          conflicts++;
          await _applyEditConflict(entry, result.data!);
        } else {
          errors.add("upsert ${entry.local.uuid} failed: code=${result.code} ${batchResp.message}");
        }
      }
      if (logs.isNotEmpty) {
        AppLogger.i('SyncEngine', logs.join("\n"));
      }
      if (errors.isNotEmpty) {
        throw SyncException(errors.join("; "), null, 0);
      }
    }

    // ---- 2. Individual push for edits with file content change ----
    for (var entry in await db.getEditRecordsWithFileEdit()) {
      if (_closed) return;
      if (entry.local.syncConflict) continue;

      final file = File(fileStore.getWorkFile(entry.local.uuid));
      final fileExist = file.existsSync();

      // Upload referenced assets first (HEAD-check then PUT) so the server
      // never receives content referencing missing files.
      if (fileExist) {
        await _uploadRecordAssets(entry.local.uuid, file.absolute.path);
      }

      final item = _buildUpsertItem(entry);
      final result = await HttpApi.upsertRecord(
        item,
        filePath: fileExist ? file.absolute.path : null,
        fileEditAt: fileExist ? entry.local.fileEditAt : null,
      );

      if (result.isSuccess()) {
        final (pushed, logMsg) = await _applyEditSuccess(entry, result.data!, fileExist);
        if (pushed) pushedEdits++;
        if (logMsg != null) AppLogger.i('SyncEngine', logMsg);
      } else if (result.code == HttpApi.kResultErrorRecordConflict) {
        conflicts++;
        await _applyEditConflict(entry, result.data!);
      } else {
        throw SyncException(result.message, null, result.code);
      }
    }
    if (pushedDeletes > 0 || conflicts > 0 || pushedEdits > 0) {
      AppLogger.log(
      pushedDeletes > 0 || conflicts > 0 ? AppLogger.levelWarn : AppLogger.levelInfo,
      'SyncEngine',
      "pushRecords done, deletes=$pushedDeletes, edits=$pushedEdits, conflicts=$conflicts",
    );
    }
  }
}
