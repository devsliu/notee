// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalRecordsTable extends LocalRecords
    with TableInfo<$LocalRecordsTable, LocalRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchNoMeta = const VerificationMeta(
    'batchNo',
  );
  @override
  late final GeneratedColumn<int> batchNo = GeneratedColumn<int>(
    'batch_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteJsonMeta = const VerificationMeta(
    'remoteJson',
  );
  @override
  late final GeneratedColumn<String> remoteJson = GeneratedColumn<String>(
    'remote_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _baseFileVersionMeta = const VerificationMeta(
    'baseFileVersion',
  );
  @override
  late final GeneratedColumn<int> baseFileVersion = GeneratedColumn<int>(
    'base_file_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _editTypeMeta = const VerificationMeta(
    'editType',
  );
  @override
  late final GeneratedColumn<int> editType = GeneratedColumn<int>(
    'edit_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileVersionMeta = const VerificationMeta(
    'fileVersion',
  );
  @override
  late final GeneratedColumn<int> fileVersion = GeneratedColumn<int>(
    'file_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _editAtMeta = const VerificationMeta('editAt');
  @override
  late final GeneratedColumn<int> editAt = GeneratedColumn<int>(
    'edit_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileEditAtMeta = const VerificationMeta(
    'fileEditAt',
  );
  @override
  late final GeneratedColumn<int> fileEditAt = GeneratedColumn<int>(
    'file_edit_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileDirtyMeta = const VerificationMeta(
    'fileDirty',
  );
  @override
  late final GeneratedColumn<int> fileDirty = GeneratedColumn<int>(
    'file_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createAtMeta = const VerificationMeta(
    'createAt',
  );
  @override
  late final GeneratedColumn<int> createAt = GeneratedColumn<int>(
    'create_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _md5Meta = const VerificationMeta('md5');
  @override
  late final GeneratedColumn<String> md5 = GeneratedColumn<String>(
    'md5',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<int> locked = GeneratedColumn<int>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reminderMeta = const VerificationMeta(
    'reminder',
  );
  @override
  late final GeneratedColumn<String> reminder = GeneratedColumn<String>(
    'reminder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL COLLATE BINARY CHECK (path LIKE \'%/\')',
    defaultValue: const Constant('/'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    batchNo,
    remoteVersion,
    remoteJson,
    baseFileVersion,
    editType,
    version,
    fileVersion,
    editAt,
    fileEditAt,
    fileDirty,
    createAt,
    name,
    md5,
    locked,
    reminder,
    tags,
    path,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('batch_no')) {
      context.handle(
        _batchNoMeta,
        batchNo.isAcceptableOrUnknown(data['batch_no']!, _batchNoMeta),
      );
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('remote_json')) {
      context.handle(
        _remoteJsonMeta,
        remoteJson.isAcceptableOrUnknown(data['remote_json']!, _remoteJsonMeta),
      );
    }
    if (data.containsKey('base_file_version')) {
      context.handle(
        _baseFileVersionMeta,
        baseFileVersion.isAcceptableOrUnknown(
          data['base_file_version']!,
          _baseFileVersionMeta,
        ),
      );
    }
    if (data.containsKey('edit_type')) {
      context.handle(
        _editTypeMeta,
        editType.isAcceptableOrUnknown(data['edit_type']!, _editTypeMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('file_version')) {
      context.handle(
        _fileVersionMeta,
        fileVersion.isAcceptableOrUnknown(
          data['file_version']!,
          _fileVersionMeta,
        ),
      );
    }
    if (data.containsKey('edit_at')) {
      context.handle(
        _editAtMeta,
        editAt.isAcceptableOrUnknown(data['edit_at']!, _editAtMeta),
      );
    }
    if (data.containsKey('file_edit_at')) {
      context.handle(
        _fileEditAtMeta,
        fileEditAt.isAcceptableOrUnknown(
          data['file_edit_at']!,
          _fileEditAtMeta,
        ),
      );
    }
    if (data.containsKey('file_dirty')) {
      context.handle(
        _fileDirtyMeta,
        fileDirty.isAcceptableOrUnknown(data['file_dirty']!, _fileDirtyMeta),
      );
    }
    if (data.containsKey('create_at')) {
      context.handle(
        _createAtMeta,
        createAt.isAcceptableOrUnknown(data['create_at']!, _createAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('md5')) {
      context.handle(
        _md5Meta,
        md5.isAcceptableOrUnknown(data['md5']!, _md5Meta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('reminder')) {
      context.handle(
        _reminderMeta,
        reminder.isAcceptableOrUnknown(data['reminder']!, _reminderMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  LocalRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRecord(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      batchNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_no'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      remoteJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_json'],
      )!,
      baseFileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_file_version'],
      )!,
      editType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edit_type'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      fileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_version'],
      )!,
      editAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edit_at'],
      )!,
      fileEditAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_edit_at'],
      )!,
      fileDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_dirty'],
      )!,
      createAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}create_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      md5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}md5'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}locked'],
      )!,
      reminder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
    );
  }

  @override
  $LocalRecordsTable createAlias(String alias) {
    return $LocalRecordsTable(attachedDatabase, alias);
  }
}

class LocalRecord extends DataClass implements Insertable<LocalRecord> {
  final String uuid;
  final int batchNo;

  /// Conflict detection + sort, participates in SQL WHERE/ORDER BY
  final int remoteVersion;

  /// Full server snapshot as JSON (all RemoteRecord fields).
  /// The column above is a redundant indexed copy kept only for SQL WHERE/ORDER BY.
  /// Decoded lazily into RemoteRecord via RecordEntry.remote.
  final String remoteJson;

  /// The server-side fileVersion of the locally downloaded base file.
  /// Written only after downloadBaseFile succeeds, never cleared.
  /// Whether to re-download: remote.fileVersion > baseFileVersion (or file does not exist).
  final int baseFileVersion;

