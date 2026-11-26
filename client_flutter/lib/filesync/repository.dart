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
import 'package:notee/filesync/sync_configs.dart';
import 'package:notee/filesync/sync_engine.dart' show SyncEngine, SyncState;
import 'package:notee/filesync/backends/backend_manager.dart';
import 'package:notee/filesync/backends/sync_backend.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/serial_task_queue.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 本地笔记目录（固定，所有 backend 共享）。
/// Backend 只管"往哪个服务器同步"，不切本地目录。
const _recordsSubDir = 'records';

class Repository {
  static const recyclerExpireDays = 30;
  static const int fetchLimit = 200;

  static Repository? _instance;

  /// 全局应用根目录（Repository.init 时拿到）。
  late final String appRootDir;

  /// 本地笔记目录（固定，所有 backend 共享）。
  late final String dataDir;

  // =========================================================================
  // 本地资源 —— 固定，不随 backend 切换
  // =========================================================================

  late final AppDatabase db;
  late final FileStore fileStore;
  late final SearchIndex searchIndex;

  StreamSubscription<int>? recyclerCountSub;
  StreamSubscription<ContentFileEvent>? searchIndexSub;

  // =========================================================================
  // 同步相关 —— backend 切换时重建
  // =========================================================================

  SyncBackend? backend;
  SyncEngine? syncEngine;
  final SyncConfigs syncConfigs = SyncConfigs();

  // =========================================================================
  // UI 状态
  // =========================================================================

  final RecordTree recordTree = RecordTree();
  final ReminderTree reminderTree = ReminderTree();
  final TagTree tagTree = TagTree();
  final ValueNotifier<SyncState> syncStateNotifier = ValueNotifier(SyncState(state: SyncState.idle));
  final ValueNotifier<int> recyclerCountNotifier = ValueNotifier(0);

  /// True while a backend switch is in progress. UI uses this to show a loading overlay.
  final ValueNotifier<bool> backendSwitchingNotifier = ValueNotifier(false);

  Repository._() {
    reminderTree.bind(recordTree);
    tagTree.bind(recordTree);
  }
  static Repository get() => _instance!;

  // =========================================================================
  // INIT —— 只建一次本地资源
  // =========================================================================

  static Future<void> init(String appRootDir) async {
    if (_instance != null) return;
    final repo = Repository._()
      ..appRootDir = appRootDir
      ..dataDir = join(appRootDir, _recordsSubDir);
    _instance = repo;

    // 确保 notes 目录存在
    await Directory(repo.dataDir).create(recursive: true);

    // 建本地 db / fileStore / searchIndex（固定目录，所有 backend 共享）
    await repo._openLocal();

    // 恢复上次登录的 backend（如果有），没有则保持 guest
    final backend = await BackendManager.restore();
    if (backend != null) {
      repo.setBackend(backend);
    }
  }

  Future<void> _openLocal() async {
    AppLogger.i('Repository', "open local dataDir=$dataDir");
    final cacheDir = (await getApplicationCacheDirectory()).path;
    fileStore = FileStore(dataDir, cacheDir);
    db = createRecordsDatabase(File(join(dataDir, 'records0.db')));
    fileStore.db = db;
    // 注意：此处不接 backend。Repository.backend 此时恒为 null（backend 在
    // _openLocal 之后才由 BackendManager.restore 恢复，再经 setBackend → switchBackend 接入）。

    // 清理过期回收站
    final threshold = DateTime.now().millisecondsSinceEpoch - recyclerExpireDays * 24 * 60 * 60 * 1000;
    final expired = await db.purgeRecycleRecordsBefore(threshold);
    for (final row in expired) {
      fileStore.deleteRecyclerFile(row.uuid);
      fileStore.deleteAssetsDir(row.uuid);
    }
    if (expired.isNotEmpty) {
      AppLogger.w('Repository', "auto-purged ${expired.length} expired recycler entries (>30d)");
    }

    searchIndex = SearchIndex(File(join(dataDir, 'search0.db')), fileStore);
    await searchIndex.open();

    searchIndexSub = fileStore.onContentChanged.listen((event) async {
      await searchIndex.refresh(event.uuid);
    });

    recyclerCountSub = db.watchRecycleCount().listen((c) => recyclerCountNotifier.value = c);

    recordTree.rebuild(await db.getAllRecords());

    // 加载本地 sync configs 缓存（guest 模式也要能读 readOnlyFolders 等本地配置）。
    // 若之后 restore 了 backend，setBackend 会再 load(db, backend:) 覆盖。
    await syncConfigs.load(db);
  }

  // =========================================================================
  // BACKEND SWITCH —— 只换同步目标，不切本地目录
  // =========================================================================

