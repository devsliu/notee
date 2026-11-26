import 'package:notee/filesync/remote_record.dart';

/// Backend-agnostic types shared by SyncBackend and all its implementations.
/// These were previously defined in http_api.dart but are needed by the
/// abstract interface — moving them here breaks the http_api dependency
/// and lets SyncBackend / sync_engine.dart / etc. work with any backend.

/// Generic API response envelope (code + message + data).
class ApiResult<T> {
  final int code;
  final String message;
  final T? data;
  final String? rawData; // Raw HTTP response body string; null for client-side errors

  const ApiResult(this.code, this.message, this.data, {this.rawData});

  bool isSuccess() {
    return code == 200;
  }

  static ApiResult<T> success<T>(T data, {String? rawData}) {
    return ApiResult(200, "OK", data, rawData: rawData);
  }
}

/// Result of a record-list fetch (incremental or full).
class FetchEntitesResult {
  final List<RemoteRecord> records;
  /// The maximum purged value (inclusive). Your local version must be
  /// >= purgedVersion, otherwise some of your history has been physically
  /// deleted on the server and you need a full pull.
  final int purgedVersion;

  FetchEntitesResult(this.records, this.purgedVersion);
}

/// Record metadata carried in a download-file response, used to verify
/// file integrity and version.
class DownloadFileMeta {
  final int fileVersion;
  final String md5;
  DownloadFileMeta(this.fileVersion, this.md5);
}

/// Per-uuid result of a batch record operation (delete or upsert).
/// [data] carries the current server record on success or conflict (531).
class RecordResult {
  final String uuid;
  final int code;
  final RemoteRecord? data;

  const RecordResult(this.uuid, this.code, this.data);

  bool isSuccess() => code == 200;
}

/// A single record upsert item (no content file). Null / 0 / empty fields
/// mean "not provided" — the backend leaves those fields untouched.
class UpsertRecordItem {
  final String uuid;
  final int editAt;
  final int version;
  final String? path;
  final String? name;
  final int? createAt;
  final int? fileEditAt;
  final int? locked;
  final String? reminder;
  final String? tags;

  const UpsertRecordItem({
    required this.uuid,
    required this.editAt,
    required this.version,
    this.path,
    this.name,
    this.createAt,
    this.fileEditAt,
    this.locked,
    this.reminder,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'uuid': uuid, 'editAt': editAt, 'version': version};
    if (path != null) map['path'] = path;
    if (name != null) map['name'] = name;
    if (createAt != null) map['createAt'] = createAt;
    if (fileEditAt != null) map['fileEditAt'] = fileEditAt;
    if (locked != null) map['locked'] = locked;
    if (reminder != null) map['reminder'] = reminder;
    if (tags != null) map['tags'] = tags;
    return map;
  }
}
