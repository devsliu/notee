import 'package:drift/drift.dart';

/// Local edit type.
/// none(0) = synced, no pending upload changes
/// edit(1) = has local edits (metadata and/or file content)
/// delete(2) = local deletion
///
/// Detection:
///   Has edits           → editType > none
///   Local file changed  → fileDirty == 1
///   Conflict            → editType > none && version != remoteVersion
///   Local deletion     → editType == delete
class LocalEditType {
  static const int none = 0;
  static const int edit = 1;
  static const int delete = 2;
}

@TableIndex(name: 'records_path_idx', columns: {#path})
@TableIndex(name: 'records_version_idx', columns: {#remoteVersion})
@DataClassName('LocalRecord')
class LocalRecords extends Table {
  // ========== Identity ==========
  TextColumn get uuid => text()();

  // ========== Pull tracking ==========
  IntColumn get batchNo => integer().withDefault(const Constant(0))();

  // ========== Server authoritative (downloaded from server) ==========
  /// Conflict detection + sort, participates in SQL WHERE/ORDER BY
  IntColumn get remoteVersion => integer().withDefault(const Constant(0))();

  /// Full server snapshot as JSON (all RemoteRecord fields).
  /// The column above is a redundant indexed copy kept only for SQL WHERE/ORDER BY.
  /// Decoded lazily into RemoteRecord via RecordEntry.remote.
  TextColumn get remoteJson => text().withDefault(const Constant(''))();

  // ========== Base file tracking ==========
  /// The server-side fileVersion of the locally downloaded base file.
  /// Written only after downloadBaseFile succeeds, never cleared.
  /// Whether to re-download: remote.fileVersion > baseFileVersion (or file does not exist).
  IntColumn get baseFileVersion => integer().withDefault(const Constant(0))();

  // ========== Local working state ==========
  /// Local edit type: 0=synced, 1=edited, 2=deleted
  IntColumn get editType => integer().withDefault(const Constant(0))();

  /// Local globally-modified version number. Conflict detection: editType>0 && version != remoteVersion
  IntColumn get version => integer().withDefault(const Constant(0))();

  /// Local file edit based on the remote fileVersion. File conflict detection: localFileEdited==1 && fileVersion != remote.fileVersion
  IntColumn get fileVersion => integer().withDefault(const Constant(0))();

  /// Local edit timestamp. After sync, aligned to remote.editAt.
  /// Local edit detection: editType != none (not editAt > 0).
  IntColumn get editAt => integer().withDefault(const Constant(0))();

  /// Local file edit timestamp. After sync, aligned to remote.fileEditAt.
  IntColumn get fileEditAt => integer().withDefault(const Constant(0))();

  /// Explicit flag: 1 = local file content modified since last sync (needs upload),
  /// 0 = local file matches server (or no file). Set on file edit, cleared on sync.
  IntColumn get fileDirty => integer().withDefault(const Constant(0))();

  /// Local creation timestamp. Set on local create, synced from server on pull.
  /// Never modified after creation.
  IntColumn get createAt => integer().withDefault(const Constant(0))();

  /// Field values after local edits. Overwritten with remote_* after successful sync (restored to server values)
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get md5 => text().withDefault(const Constant(''))();
  IntColumn get locked => integer().withDefault(const Constant(0))();
  TextColumn get reminder => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// Local path: COLLATE BINARY ensures LIKE index works, CHECK constraint guarantees format
  TextColumn get path =>
      text().withDefault(const Constant('/')).customConstraint("NOT NULL COLLATE BINARY CHECK (path LIKE '%/')")();

  @override
  Set<Column> get primaryKey => {uuid};
}

// Path dashboard view
@DriftView(name: 'PathRecordCounts')
abstract class PathRecordCounts extends View {
  LocalRecords get records;
  Expression<int> get recordCount => records.uuid.count();

  @override
  Query as() => select([records.path, recordCount]).from(records)..groupBy([records.path]);
}

/// Recycle bin entry: metadata snapshot of a locally deleted record.
/// The content file is kept in the recycler/ folder named by uuid.
/// Restore re-creates the record as a pure local edit (remote_* zeroed, uuid unchanged),
/// which is pushed to the server as a new record on next sync.
///
/// groupId groups entries deleted together:
///   '' (empty) = single record delete
///   '/Folder/' = folder delete — UI collapses all entries with same groupId
///                under one "folder" card; restore/purge the card does all at once
@DataClassName('RecycleRecord')
class RecycleRecords extends Table {
  TextColumn get uuid => text()();

  // Snapshot of the deleted record's local_* fields
  TextColumn get path => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get reminder => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  IntColumn get locked => integer().withDefault(const Constant(0))();

  /// Deletion timestamp (ms)
  IntColumn get deleteAt => integer()();

  /// Folder-delete group: '' = single delete, '/Folder/' = part of a folder delete
  TextColumn get groupId => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('KVConfig')
class KVConfigs extends Table {
  // Last synced maximum version number (inclusive)
  static const String lastSyncedVersion = 'last_synced_version';
  // Recent content-search queries, JSON array of strings, newest first
  static const String searchHistory = 'search_history';
  // Last time configs were synced with server (ms since epoch)
  static const String lastConfigSyncTime = 'last_config_sync_time';
  // Read-only folder list, JSON array of folder paths (each ends with /)
  static const String readOnlyFolders = 'read_only_folders';

  // type values
  static const String typeLocal = 'local';
  static const String typeSync = 'sync';
  // state values (only meaningful for type=sync)
  static const int stateSynced = 1;
  static const int stateUnsynced = 0;

  TextColumn get key => text()();
  TextColumn get value => text()();
  // 'local' = store only on this device; 'sync' = sync with server
  TextColumn get type => text().withDefault(const Constant(KVConfigs.typeLocal))();
  // 0 = locally edited & unsynced; 1 = synced. Unused for type=local.
  IntColumn get state => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}