  /// Local edit type: 0=synced, 1=edited, 2=deleted
  final int editType;

  /// Local globally-modified version number. Conflict detection: editType>0 && version != remoteVersion
  final int version;

  /// Local file edit based on the remote fileVersion. File conflict detection: localFileEdited==1 && fileVersion != remote.fileVersion
  final int fileVersion;

  /// Local edit timestamp. After sync, aligned to remote.editAt.
  /// Local edit detection: editType != none (not editAt > 0).
  final int editAt;

  /// Local file edit timestamp. After sync, aligned to remote.fileEditAt.
  final int fileEditAt;

  /// Explicit flag: 1 = local file content modified since last sync (needs upload),
  /// 0 = local file matches server (or no file). Set on file edit, cleared on sync.
  final int fileDirty;

  /// Local creation timestamp. Set on local create, synced from server on pull.
  /// Never modified after creation.
  final int createAt;

  /// Field values after local edits. Overwritten with remote_* after successful sync (restored to server values)
  final String name;
  final String md5;
  final int locked;
  final String reminder;
  final String tags;

  /// Local path: COLLATE BINARY ensures LIKE index works, CHECK constraint guarantees format
  final String path;
  const LocalRecord({
    required this.uuid,
    required this.batchNo,
    required this.remoteVersion,
    required this.remoteJson,
    required this.baseFileVersion,
    required this.editType,
    required this.version,
    required this.fileVersion,
    required this.editAt,
    required this.fileEditAt,
    required this.fileDirty,
    required this.createAt,
    required this.name,
    required this.md5,
    required this.locked,
    required this.reminder,
    required this.tags,
    required this.path,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['batch_no'] = Variable<int>(batchNo);
    map['remote_version'] = Variable<int>(remoteVersion);
    map['remote_json'] = Variable<String>(remoteJson);
    map['base_file_version'] = Variable<int>(baseFileVersion);
    map['edit_type'] = Variable<int>(editType);
    map['version'] = Variable<int>(version);
    map['file_version'] = Variable<int>(fileVersion);
    map['edit_at'] = Variable<int>(editAt);
    map['file_edit_at'] = Variable<int>(fileEditAt);
    map['file_dirty'] = Variable<int>(fileDirty);
    map['create_at'] = Variable<int>(createAt);
    map['name'] = Variable<String>(name);
    map['md5'] = Variable<String>(md5);
    map['locked'] = Variable<int>(locked);
    map['reminder'] = Variable<String>(reminder);
    map['tags'] = Variable<String>(tags);
    map['path'] = Variable<String>(path);
    return map;
  }

  LocalRecordsCompanion toCompanion(bool nullToAbsent) {
    return LocalRecordsCompanion(
      uuid: Value(uuid),
      batchNo: Value(batchNo),
      remoteVersion: Value(remoteVersion),
      remoteJson: Value(remoteJson),
      baseFileVersion: Value(baseFileVersion),
      editType: Value(editType),
      version: Value(version),
      fileVersion: Value(fileVersion),
      editAt: Value(editAt),
      fileEditAt: Value(fileEditAt),
      fileDirty: Value(fileDirty),
      createAt: Value(createAt),
      name: Value(name),
      md5: Value(md5),
      locked: Value(locked),
      reminder: Value(reminder),
      tags: Value(tags),
      path: Value(path),
    );
  }

  factory LocalRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRecord(
      uuid: serializer.fromJson<String>(json['uuid']),
      batchNo: serializer.fromJson<int>(json['batchNo']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      remoteJson: serializer.fromJson<String>(json['remoteJson']),
      baseFileVersion: serializer.fromJson<int>(json['baseFileVersion']),
      editType: serializer.fromJson<int>(json['editType']),
      version: serializer.fromJson<int>(json['version']),
      fileVersion: serializer.fromJson<int>(json['fileVersion']),
      editAt: serializer.fromJson<int>(json['editAt']),
      fileEditAt: serializer.fromJson<int>(json['fileEditAt']),
      fileDirty: serializer.fromJson<int>(json['fileDirty']),
      createAt: serializer.fromJson<int>(json['createAt']),
      name: serializer.fromJson<String>(json['name']),
      md5: serializer.fromJson<String>(json['md5']),
      locked: serializer.fromJson<int>(json['locked']),
      reminder: serializer.fromJson<String>(json['reminder']),
      tags: serializer.fromJson<String>(json['tags']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'batchNo': serializer.toJson<int>(batchNo),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'remoteJson': serializer.toJson<String>(remoteJson),
      'baseFileVersion': serializer.toJson<int>(baseFileVersion),
      'editType': serializer.toJson<int>(editType),
      'version': serializer.toJson<int>(version),
      'fileVersion': serializer.toJson<int>(fileVersion),
      'editAt': serializer.toJson<int>(editAt),
      'fileEditAt': serializer.toJson<int>(fileEditAt),
      'fileDirty': serializer.toJson<int>(fileDirty),
      'createAt': serializer.toJson<int>(createAt),
      'name': serializer.toJson<String>(name),
      'md5': serializer.toJson<String>(md5),
      'locked': serializer.toJson<int>(locked),
      'reminder': serializer.toJson<String>(reminder),
      'tags': serializer.toJson<String>(tags),
      'path': serializer.toJson<String>(path),
    };
  }

  LocalRecord copyWith({
    String? uuid,
    int? batchNo,
    int? remoteVersion,
    String? remoteJson,
    int? baseFileVersion,
    int? editType,
    int? version,
    int? fileVersion,
    int? editAt,
    int? fileEditAt,
    int? fileDirty,
    int? createAt,
    String? name,
    String? md5,
    int? locked,
    String? reminder,
    String? tags,
    String? path,
  }) => LocalRecord(
    uuid: uuid ?? this.uuid,
    batchNo: batchNo ?? this.batchNo,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    remoteJson: remoteJson ?? this.remoteJson,
    baseFileVersion: baseFileVersion ?? this.baseFileVersion,
    editType: editType ?? this.editType,
    version: version ?? this.version,
    fileVersion: fileVersion ?? this.fileVersion,
    editAt: editAt ?? this.editAt,
    fileEditAt: fileEditAt ?? this.fileEditAt,
    fileDirty: fileDirty ?? this.fileDirty,
    createAt: createAt ?? this.createAt,
    name: name ?? this.name,
    md5: md5 ?? this.md5,
    locked: locked ?? this.locked,
    reminder: reminder ?? this.reminder,
    tags: tags ?? this.tags,
    path: path ?? this.path,
  );
  LocalRecord copyWithCompanion(LocalRecordsCompanion data) {
    return LocalRecord(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      batchNo: data.batchNo.present ? data.batchNo.value : this.batchNo,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      remoteJson: data.remoteJson.present
          ? data.remoteJson.value
          : this.remoteJson,
      baseFileVersion: data.baseFileVersion.present
          ? data.baseFileVersion.value
          : this.baseFileVersion,
      editType: data.editType.present ? data.editType.value : this.editType,
      version: data.version.present ? data.version.value : this.version,
      fileVersion: data.fileVersion.present
          ? data.fileVersion.value
          : this.fileVersion,
      editAt: data.editAt.present ? data.editAt.value : this.editAt,
      fileEditAt: data.fileEditAt.present
          ? data.fileEditAt.value
          : this.fileEditAt,
      fileDirty: data.fileDirty.present ? data.fileDirty.value : this.fileDirty,
      createAt: data.createAt.present ? data.createAt.value : this.createAt,
      name: data.name.present ? data.name.value : this.name,
      md5: data.md5.present ? data.md5.value : this.md5,
      locked: data.locked.present ? data.locked.value : this.locked,
      reminder: data.reminder.present ? data.reminder.value : this.reminder,
      tags: data.tags.present ? data.tags.value : this.tags,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRecord(')
          ..write('uuid: $uuid, ')
          ..write('batchNo: $batchNo, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('remoteJson: $remoteJson, ')
          ..write('baseFileVersion: $baseFileVersion, ')
          ..write('editType: $editType, ')
          ..write('version: $version, ')
          ..write('fileVersion: $fileVersion, ')
          ..write('editAt: $editAt, ')
          ..write('fileEditAt: $fileEditAt, ')
          ..write('fileDirty: $fileDirty, ')
          ..write('createAt: $createAt, ')
          ..write('name: $name, ')
          ..write('md5: $md5, ')
          ..write('locked: $locked, ')
          ..write('reminder: $reminder, ')
          ..write('tags: $tags, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    batchNo,
    remoteVersion,
    remoteJson,
    baseFileVersion,
    editType,
    version,
    fileVersion,
    editAt,
    fileEditAt,
    fileDirty,
    createAt,
    name,
    md5,
    locked,
    reminder,
    tags,
    path,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRecord &&
          other.uuid == this.uuid &&
          other.batchNo == this.batchNo &&
          other.remoteVersion == this.remoteVersion &&
          other.remoteJson == this.remoteJson &&
          other.baseFileVersion == this.baseFileVersion &&
          other.editType == this.editType &&
          other.version == this.version &&
          other.fileVersion == this.fileVersion &&
          other.editAt == this.editAt &&
          other.fileEditAt == this.fileEditAt &&
          other.fileDirty == this.fileDirty &&
          other.createAt == this.createAt &&
          other.name == this.name &&
          other.md5 == this.md5 &&
          other.locked == this.locked &&
          other.reminder == this.reminder &&
          other.tags == this.tags &&
          other.path == this.path);
}

class LocalRecordsCompanion extends UpdateCompanion<LocalRecord> {
  final Value<String> uuid;
  final Value<int> batchNo;
  final Value<int> remoteVersion;
  final Value<String> remoteJson;
  final Value<int> baseFileVersion;
  final Value<int> editType;
  final Value<int> version;
  final Value<int> fileVersion;
  final Value<int> editAt;
  final Value<int> fileEditAt;
  final Value<int> fileDirty;
  final Value<int> createAt;
  final Value<String> name;
  final Value<String> md5;
  final Value<int> locked;
  final Value<String> reminder;
  final Value<String> tags;
  final Value<String> path;
  final Value<int> rowid;
  const LocalRecordsCompanion({
    this.uuid = const Value.absent(),
    this.batchNo = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.remoteJson = const Value.absent(),
    this.baseFileVersion = const Value.absent(),
    this.editType = const Value.absent(),
    this.version = const Value.absent(),
    this.fileVersion = const Value.absent(),
    this.editAt = const Value.absent(),
    this.fileEditAt = const Value.absent(),
    this.fileDirty = const Value.absent(),
    this.createAt = const Value.absent(),
    this.name = const Value.absent(),
    this.md5 = const Value.absent(),
    this.locked = const Value.absent(),
    this.reminder = const Value.absent(),
    this.tags = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRecordsCompanion.insert({
    required String uuid,
    this.batchNo = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.remoteJson = const Value.absent(),
    this.baseFileVersion = const Value.absent(),
    this.editType = const Value.absent(),
    this.version = const Value.absent(),
    this.fileVersion = const Value.absent(),
    this.editAt = const Value.absent(),
    this.fileEditAt = const Value.absent(),
    this.fileDirty = const Value.absent(),
    this.createAt = const Value.absent(),
    this.name = const Value.absent(),
    this.md5 = const Value.absent(),
    this.locked = const Value.absent(),
    this.reminder = const Value.absent(),
    this.tags = const Value.absent(),
    this.path = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid);
  static Insertable<LocalRecord> custom({
    Expression<String>? uuid,
    Expression<int>? batchNo,
    Expression<int>? remoteVersion,
    Expression<String>? remoteJson,
    Expression<int>? baseFileVersion,
    Expression<int>? editType,
    Expression<int>? version,
    Expression<int>? fileVersion,
    Expression<int>? editAt,
    Expression<int>? fileEditAt,
    Expression<int>? fileDirty,
    Expression<int>? createAt,
    Expression<String>? name,
    Expression<String>? md5,
    Expression<int>? locked,
    Expression<String>? reminder,
    Expression<String>? tags,
    Expression<String>? path,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (batchNo != null) 'batch_no': batchNo,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (remoteJson != null) 'remote_json': remoteJson,
      if (baseFileVersion != null) 'base_file_version': baseFileVersion,
      if (editType != null) 'edit_type': editType,
      if (version != null) 'version': version,
      if (fileVersion != null) 'file_version': fileVersion,
      if (editAt != null) 'edit_at': editAt,
      if (fileEditAt != null) 'file_edit_at': fileEditAt,
      if (fileDirty != null) 'file_dirty': fileDirty,
      if (createAt != null) 'create_at': createAt,
      if (name != null) 'name': name,
      if (md5 != null) 'md5': md5,
      if (locked != null) 'locked': locked,
      if (reminder != null) 'reminder': reminder,
      if (tags != null) 'tags': tags,
      if (path != null) 'path': path,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRecordsCompanion copyWith({
    Value<String>? uuid,
    Value<int>? batchNo,
    Value<int>? remoteVersion,
    Value<String>? remoteJson,
    Value<int>? baseFileVersion,
    Value<int>? editType,
    Value<int>? version,
    Value<int>? fileVersion,
    Value<int>? editAt,
    Value<int>? fileEditAt,
    Value<int>? fileDirty,
    Value<int>? createAt,
    Value<String>? name,
    Value<String>? md5,
    Value<int>? locked,
    Value<String>? reminder,
    Value<String>? tags,
    Value<String>? path,
    Value<int>? rowid,
  }) {
    return LocalRecordsCompanion(
      uuid: uuid ?? this.uuid,
      batchNo: batchNo ?? this.batchNo,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      remoteJson: remoteJson ?? this.remoteJson,
      baseFileVersion: baseFileVersion ?? this.baseFileVersion,
      editType: editType ?? this.editType,
      version: version ?? this.version,
      fileVersion: fileVersion ?? this.fileVersion,
      editAt: editAt ?? this.editAt,
      fileEditAt: fileEditAt ?? this.fileEditAt,
      fileDirty: fileDirty ?? this.fileDirty,
      createAt: createAt ?? this.createAt,
      name: name ?? this.name,
      md5: md5 ?? this.md5,
      locked: locked ?? this.locked,
      reminder: reminder ?? this.reminder,
      tags: tags ?? this.tags,
      path: path ?? this.path,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (batchNo.present) {
      map['batch_no'] = Variable<int>(batchNo.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (remoteJson.present) {
      map['remote_json'] = Variable<String>(remoteJson.value);
    }
    if (baseFileVersion.present) {
      map['base_file_version'] = Variable<int>(baseFileVersion.value);
    }
    if (editType.present) {
      map['edit_type'] = Variable<int>(editType.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (fileVersion.present) {
      map['file_version'] = Variable<int>(fileVersion.value);
    }
    if (editAt.present) {
      map['edit_at'] = Variable<int>(editAt.value);
    }
    if (fileEditAt.present) {
      map['file_edit_at'] = Variable<int>(fileEditAt.value);
    }
    if (fileDirty.present) {
      map['file_dirty'] = Variable<int>(fileDirty.value);
    }
    if (createAt.present) {
      map['create_at'] = Variable<int>(createAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (md5.present) {
      map['md5'] = Variable<String>(md5.value);
    }
    if (locked.present) {
      map['locked'] = Variable<int>(locked.value);
    }
    if (reminder.present) {
      map['reminder'] = Variable<String>(reminder.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRecordsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('batchNo: $batchNo, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('remoteJson: $remoteJson, ')
          ..write('baseFileVersion: $baseFileVersion, ')
          ..write('editType: $editType, ')
          ..write('version: $version, ')
          ..write('fileVersion: $fileVersion, ')
          ..write('editAt: $editAt, ')
          ..write('fileEditAt: $fileEditAt, ')
          ..write('fileDirty: $fileDirty, ')
          ..write('createAt: $createAt, ')
          ..write('name: $name, ')
          ..write('md5: $md5, ')
          ..write('locked: $locked, ')
          ..write('reminder: $reminder, ')
          ..write('tags: $tags, ')
          ..write('path: $path, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KVConfigsTable extends KVConfigs
    with TableInfo<$KVConfigsTable, KVConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KVConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(KVConfigs.typeLocal),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, type, state];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'k_v_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<KVConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KVConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KVConfig(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $KVConfigsTable createAlias(String alias) {
    return $KVConfigsTable(attachedDatabase, alias);
  }
}

class KVConfig extends DataClass implements Insertable<KVConfig> {
  final String key;
  final String value;
  final String type;
  final int state;
  const KVConfig({
    required this.key,
    required this.value,
    required this.type,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['type'] = Variable<String>(type);
    map['state'] = Variable<int>(state);
    return map;
  }

  KVConfigsCompanion toCompanion(bool nullToAbsent) {
    return KVConfigsCompanion(
      key: Value(key),
      value: Value(value),
      type: Value(type),
      state: Value(state),
    );
  }

  factory KVConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KVConfig(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      type: serializer.fromJson<String>(json['type']),
      state: serializer.fromJson<int>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'type': serializer.toJson<String>(type),
      'state': serializer.toJson<int>(state),
    };
  }

  KVConfig copyWith({String? key, String? value, String? type, int? state}) =>
      KVConfig(
        key: key ?? this.key,
        value: value ?? this.value,
        type: type ?? this.type,
        state: state ?? this.state,
      );
  KVConfig copyWithCompanion(KVConfigsCompanion data) {
    return KVConfig(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      type: data.type.present ? data.type.value : this.type,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KVConfig(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('type: $type, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, type, state);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KVConfig &&
          other.key == this.key &&
          other.value == this.value &&
          other.type == this.type &&
          other.state == this.state);
}

class KVConfigsCompanion extends UpdateCompanion<KVConfig> {
  final Value<String> key;
  final Value<String> value;
  final Value<String> type;
  final Value<int> state;
  final Value<int> rowid;
  const KVConfigsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.type = const Value.absent(),
    this.state = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KVConfigsCompanion.insert({
    required String key,
    required String value,
    this.type = const Value.absent(),
    this.state = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KVConfig> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? type,
    Expression<int>? state,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (type != null) 'type': type,
      if (state != null) 'state': state,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KVConfigsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<String>? type,
    Value<int>? state,
    Value<int>? rowid,
  }) {
    return KVConfigsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      type: type ?? this.type,
      state: state ?? this.state,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KVConfigsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('type: $type, ')
          ..write('state: $state, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecycleRecordsTable extends RecycleRecords
    with TableInfo<$RecycleRecordsTable, RecycleRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecycleRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _reminderMeta = const VerificationMeta(
    'reminder',
  );
  @override
  late final GeneratedColumn<String> reminder = GeneratedColumn<String>(
    'reminder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<int> locked = GeneratedColumn<int>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deleteAtMeta = const VerificationMeta(
    'deleteAt',
  );
  @override
  late final GeneratedColumn<int> deleteAt = GeneratedColumn<int>(
    'delete_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    path,
    name,
    reminder,
    tags,
    locked,
    deleteAt,
    groupId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recycle_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecycleRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('reminder')) {
      context.handle(
        _reminderMeta,
        reminder.isAcceptableOrUnknown(data['reminder']!, _reminderMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('delete_at')) {
      context.handle(
        _deleteAtMeta,
        deleteAt.isAcceptableOrUnknown(data['delete_at']!, _deleteAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deleteAtMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  RecycleRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecycleRecord(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      reminder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}locked'],
      )!,
      deleteAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delete_at'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
    );
  }

  @override
  $RecycleRecordsTable createAlias(String alias) {
    return $RecycleRecordsTable(attachedDatabase, alias);
  }
}

class RecycleRecord extends DataClass implements Insertable<RecycleRecord> {
  final String uuid;
  final String path;
  final String name;
  final String reminder;
  final String tags;
  final int locked;

  /// Deletion timestamp (ms)
  final int deleteAt;

  /// Folder-delete group: '' = single delete, '/Folder/' = part of a folder delete
  final String groupId;
  const RecycleRecord({
    required this.uuid,
    required this.path,
    required this.name,
    required this.reminder,
    required this.tags,
    required this.locked,
    required this.deleteAt,
    required this.groupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['reminder'] = Variable<String>(reminder);
    map['tags'] = Variable<String>(tags);
    map['locked'] = Variable<int>(locked);
    map['delete_at'] = Variable<int>(deleteAt);
    map['group_id'] = Variable<String>(groupId);
    return map;
  }

  RecycleRecordsCompanion toCompanion(bool nullToAbsent) {
    return RecycleRecordsCompanion(
      uuid: Value(uuid),
      path: Value(path),
      name: Value(name),
      reminder: Value(reminder),
      tags: Value(tags),
      locked: Value(locked),
      deleteAt: Value(deleteAt),
      groupId: Value(groupId),
    );
  }

  factory RecycleRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecycleRecord(
      uuid: serializer.fromJson<String>(json['uuid']),
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      reminder: serializer.fromJson<String>(json['reminder']),
      tags: serializer.fromJson<String>(json['tags']),
      locked: serializer.fromJson<int>(json['locked']),
      deleteAt: serializer.fromJson<int>(json['deleteAt']),
      groupId: serializer.fromJson<String>(json['groupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'reminder': serializer.toJson<String>(reminder),
      'tags': serializer.toJson<String>(tags),
      'locked': serializer.toJson<int>(locked),
      'deleteAt': serializer.toJson<int>(deleteAt),
      'groupId': serializer.toJson<String>(groupId),
    };
  }

  RecycleRecord copyWith({
    String? uuid,
    String? path,
    String? name,
    String? reminder,
    String? tags,
    int? locked,
    int? deleteAt,
    String? groupId,
  }) => RecycleRecord(
    uuid: uuid ?? this.uuid,
    path: path ?? this.path,
    name: name ?? this.name,
    reminder: reminder ?? this.reminder,
    tags: tags ?? this.tags,
    locked: locked ?? this.locked,
    deleteAt: deleteAt ?? this.deleteAt,
    groupId: groupId ?? this.groupId,
  );
  RecycleRecord copyWithCompanion(RecycleRecordsCompanion data) {
    return RecycleRecord(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      reminder: data.reminder.present ? data.reminder.value : this.reminder,
      tags: data.tags.present ? data.tags.value : this.tags,
      locked: data.locked.present ? data.locked.value : this.locked,
      deleteAt: data.deleteAt.present ? data.deleteAt.value : this.deleteAt,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecycleRecord(')
          ..write('uuid: $uuid, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('reminder: $reminder, ')
          ..write('tags: $tags, ')
          ..write('locked: $locked, ')
          ..write('deleteAt: $deleteAt, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(uuid, path, name, reminder, tags, locked, deleteAt, groupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecycleRecord &&
          other.uuid == this.uuid &&
          other.path == this.path &&
          other.name == this.name &&
          other.reminder == this.reminder &&
          other.tags == this.tags &&
          other.locked == this.locked &&
          other.deleteAt == this.deleteAt &&
          other.groupId == this.groupId);
}

class RecycleRecordsCompanion extends UpdateCompanion<RecycleRecord> {
  final Value<String> uuid;
  final Value<String> path;
  final Value<String> name;
  final Value<String> reminder;
  final Value<String> tags;
  final Value<int> locked;
  final Value<int> deleteAt;
  final Value<String> groupId;
  final Value<int> rowid;
  const RecycleRecordsCompanion({
    this.uuid = const Value.absent(),
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.reminder = const Value.absent(),
    this.tags = const Value.absent(),
    this.locked = const Value.absent(),
    this.deleteAt = const Value.absent(),
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecycleRecordsCompanion.insert({
    required String uuid,
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.reminder = const Value.absent(),
    this.tags = const Value.absent(),
    this.locked = const Value.absent(),
    required int deleteAt,
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       deleteAt = Value(deleteAt);
  static Insertable<RecycleRecord> custom({
    Expression<String>? uuid,
    Expression<String>? path,
    Expression<String>? name,
    Expression<String>? reminder,
    Expression<String>? tags,
    Expression<int>? locked,
    Expression<int>? deleteAt,
    Expression<String>? groupId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (reminder != null) 'reminder': reminder,
      if (tags != null) 'tags': tags,
      if (locked != null) 'locked': locked,
      if (deleteAt != null) 'delete_at': deleteAt,
      if (groupId != null) 'group_id': groupId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecycleRecordsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? path,
    Value<String>? name,
    Value<String>? reminder,
    Value<String>? tags,
    Value<int>? locked,
    Value<int>? deleteAt,
    Value<String>? groupId,
    Value<int>? rowid,
  }) {
    return RecycleRecordsCompanion(
      uuid: uuid ?? this.uuid,
      path: path ?? this.path,
      name: name ?? this.name,
      reminder: reminder ?? this.reminder,
      tags: tags ?? this.tags,
      locked: locked ?? this.locked,
      deleteAt: deleteAt ?? this.deleteAt,
      groupId: groupId ?? this.groupId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (reminder.present) {
      map['reminder'] = Variable<String>(reminder.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (locked.present) {
      map['locked'] = Variable<int>(locked.value);
    }
    if (deleteAt.present) {
      map['delete_at'] = Variable<int>(deleteAt.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecycleRecordsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('reminder: $reminder, ')
          ..write('tags: $tags, ')
          ..write('locked: $locked, ')
          ..write('deleteAt: $deleteAt, ')
          ..write('groupId: $groupId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PathRecordCount extends DataClass {
  final String path;
  final int? recordCount;
  const PathRecordCount({required this.path, this.recordCount});
  factory PathRecordCount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PathRecordCount(
      path: serializer.fromJson<String>(json['path']),
      recordCount: serializer.fromJson<int?>(json['recordCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'recordCount': serializer.toJson<int?>(recordCount),
    };
  }

  PathRecordCount copyWith({
    String? path,
    Value<int?> recordCount = const Value.absent(),
  }) => PathRecordCount(
    path: path ?? this.path,
    recordCount: recordCount.present ? recordCount.value : this.recordCount,
  );
  @override
  String toString() {
    return (StringBuffer('PathRecordCount(')
          ..write('path: $path, ')
          ..write('recordCount: $recordCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, recordCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathRecordCount &&
          other.path == this.path &&
          other.recordCount == this.recordCount);
}

class $PathRecordCountsView
    extends ViewInfo<$PathRecordCountsView, PathRecordCount>
    implements HasResultSet {
  final String? _alias;
  @override
  final _$AppDatabase attachedDatabase;
  $PathRecordCountsView(this.attachedDatabase, [this._alias]);
  $LocalRecordsTable get records =>
      attachedDatabase.localRecords.createAlias('t0');
  @override
  List<GeneratedColumn> get $columns => [path, recordCount];
  @override
  String get aliasedName => _alias ?? entityName;
  @override
  String get entityName => 'PathRecordCounts';
  @override
  Map<SqlDialect, String>? get createViewStatements => null;
  @override
  $PathRecordCountsView get asDslTable => this;
  @override
  PathRecordCount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PathRecordCount(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      recordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_count'],
      ),
    );
  }

  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    generatedAs: GeneratedAs(records.path, false),
    type: DriftSqlType.string,
  );
  late final GeneratedColumn<int> recordCount = GeneratedColumn<int>(
    'record_count',
    aliasedName,
    true,
    generatedAs: GeneratedAs(BaseAggregate(records.uuid).count(), false),
    type: DriftSqlType.int,
  );
  @override
  $PathRecordCountsView createAlias(String alias) {
    return $PathRecordCountsView(attachedDatabase, alias);
  }

  @override
  Query? get query =>
      (attachedDatabase.selectOnly(records)..addColumns($columns))
        ..groupBy([records.path]);
  @override
  Set<String> get readTables => const {'local_records'};
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalRecordsTable localRecords = $LocalRecordsTable(this);
  late final $KVConfigsTable kVConfigs = $KVConfigsTable(this);
  late final $RecycleRecordsTable recycleRecords = $RecycleRecordsTable(this);
  late final $PathRecordCountsView pathRecordCounts = $PathRecordCountsView(
    this,
  );
  late final Index recordsPathIdx = Index(
    'records_path_idx',
    'CREATE INDEX records_path_idx ON local_records (path)',
  );
  late final Index recordsVersionIdx = Index(
    'records_version_idx',
    'CREATE INDEX records_version_idx ON local_records (remote_version)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localRecords,
    kVConfigs,
    recycleRecords,
    pathRecordCounts,
    recordsPathIdx,
    recordsVersionIdx,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$LocalRecordsTableCreateCompanionBuilder =
    LocalRecordsCompanion Function({
      required String uuid,
      Value<int> batchNo,
      Value<int> remoteVersion,
      Value<String> remoteJson,
      Value<int> baseFileVersion,
      Value<int> editType,
      Value<int> version,
      Value<int> fileVersion,
      Value<int> editAt,
      Value<int> fileEditAt,
      Value<int> fileDirty,
      Value<int> createAt,
      Value<String> name,
      Value<String> md5,
      Value<int> locked,
      Value<String> reminder,
      Value<String> tags,
      Value<String> path,
      Value<int> rowid,
    });
typedef $$LocalRecordsTableUpdateCompanionBuilder =
    LocalRecordsCompanion Function({
      Value<String> uuid,
      Value<int> batchNo,
      Value<int> remoteVersion,
      Value<String> remoteJson,
      Value<int> baseFileVersion,
      Value<int> editType,
      Value<int> version,
      Value<int> fileVersion,
      Value<int> editAt,
      Value<int> fileEditAt,
      Value<int> fileDirty,
      Value<int> createAt,
      Value<String> name,
      Value<String> md5,
      Value<int> locked,
      Value<String> reminder,
      Value<String> tags,
      Value<String> path,
      Value<int> rowid,
    });

class $$LocalRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRecordsTable> {
  $$LocalRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batchNo => $composableBuilder(
    column: $table.batchNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseFileVersion => $composableBuilder(
    column: $table.baseFileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editType => $composableBuilder(
    column: $table.editType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileVersion => $composableBuilder(
    column: $table.fileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editAt => $composableBuilder(
    column: $table.editAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileEditAt => $composableBuilder(
    column: $table.fileEditAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileDirty => $composableBuilder(
    column: $table.fileDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createAt => $composableBuilder(
    column: $table.createAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get md5 => $composableBuilder(
    column: $table.md5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRecordsTable> {
  $$LocalRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batchNo => $composableBuilder(
    column: $table.batchNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseFileVersion => $composableBuilder(
    column: $table.baseFileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editType => $composableBuilder(
    column: $table.editType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileVersion => $composableBuilder(
    column: $table.fileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editAt => $composableBuilder(
    column: $table.editAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileEditAt => $composableBuilder(
    column: $table.fileEditAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileDirty => $composableBuilder(
    column: $table.fileDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createAt => $composableBuilder(
    column: $table.createAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get md5 => $composableBuilder(
    column: $table.md5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRecordsTable> {
  $$LocalRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get batchNo =>
      $composableBuilder(column: $table.batchNo, builder: (column) => column);

  GeneratedColumn<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteJson => $composableBuilder(
    column: $table.remoteJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseFileVersion => $composableBuilder(
    column: $table.baseFileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get editType =>
      $composableBuilder(column: $table.editType, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get fileVersion => $composableBuilder(
    column: $table.fileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get editAt =>
      $composableBuilder(column: $table.editAt, builder: (column) => column);

  GeneratedColumn<int> get fileEditAt => $composableBuilder(
    column: $table.fileEditAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileDirty =>
      $composableBuilder(column: $table.fileDirty, builder: (column) => column);

  GeneratedColumn<int> get createAt =>
      $composableBuilder(column: $table.createAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get md5 =>
      $composableBuilder(column: $table.md5, builder: (column) => column);

  GeneratedColumn<int> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<String> get reminder =>
      $composableBuilder(column: $table.reminder, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);
}

class $$LocalRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRecordsTable,
          LocalRecord,
          $$LocalRecordsTableFilterComposer,
          $$LocalRecordsTableOrderingComposer,
          $$LocalRecordsTableAnnotationComposer,
          $$LocalRecordsTableCreateCompanionBuilder,
          $$LocalRecordsTableUpdateCompanionBuilder,
          (
            LocalRecord,
            BaseReferences<_$AppDatabase, $LocalRecordsTable, LocalRecord>,
          ),
          LocalRecord,
          PrefetchHooks Function()
        > {
  $$LocalRecordsTableTableManager(_$AppDatabase db, $LocalRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int> batchNo = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<String> remoteJson = const Value.absent(),
                Value<int> baseFileVersion = const Value.absent(),
                Value<int> editType = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> fileVersion = const Value.absent(),
                Value<int> editAt = const Value.absent(),
                Value<int> fileEditAt = const Value.absent(),
                Value<int> fileDirty = const Value.absent(),
                Value<int> createAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> md5 = const Value.absent(),
                Value<int> locked = const Value.absent(),
                Value<String> reminder = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRecordsCompanion(
                uuid: uuid,
                batchNo: batchNo,
                remoteVersion: remoteVersion,
                remoteJson: remoteJson,
                baseFileVersion: baseFileVersion,
                editType: editType,
                version: version,
                fileVersion: fileVersion,
                editAt: editAt,
                fileEditAt: fileEditAt,
                fileDirty: fileDirty,
                createAt: createAt,
                name: name,
                md5: md5,
                locked: locked,
                reminder: reminder,
                tags: tags,
                path: path,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<int> batchNo = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<String> remoteJson = const Value.absent(),
                Value<int> baseFileVersion = const Value.absent(),
                Value<int> editType = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> fileVersion = const Value.absent(),
                Value<int> editAt = const Value.absent(),
                Value<int> fileEditAt = const Value.absent(),
                Value<int> fileDirty = const Value.absent(),
                Value<int> createAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> md5 = const Value.absent(),
                Value<int> locked = const Value.absent(),
                Value<String> reminder = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRecordsCompanion.insert(
                uuid: uuid,
                batchNo: batchNo,
                remoteVersion: remoteVersion,
                remoteJson: remoteJson,
                baseFileVersion: baseFileVersion,
                editType: editType,
                version: version,
                fileVersion: fileVersion,
                editAt: editAt,
                fileEditAt: fileEditAt,
                fileDirty: fileDirty,
                createAt: createAt,
                name: name,
                md5: md5,
                locked: locked,
                reminder: reminder,
                tags: tags,
                path: path,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRecordsTable, LocalRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRecordsTable,
                    LocalRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRecordsTable,
      LocalRecord,
      $$LocalRecordsTableFilterComposer,
      $$LocalRecordsTableOrderingComposer,
      $$LocalRecordsTableAnnotationComposer,
      $$LocalRecordsTableCreateCompanionBuilder,
      $$LocalRecordsTableUpdateCompanionBuilder,
      (
        LocalRecord,
        BaseReferences<_$AppDatabase, $LocalRecordsTable, LocalRecord>,
      ),
      LocalRecord,
      PrefetchHooks Function()
    >;
typedef $$KVConfigsTableCreateCompanionBuilder = KVConfigsCompanion Function({
  required String key,
  required String value,
  Value<String> type,
  Value<int> state,
  Value<int> rowid,
});
typedef $$KVConfigsTableUpdateCompanionBuilder = KVConfigsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<String> type,
  Value<int> state,
  Value<int> rowid,
});

class $$KVConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $KVConfigsTable> {
  $$KVConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KVConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $KVConfigsTable> {
  $$KVConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KVConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KVConfigsTable> {
  $$KVConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);
}

class $$KVConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KVConfigsTable,
          KVConfig,
          $$KVConfigsTableFilterComposer,
          $$KVConfigsTableOrderingComposer,
          $$KVConfigsTableAnnotationComposer,
          $$KVConfigsTableCreateCompanionBuilder,
          $$KVConfigsTableUpdateCompanionBuilder,
          (KVConfig, BaseReferences<_$AppDatabase, $KVConfigsTable, KVConfig>),
          KVConfig,
          PrefetchHooks Function()
        > {
  $$KVConfigsTableTableManager(_$AppDatabase db, $KVConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KVConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KVConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KVConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KVConfigsCompanion(
                key: key,
                value: value,
                type: type,
                state: state,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<String> type = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KVConfigsCompanion.insert(
                key: key,
                value: value,
                type: type,
                state: state,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KVConfigsTable, KVConfig>(table),
                  BaseReferences<_$AppDatabase, $KVConfigsTable, KVConfig>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KVConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KVConfigsTable,
      KVConfig,
      $$KVConfigsTableFilterComposer,
      $$KVConfigsTableOrderingComposer,
      $$KVConfigsTableAnnotationComposer,
      $$KVConfigsTableCreateCompanionBuilder,
      $$KVConfigsTableUpdateCompanionBuilder,
      (KVConfig, BaseReferences<_$AppDatabase, $KVConfigsTable, KVConfig>),
      KVConfig,
      PrefetchHooks Function()
    >;
typedef $$RecycleRecordsTableCreateCompanionBuilder =
    RecycleRecordsCompanion Function({
      required String uuid,
      Value<String> path,
      Value<String> name,
      Value<String> reminder,
      Value<String> tags,
      Value<int> locked,
      required int deleteAt,
      Value<String> groupId,
      Value<int> rowid,
    });
typedef $$RecycleRecordsTableUpdateCompanionBuilder =
    RecycleRecordsCompanion Function({
      Value<String> uuid,
      Value<String> path,
      Value<String> name,
      Value<String> reminder,
      Value<String> tags,
      Value<int> locked,
      Value<int> deleteAt,
      Value<String> groupId,
      Value<int> rowid,
    });

class $$RecycleRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RecycleRecordsTable> {
  $$RecycleRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deleteAt => $composableBuilder(
    column: $table.deleteAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecycleRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecycleRecordsTable> {
  $$RecycleRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deleteAt => $composableBuilder(
    column: $table.deleteAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecycleRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecycleRecordsTable> {
  $$RecycleRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get reminder =>
      $composableBuilder(column: $table.reminder, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<int> get deleteAt =>
      $composableBuilder(column: $table.deleteAt, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);
}

class $$RecycleRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecycleRecordsTable,
          RecycleRecord,
          $$RecycleRecordsTableFilterComposer,
          $$RecycleRecordsTableOrderingComposer,
          $$RecycleRecordsTableAnnotationComposer,
          $$RecycleRecordsTableCreateCompanionBuilder,
          $$RecycleRecordsTableUpdateCompanionBuilder,
          (
            RecycleRecord,
            BaseReferences<_$AppDatabase, $RecycleRecordsTable, RecycleRecord>,
          ),
          RecycleRecord,
          PrefetchHooks Function()
        > {
  $$RecycleRecordsTableTableManager(
    _$AppDatabase db,
    $RecycleRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecycleRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecycleRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecycleRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> reminder = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> locked = const Value.absent(),
                Value<int> deleteAt = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecycleRecordsCompanion(
                uuid: uuid,
                path: path,
                name: name,
                reminder: reminder,
                tags: tags,
                locked: locked,
                deleteAt: deleteAt,
                groupId: groupId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> reminder = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> locked = const Value.absent(),
                required int deleteAt,
                Value<String> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecycleRecordsCompanion.insert(
                uuid: uuid,
                path: path,
                name: name,
                reminder: reminder,
                tags: tags,
                locked: locked,
                deleteAt: deleteAt,
                groupId: groupId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecycleRecordsTable, RecycleRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecycleRecordsTable,
                    RecycleRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecycleRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecycleRecordsTable,
      RecycleRecord,
      $$RecycleRecordsTableFilterComposer,
      $$RecycleRecordsTableOrderingComposer,
      $$RecycleRecordsTableAnnotationComposer,
      $$RecycleRecordsTableCreateCompanionBuilder,
      $$RecycleRecordsTableUpdateCompanionBuilder,
      (
        RecycleRecord,
        BaseReferences<_$AppDatabase, $RecycleRecordsTable, RecycleRecord>,
      ),
      RecycleRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalRecordsTableTableManager get localRecords =>
      $$LocalRecordsTableTableManager(_db, _db.localRecords);
  $$KVConfigsTableTableManager get kVConfigs =>
      $$KVConfigsTableTableManager(_db, _db.kVConfigs);
  $$RecycleRecordsTableTableManager get recycleRecords =>
      $$RecycleRecordsTableTableManager(_db, _db.recycleRecords);
}