  /// setBackend 串行队列：登录/登出/切后端严格串行，防止 reset 与 engine 重建交错。
  /// setBackend 是"状态赋值"——最新调用代表期望终态，所以 maxPending=1 + dropOldest：
  /// 最多一个排队，更新的调用到来时丢弃排队中的旧切换（其 future 正常完成）。
  /// 正在执行的任务不会被中断，reset/engine 重建始终原子跑完。
  final _setBackendQueue = SingleSerialTaskQueue(maxPending: 1, overflowStrategy: QueueOverflowStrategy.dropOldest);

  Future<void> setBackend(SyncBackend? newBackend) {
    return _setBackendQueue.submit(() async {
      // 落盘当前 backend（null = 游客）。backend 内部 token 变化时由它自己
      // 调 BackendManager.save(this)，无需再注入回调。
      BackendManager.save(newBackend);
      await _onBackendChanged(newBackend);
    });
  }

  Future<void> _onBackendChanged(SyncBackend? newBackend) async {
    AppLogger.i('Repository', "_onBackendChanged ${backend?.name ?? 'Guest'} → ${newBackend?.name ?? 'Guest'}");

    // 同一个 backend 实例 —— 不重建，只做同步
    if (backend == newBackend && newBackend != null) {
      await syncRecords(true);
      return;
    }

    backendSwitchingNotifier.value = true;
    final oldBackend = backend;
    try {
      // 停掉旧的 SyncEngine
      await syncEngine?.close();
      syncEngine = null;

      // 作废并排空 FileStore 里绑定旧 backend 的在飞下载（中断 HTTP、重建队列/client、
      // 等旧任务全部收尾），必须在下面的 remote 状态重置之前完成 —— 否则旧下载在重置
      // 之后写回 baseFileVersion / asset 标记会复活旧后端基准。启动恢复/游客登录时
      // 旧 backend 为 null，内部走直接换引用的快路径，无销毁开销。
      await fileStore.switchBackend(newBackend);

      // 清掉旧 backend 的 remote 状态 —— 避免新 backend 继承旧版本号
      // 注意：只有旧 backend 非 null 时才清空。
      //   - app 启动恢复 backend：此时 backend == null，remote 字段属于刚恢复的
      //     同一个 backend，必须保留以支持增量同步，不能清空。
      //   - 游客首次登录：remote 本来就是空，清不清无所谓。
      //   - 切账号 / 登出：旧 backend != null，必须清。
      if (backend != null) {
        await db.resetAllRemoteFields();
        // 重置同步游标：lastSyncedVersion 是 type=local 行，pullRecords 直接读
        // value（不看 state），必须置 0 才能让新后端走全量拉取；否则用旧后端
        // 的版本号增量会漏掉新后端上 version <= 旧游标的所有笔记。
        await db.setIntValue(KVConfigs.lastSyncedVersion, 0);
        // 只处理未删除的记录（deleted 的 base 文件在删除时已清理）。
        final uuids = await db.getUndeletedUuids();
        // base_files 是旧 backend 的同步基准，baseFileVersion 已被上面清零。
        // work 不存在 → base 提升为 work（当作本地编辑 push 到新 backend）；
        // work 已存在 → base 是过期基准，直接删掉。
        fileStore.resetAllBaseFiles(uuids);
        // 清理 asset "已上传" 标记（*.1）：这些标记属于旧 backend，不清会导致
        // 新 backend 跳过图片上传 → 其他设备拉取 404。原始图片文件保留。
        fileStore.resetAllAssetMarkers(uuids);
        // sync configs 是本地优先数据（readOnlyFolders 等），只重置同步标记，
        // 不删值，下次同步会重新上传到新 backend。缓存/DB 绑定保持不动。
        final resetConfigs = await db.resetAllSyncConfigsUnsynced();
        // 重建 recordTree：db 的 remote 字段已清零，树里缓存的 RecordEntry
        // 还是旧 backend 的，必须刷新否则 UI 显示陈旧版本号/冲突徽标。
        recordTree.rebuild(await db.getAllRecords());
        AppLogger.i(
          'Repository',
          "_onBackendChanged cleared remote state + reset base/asset markers + reset $resetConfigs sync configs + rebuilt tree",
        );
      }

      // 旧 backend 的连接池此刻已无在飞请求：SyncEngine 已停、fileStore 排空已等
      // 所有 base 下载（走 backend 独占 client）收尾。安全释放，避免连接泄漏。
      // 游客→登录时 oldBackend 为 null，跳过。
      await oldBackend?.close();

      backend = newBackend;
      // FileStore 的 backend 已在重置前经 switchBackend 排空切换，这里只换配置层引用：
      // DB 终身不变、配置值本地保留，无需 dispose/reload。游客传 null，_doSync 自动跳过；
      // 缓存持续有效，只读门禁不受登出影响。
      syncConfigs.setBackend(newBackend);

      if (newBackend != null) {
        // 建新的 SyncEngine
        syncEngine = SyncEngine(
          db: db,
          fileStore: fileStore,
          backend: newBackend,
          recordTree: recordTree,
          syncStateNotifier: syncStateNotifier,
        );
        AppLogger.i('Repository', "_onBackendChanged initial sync to ${newBackend.name}");
        await syncRecords(true);
        unawaited(syncConfigs.syncNow());
      } else {
        // 游客模式 — 不触发远端同步
        AppLogger.i('Repository', "_onBackendChanged guest mode, no sync");
      }
    } finally {
      backendSwitchingNotifier.value = false;
    }
  }

