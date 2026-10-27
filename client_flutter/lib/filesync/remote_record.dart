import 'dart:convert';

import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/record_ext.dart';

import 'table_record.dart';

class RemoteRecord {
  final String uuid;
  String path;
  String name;
  final int version;
  final int createAt;
  final int editAt;
  final int fileEditAt;
  final int fileVersion;
  final int deleteAt;
  final String md5;
  final int locked;
  final String reminder;
  final String tags;

  RemoteRecord({
    required this.uuid,
    required this.path,
    required this.name,
    required this.version,
    required this.createAt,
    required this.editAt,
    required this.fileEditAt,
    required this.fileVersion,
    required this.locked,
    required this.deleteAt,
    required this.md5,
    this.reminder = '',
    this.tags = '',
  });

  /// RemoteRecord → LocalRecord: copy all remote_*, local_* = remote_* (synced baseline).
  /// [baseFileVersion]: which file version the local base file corresponds to, default 0 (new record).
  LocalRecord toLocalRecord(int batchNo, {int baseFileVersion = 0}) {
    final formattedPath = RecordPath.normalizePath(path);

    // remoteJson stores the full server snapshot; path is formatted for consistency.
    final remoteJson = jsonEncode({...toJson(), 'path': formattedPath});

    return LocalRecord(
      uuid: uuid,
      batchNo: batchNo,
      // Indexed columns (redundant with remoteJson, kept for SQL WHERE)
      remoteVersion: version,
      remoteMd5: md5,
      remoteFileVersion: fileVersion,
      remoteJson: remoteJson,
      baseFileVersion: baseFileVersion,
      // Local = remote (synced)
      editType: LocalEditType.none,
      version: version,
      fileVersion: fileVersion,
      editAt: editAt,
      fileEditAt: fileEditAt,
      fileDirty: 0,
      createAt: createAt,
      name: name,
      md5: md5,
      path: formattedPath,
      locked: locked,
      reminder: reminder,
      tags: tags,
    );
  }

  factory RemoteRecord.fromJson(Map<String, dynamic> json) => RemoteRecord(
    uuid: json['uuid'] as String? ?? '',
    path: json['path'] as String? ?? '',
    name: json['name'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? 0,
    createAt: (json['createAt'] as num?)?.toInt() ?? 0,
    editAt: (json['editAt'] as num?)?.toInt() ?? 0,
    fileEditAt: (json['fileEditAt'] as num?)?.toInt() ?? 0,
    fileVersion: (json['fileVersion'] as num?)?.toInt() ?? 0,
    locked: (json['locked'] as num?)?.toInt() ?? 0,
    deleteAt: (json['deleteAt'] as num?)?.toInt() ?? 0,
    md5: json['md5'] as String? ?? '',
    reminder: _normalizeReminder(json['reminder'] as String?),
    tags: json['tags'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'uuid': uuid,
    'path': path,
    'name': name,
    'version': version,
    'createAt': createAt,
    'editAt': editAt,
    'fileEditAt': fileEditAt,
    'fileVersion': fileVersion,
    'deleteAt': deleteAt,
    'md5': md5,
    'locked': locked,
    'reminder': _normalizeReminder(reminder),
    'tags': tags,
  };

  /// Normalize reminder: empty JSON array ("[]") or "null" becomes "".
  static String _normalizeReminder(String? value) {
    final v = (value ?? '').trim();
    if (v == '[]' || v == 'null') return '';
    return value ?? '';
  }

  @override
  bool operator ==(Object other) => other is RemoteRecord && uuid == other.uuid;

  @override
  int get hashCode => Object.hash(uuid, "RemoteRecord");
}
