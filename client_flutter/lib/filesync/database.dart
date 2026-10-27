import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/filesync/remote_record.dart';

import 'record_ext.dart';
import 'table_record.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LocalRecords, KVConfigs, RecycleRecords], views: [PathRecordCounts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // ========== Queries ==========

  Future<List<RecordEntry>> getAllRecords() async =>
      (await select(localRecords).get()).map((r) => RecordEntry(r)).toList();

  /// PUSH: retrieve all locally edited entries (edit=1, non-delete)
  Future<List<RecordEntry>> getEditRecords() async => (await (select(
    localRecords,
  )..where((t) => t.editType.equals(LocalEditType.edit))).get()).map((r) => RecordEntry(r)).toList();

  /// PUSH: locally edited entries with NO file content change (fileDirty == 0).
  /// These can be batched via upsertRecords (metadata-only, no file upload).
  Future<List<RecordEntry>> getEditRecordsWithoutFileEdit() async =>
      (await (select(localRecords)
                ..where((t) => t.editType.equals(LocalEditType.edit))
                ..where((t) => t.fileDirty.equals(0)))
              .get())
          .map((r) => RecordEntry(r))
          .toList();

  /// PUSH: locally edited entries WITH file content change (fileDirty == 1).
  /// These must be pushed individually via upsertRecord (file upload required).
  Future<List<RecordEntry>> getEditRecordsWithFileEdit() async =>
      (await (select(localRecords)
                ..where((t) => t.editType.equals(LocalEditType.edit))
                ..where((t) => t.fileDirty.equals(1)))
              .get())
          .map((r) => RecordEntry(r))
          .toList();

  Future<RecordEntry?> getRecord(String uuid) async {
    final r = await (select(localRecords)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    return r == null ? null : RecordEntry(r);
  }

  /// Fetch multiple records by their uuids.
  Future<List<RecordEntry>> getRecordsByUuids(List<String> uuids) async =>
      (await (select(localRecords)..where((t) => t.uuid.isIn(uuids))).get()).map((r) => RecordEntry(r)).toList();

  /// PUSH: retrieve all locally deleted entries
  Future<List<RecordEntry>> getDeleteRecords() async => (await (select(
    localRecords,
  )..where((t) => t.editType.equals(LocalEditType.delete))).get()).map((r) => RecordEntry(r)).toList();

  /// All conflicted entries: local has edit (non-delete) && version != remoteVersion
  /// Local deletion is not considered a conflict (deletion is an independent push flow)
  Future<List<RecordEntry>> getConflictRecords() async =>
      (await (select(localRecords)
                ..where((t) => t.editType.equals(LocalEditType.edit))
                ..where((t) => t.version.equalsExp(t.remoteVersion).not()))
              .get())
          .map((r) => RecordEntry(r))
          .toList();

  /// Records under a path prefix that are not delete-marked (used for folder deletion capture).
  Future<List<RecordEntry>> getUndeletedRecordsByPathPrefix(String pathPrefix) async =>
      (await (select(localRecords)
                ..where((t) => t.path.like('$pathPrefix%'))
                ..where((t) => t.editType.equals(LocalEditType.delete).not()))
              .get())
          .map((r) => RecordEntry(r))
          .toList();

  // ========== Recycle bin ==========

  /// All recycle bin entries, newest deletion first.
  Future<List<RecycleRecord>> getRecycleRecords() async => await (select(
    recycleRecords,
  )..orderBy([(t) => OrderingTerm(expression: t.deleteAt, mode: OrderingMode.desc)])).get();

  /// Folder groups from recycle bin — one row per non-empty groupId with
  /// folderPath, deleteAt (latest in group), count, and the raw groupId.
  Future<List<({String folderPath, int deleteAt, int count, String groupId})>> getRecycleFolderGroups() async {
    final count = recycleRecords.uuid.count();
    final maxAt = recycleRecords.deleteAt.max();
    final rows =
        await (selectOnly(recycleRecords)
              ..addColumns([recycleRecords.groupId, count, maxAt])
              ..where(recycleRecords.groupId.isNotValue(''))
              ..groupBy([recycleRecords.groupId]))
            .get();
    return rows.map((row) {
      final gid = row.read(recycleRecords.groupId)!;
      return (
        folderPath: gid.split('#').first,
        deleteAt: row.read(maxAt) ?? 0,
        count: row.read(count) ?? 0,
        groupId: gid,
      );
    }).toList()..sort((a, b) => b.deleteAt.compareTo(a.deleteAt));
  }

  /// Single recycle records (groupId empty), newest first.
  Future<List<RecycleRecord>> getRecycleSingleRecords() async {
    return await (select(recycleRecords)
          ..where((t) => t.groupId.equals(''))
          ..orderBy([(t) => OrderingTerm(expression: t.deleteAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<RecycleRecord?> getRecycleRecord(String uuid) async =>
      await (select(
    recycleRecords,
  )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  /// Re-emits the recycle bin row count whenever the table changes (initial
  /// value emitted on listen). Avoids polling after every sync.
  Stream<int> watchRecycleCount() {
    final count = recycleRecords.uuid.count();
    final query = selectOnly(recycleRecords)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<int> insertRecycleRecord({
    required String uuid,
    required String path,
    required String name,
    required String reminder,
    required String tags,
    required int locked,
    required int deleteAt,
    String groupId = '',
  }) async {
    return await into(recycleRecords).insertOnConflictUpdate(
      RecycleRecordsCompanion.insert(
        uuid: uuid,
        path: Value(path),
        name: Value(name),
        reminder: Value(reminder),
        tags: Value(tags),
        locked: Value(locked),
        deleteAt: deleteAt,
        groupId: Value(groupId),
      ),
    );
  }

  Future<int> deleteRecycleRecord(String uuid) async =>
      await (delete(recycleRecords)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteRecycleRecordsByGroup(String groupId) async =>
      await (delete(recycleRecords)..where((t) => t.groupId.equals(groupId))).go();

  Future<List<RecycleRecord>> getRecycleRecordsByGroup(String groupId) async =>
      await (select(recycleRecords)..where((t) => t.groupId.equals(groupId))).get();

  Future<int> clearRecycleRecords() async => await delete(recycleRecords).go();

  /// Delete recycle-bin rows whose deleteAt timestamp is older than [thresholdMs] (epoch ms).
  Future<List<RecycleRecord>> purgeRecycleRecordsBefore(int thresholdMs) async {
    final rows = await (select(recycleRecords)..where((t) => t.deleteAt.isSmallerOrEqualValue(thresholdMs))).get();
    if (rows.isNotEmpty) {
      await (delete(recycleRecords)..where((t) => t.deleteAt.isSmallerOrEqualValue(thresholdMs))).go();
    }
    return rows;
  }

  // ========== KV ==========

  Future<int> getConfigInt(String key, int def) async {
    var str = await getConfigStr(key, null);
    return str != null && str.isNotEmpty ? int.parse(str) : def;
  }

  Future<String?> getConfigStr(String key, String? def) async {
    var config = await (select(kVConfigs)..where((t) => t.key.equals(key))).getSingleOrNull();
    return config != null ? config.value : def;
  }

  Future<int> setIntValue(String key, int value) async => await setStringValue(key, value.toString());

  Future<int> setStringValue(String key, String value) async =>
      await into(kVConfigs).insertOnConflictUpdate(KVConfig(key: key, value: value));

  // ========== Writes ==========

  Future<int> deleteRecord(String uuid) async => await (delete(localRecords)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteRecordsByUuids(List<String> uuids) async =>
      await (delete(localRecords)..where((t) => t.uuid.isIn(uuids))).go();

  Future<int> replaceRecord(LocalRecord localRecord) async =>
      await into(localRecords).insertOnConflictUpdate(localRecord);

  /// Create a new local record (remote_* all zeroes, uses DB default values).
  Future<int> insertRecord({
    required String uuid,
    required String name,
    required String path,
    required int editAt,
    required int fileEditAt,
    required int createAt,
    int fileDirty = 0,
    String? reminder,
    String? tags,
  }) async {
    return await into(localRecords).insert(
      LocalRecordsCompanion.insert(
        uuid: uuid,
        editType: const Value(LocalEditType.edit),
        editAt: Value(editAt),
        fileEditAt: Value(fileEditAt),
        fileDirty: Value(fileDirty),
        createAt: Value(createAt),
        name: Value(name),
        path: Value(path),
        reminder: Value(reminder ?? ''),
        tags: Value(tags ?? ''),
      ),
    );
  }

  /// Re-create a local record from the recycle bin, or update the local-edit
  /// fields if a row with the same uuid already exists (e.g. still marked delete).
  /// Uses insertOnConflictUpdate — remote/batch fields are untouched on conflict.
  Future<int> restoreRecord({
    required String uuid,
    required String name,
    required String path,
    required int locked,
    required String reminder,
    required int editAt,
    required int fileEditAt,
    required int createAt,
    required String tags,
    int fileDirty = 0,
    int baseFileVersion = 0,
  }) async {
    return await into(localRecords).insertOnConflictUpdate(
      LocalRecordsCompanion.insert(
        uuid: uuid,
        editType: const Value(LocalEditType.edit),
        editAt: Value(editAt),
        fileEditAt: Value(fileEditAt),
        fileDirty: Value(fileDirty),
        createAt: Value(createAt),
        name: Value(name),
        locked: Value(locked),
        reminder: Value(reminder),
        tags: Value(tags),
        path: Value(path),
        baseFileVersion: Value(baseFileVersion),
      ),
    );
  }

  /// Unified LocalRecord update. All fields optional, null means do not update.
  ///
  /// remote fields: 3 indexed columns (remoteVersion/remoteMd5/remoteFileVersion) + remoteJson blob.
  /// Called after successful sync: overwrites remote fields to local fields, version=remoteVersion, editType=none.
  Future<int> updateRecord(
    String uuid, {
    int? batchNo,
    // remote: 3 columns + json blob
    int? remoteVersion,
    String? remoteMd5,
    int? remoteFileVersion,
    String? remoteJson,
    // base file tracking
    int? baseFileVersion,
    // local
    int? editType,
    int? version,
    int? fileVersion,
    int? editAt,
    int? fileEditAt,
    int? fileDirty,
    int? createAt,
    String? name,
    String? md5,
    String? path,
    int? locked,
    String? reminder,
    String? tags,
  }) async {
    return await (update(localRecords)..where((t) => t.uuid.equals(uuid))).write(
      LocalRecordsCompanion(
        batchNo: batchNo != null ? Value(batchNo) : Value.absent(),
        remoteVersion: remoteVersion != null ? Value(remoteVersion) : Value.absent(),
        remoteMd5: remoteMd5 != null ? Value(remoteMd5) : Value.absent(),
        remoteFileVersion: remoteFileVersion != null ? Value(remoteFileVersion) : Value.absent(),
        remoteJson: remoteJson != null ? Value(remoteJson) : Value.absent(),
        baseFileVersion: baseFileVersion != null ? Value(baseFileVersion) : Value.absent(),
        editType: editType != null ? Value(editType) : Value.absent(),
        version: version != null ? Value(version) : Value.absent(),
        fileVersion: fileVersion != null ? Value(fileVersion) : Value.absent(),
        editAt: editAt != null ? Value(editAt) : Value.absent(),
        fileEditAt: fileEditAt != null ? Value(fileEditAt) : Value.absent(),
        fileDirty: fileDirty != null ? Value(fileDirty) : Value.absent(),
        createAt: createAt != null ? Value(createAt) : Value.absent(),
        name: name != null ? Value(name) : Value.absent(),
        md5: md5 != null ? Value(md5) : Value.absent(),
        path: path != null ? Value(path) : Value.absent(),
        locked: locked != null ? Value(locked) : Value.absent(),
        reminder: reminder != null ? Value(reminder) : Value.absent(),
        tags: tags != null ? Value(tags) : Value.absent(),
      ),
    );
  }

  /// Update DB remote_* fields from server-side RemoteRecord (do not touch local_*).
  /// Optional batchNo: mark this pull cycle, used for full cleanup.
  /// Optional version: needed to align baseline version during concurrent push edits.
  Future<int> updateRecordRemote(String uuid, RemoteRecord remote, {int? batchNo, int? version}) async {
    final formattedPath = RecordPath.normalizePath(remote.path);
    final remoteJson = jsonEncode({...remote.toJson(), 'path': formattedPath});
    return await updateRecord(
      uuid,
      batchNo: batchNo,
      remoteVersion: remote.version,
      remoteMd5: remote.md5,
      remoteFileVersion: remote.fileVersion,
      remoteJson: remoteJson,
      version: version,
    );
  }

  /// Clear remote_* fields (server deleted, local has edits = needs to be re-created).
  /// Also resets version/fileVersion to zero so push treats it as a new record via upsertRecord.
  /// Optional batchNo: mark this pull cycle, used for full cleanup.
  Future<int> clearRecordRemote(String uuid, {int? batchNo}) async {
    return await updateRecord(
      uuid,
      batchNo: batchNo,
      remoteVersion: 0,
      remoteMd5: '',
      remoteFileVersion: 0,
      remoteJson: '',
      version: 0,
      fileVersion: 0,
      baseFileVersion: 0,
    );
  }

  /// One-click alignment after successful sync: local_* all = remote_*, editType=none.
  /// editAt/fileEditAt are also set to remote values (not cleared),
  /// so the UI layer can directly read local fields as correct values, no need to fall back to remote.
  /// Optional batchNo: mark this pull cycle, used for full cleanup.
  Future<int> markSynced(String uuid, {int? batchNo}) async {
    final e = await getRecord(uuid);
    if (e == null) return 0;
    // Only update local fields, aligning them to remote; remote / baseFileVersion remain unchanged.
    return await updateRecord(
      uuid,
      batchNo: batchNo,
      editType: LocalEditType.none,
      version: e.remote.version,
      fileVersion: e.remote.fileVersion,
      editAt: e.remote.editAt,
      fileEditAt: e.remote.fileEditAt,
      fileDirty: 0,
      createAt: e.remote.createAt,
      name: e.remote.name,
      md5: e.remote.md5,
      path: e.remote.path,
      locked: e.remote.locked,
      reminder: e.remote.reminder,
      tags: e.remote.tags,
    );
  }
}

// ========== Physical connector ==========

AppDatabase createRecordsDatabase(File file) {
  AppLogger.i('Database', "createRecordsDatabase: $file");
  final executor = NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      rawDb.execute('PRAGMA journal_mode=WAL;');
      rawDb.execute('PRAGMA synchronous=NORMAL;');
      rawDb.execute('PRAGMA busy_timeout = 5000;');
    },
  );
  return AppDatabase(executor);
}