  Future<void> syncFromBackground() async {
    if (backend == null) return;
    if (syncEngine?.shouldSyncFromBackground() ?? false) {
      await syncRecords(false);
    }
  }

  Future<void> waitForSync() async => await syncEngine?.waitForSync();

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
    int time = DateTime.now().millisecondsSinceEpoch;
    final recordUuid = uuid ?? const Uuid().v4();
    await db.insertRecord(
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
    final record = (await db.getRecord(recordUuid))!;
    await recordTree.insertRecord(record);
    AppLogger.i('Repository', "create record $recordUuid ${record.local.path}${record.local.name}");
    fileStore.deleteWorkFile(recordUuid);
    if (sync && backend != null) await syncRecords(false);
    return record;
  }

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
    if (record != null && backend != null) {
      unawaited(
        syncRecords(false).catchError((e) {
          AppLogger.e('Repository', "editRecord sync failed: $e");
        }),
      );
    }
    return record;
  }

  Future<void> deleteRecord(String uuid) async {
    RecordEntry? record = await db.getRecord(uuid);
    int time = DateTime.now().millisecondsSinceEpoch;
    int count = await db.updateRecord(uuid, editType: LocalEditType.delete, editAt: time);
    if (count > 0) {
      final hasContent = (fileStore.isWorkFileExist(uuid)) || ((record?.remote.fileVersion ?? 0) > 0);
      if (hasContent) {
        await _captureToRecycler(record?.local, time);
      }
      await recordTree.deleteRecord(uuid);
      AppLogger.i(
        'Repository',
        "delete record ${record?.local.uuid} ${record?.local.path}${record?.local.name} version:${record?.local.remoteVersion}",
      );
      if (backend != null) await syncRecords(false);
    }
  }

  Future<void> _captureToRecycler(LocalRecord? record, int deleteAt, {String groupId = ''}) async {
    if (record == null) return;
    try {
      await db.insertRecycleRecord(
        uuid: record.uuid,
        path: record.path,
        name: record.name,
        reminder: record.reminder,
        tags: record.tags,
        locked: record.locked,
        deleteAt: deleteAt,
        groupId: groupId,
      );
      fileStore.moveFileToRecycler(record.uuid);
    } catch (e) {
      AppLogger.e('Repository', "capture to recycler failed uuid=${record.uuid}: $e");
    }
  }

  Future<void> purgeUnsyncedRecord(String uuid) async {
    final rows = await (db.delete(db.localRecords,
    )..where((t) => t.uuid.equals(uuid) & t.remoteVersion.equals(0))).go();
    if (rows == 0) return;
    fileStore.deleteWorkFile(uuid);
    fileStore.deleteAssetsDir(uuid);
    await recordTree.deleteRecord(uuid);
    AppLogger.w('Repository', "purge unsynced record $uuid (local creation rolled back)");
  }

  Future<void> renameFolder(String oldPath, String newPath) async {
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
    if (backend != null) await syncRecords(false);
  }

  Future<void> deleteFolder(String path) async {
    if (path.isEmpty || path == '/' || !path.endsWith('/') || !path.startsWith('/')) {
      return;
    }

    final time = DateTime.now().millisecondsSinceEpoch;
    final toCapture = await db.getUndeletedRecordsByPathPrefix(path);
    final groupId = '$path#$time';

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
      return;
    }

    for (final record in toCapture) {
      fileStore.moveFileToRecycler(record.local.uuid);
    }

    await recordTree.deleteFolder(path);
    if (backend != null) await syncRecords(false);
  }

  // =========================================================================
  // 🎯 CONFLICT — detection and resolution
  // =========================================================================

  Future<List<RecordEntry>> getConflictRecords() async {
    return db.getConflictRecords();
  }

  Future<void> resolveConflict(String uuid, bool keepLocal) async {
    final record = await db.getRecord(uuid);
    if (record == null || !record.local.syncConflict) return;

    if (keepLocal) {
      await db.updateRecord(uuid, version: record.local.remoteVersion);
      fileStore.pruneAssetMarkers(uuid, null);
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) await recordTree.insertRecord(refreshed);
      AppLogger.i(
        'Repository',
        "resolveConflict keepLocal uuid=$uuid align baseline to v${record.local.remoteVersion}",
      );
    } else {
      await db.markSynced(uuid);
      fileStore.deleteWorkFile(uuid);
      try {
        final basePath = fileStore.getBaseFile(uuid);
        final remoteAssets = RecordSections.extractAssetNamesFromPath(basePath).toSet();
        fileStore.pruneAssetsFiles(uuid, remoteAssets);
      } catch (e) {
        AppLogger.e('Repository', "resolveConflict keepRemote uuid=$uuid asset prune failed: $e");
      }
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) await recordTree.insertRecord(refreshed);
      AppLogger.w('Repository', "resolveConflict keepRemote uuid=$uuid overwritten, remoteV=${record.remote.version}");
    }

    final remaining = await db.getConflictRecords();
    if (remaining.isEmpty) {
      syncStateNotifier.value = SyncState(state: SyncState.success);
    }
    if (backend != null) await syncRecords(false);
  }

  // =========================================================================
  // 🎯 SYNC — delegate to SyncEngine
  // =========================================================================

  Future<void> syncRecords(bool forcePull) async {
    if (backend == null) return; // 游客不触发同步
    await syncEngine?.sync(forcePull);
    await syncConfigs.sync();
  }

  // =========================================================================
  // 🎯 RECYCLE BIN
  // =========================================================================

  Future<List<RecycleRecord>> getRecycleRecords() async => await db.getRecycleRecords();

  Future<List<({String folderPath, int deleteAt, int count, String groupId})>> getRecycleFolderGroups() async =>
      await db.getRecycleFolderGroups();

  Future<List<RecycleRecord>> getRecycleSingleRecords() async => await db.getRecycleSingleRecords();

  Future<bool> restoreRecycleRecord(String uuid) async {
    final entry = await db.getRecycleRecord(uuid);
    if (entry == null) return false;
    final ok = await _restoreRecycleRecords([
      entry,
    ], operateLabel: "restore record ${entry.uuid} ${entry.path}${entry.name}");
    if (ok && backend != null) unawaited(syncRecords(false));
    return ok;
  }

  Future<bool> restoreRecycleGroup(String groupId) async {
    final groupEntries = await db.getRecycleRecordsByGroup(groupId);
    if (groupEntries.isEmpty) return false;
    final folderPath = groupId.split('#').first;
    final ok = await _restoreRecycleRecords(
      groupEntries,
      operateLabel: "restore folder group $folderPath, count:${groupEntries.length}",
    );
    if (ok && backend != null) unawaited(syncRecords(false));
    return ok;
  }

  Future<bool> _restoreRecycleRecords(List<RecycleRecord> entries, {required String operateLabel}) async {
    final time = DateTime.now().millisecondsSinceEpoch;
    final okEntries = <RecycleRecord>[];
    for (final entry in entries) {
      final existing = await db.getRecord(entry.uuid);
      if (existing != null && existing.local.editType != LocalEditType.delete) continue;
      fileStore.moveRecyclerFileToWork(entry.uuid);
      okEntries.add(entry);
    }
    if (okEntries.isEmpty) return false;

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
      for (final entry in okEntries) {
        fileStore.moveWorkFileToRecycler(entry.uuid);
      }
      rethrow;
    }

    for (final entry in okEntries) {
      final record = await db.getRecord(entry.uuid);
      if (record != null) await recordTree.insertRecord(record);
    }
    return true;
  }

  Future<void> purgeRecycleRecord(String uuid) async {
    await db.deleteRecycleRecord(uuid);
    fileStore.deleteRecyclerFile(uuid);
    fileStore.deleteAssetsDir(uuid);
    AppLogger.w('Repository', "purge recycler record $uuid");
  }

  Future<void> purgeRecycleGroup(String groupId) async {
    final groupEntries = await db.getRecycleRecordsByGroup(groupId);
    await db.deleteRecycleRecordsByGroup(groupId);
    for (final e in groupEntries) {
      fileStore.deleteRecyclerFile(e.uuid);
      fileStore.deleteAssetsDir(e.uuid);
    }
    AppLogger.w('Repository', "purge folder recycler group $groupId, count:${groupEntries.length}");
  }

  Future<void> clearRecycleRecords() async {
    final rows = await db.getRecycleRecords();
    await db.clearRecycleRecords();
    for (final row in rows) {
      fileStore.deleteRecyclerFile(row.uuid);
      fileStore.deleteAssetsDir(row.uuid);
    }
    AppLogger.w('Repository', "clear recycler records, count:${rows.length}");
  }
}
