import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// A single batched change event. Any field may be null; listeners check
/// which ones are non-null and react accordingly. Multiple change kinds can
/// be accumulated into one event so a single emit covers a whole batch of
/// tree mutations (e.g. sync deleting 695 records = one emit, not 695).
class RecordEvent {
  List<RecordEntry>? _rebuildRecords; // full rebuild from DB, records 为所有记录
  List<String>? _deleteFolders; //
  (String /* oldPath */, String /* newPath */)? _renameFolder;
  String? _createFolder; // path;
  List<String /* uuid */>? _deleteRecords; //
  List<RecordEntry>? _upsertRecords;

  RecordEvent();

  List<RecordEntry>? get rebuildRecords => _rebuildRecords;
  List<String>? get deleteFolders => _deleteFolders;
  (String, String)? get renameFolder => _renameFolder;
  String? get createFolder => _createFolder;
  List<String>? get deleteRecords => _deleteRecords;
  List<RecordEntry>? get upsertRecords => _upsertRecords;

  bool get isEmpty =>
      _rebuildRecords == null &&
      _deleteFolders == null &&
      _renameFolder == null &&
      _createFolder == null &&
      _deleteRecords == null &&
      _upsertRecords == null;

  void addDeleteFolder(String path) {
    _deleteFolders ??= [];
    _deleteFolders!.add(path);
  }

  void addDeleteRecords({String? uuid, List<String>? uuids}) {
    if (uuid == null && uuids == null) return;
    _deleteRecords ??= [];
    if (uuid != null) _deleteRecords!.add(uuid);
    if (uuids != null) _deleteRecords!.addAll(uuids);
  }

  void addUpsertRecords({RecordEntry? entry, List<RecordEntry>? entries}) {
    if (entry == null && entries == null) return;
    _upsertRecords ??= [];
    if (entry != null) _upsertRecords!.add(entry);
    if (entries != null) _upsertRecords!.addAll(entries);
  }

  void setCreateFolder(String path) => _createFolder = path;
  void setRenameFolder((String, String) pair) => _renameFolder = pair;
  void setRebuildRecords(List<RecordEntry> records) => _rebuildRecords = records;
  void clear() {
    _rebuildRecords = null;
    _deleteFolders = null;
    _renameFolder = null;
    _createFolder = null;
    _deleteRecords = null;
    _upsertRecords = null;
  }
}

abstract class TreeContent {
  String _path; // Must end with /
  String _name;
  TreeContent(this._path, this._name);

  String get path => _path;
  String get name => _name;
  String get dir; // The folder's parent is the parent directory; the file's dir is the path
  String get key;
}

// Once a TreeContentFile object is created, regardless of how the file corresponding to the uuid is modified,
// the object will always exist and never be re-created unless the file is deleted
class TreeContentFile extends TreeContent {
  RecordEntry _entry;
  int _editAt;

  TreeContentFile(RecordEntry entry)
    : _entry = entry,
      _editAt = entry.local.editAt,
      super(entry.local.path, entry.local.name);

  String get uuid => _entry.local.uuid;
  String get md5 => _entry.local.remoteMd5;
  int get version => _entry.local.remoteVersion;
  int get createAt => _entry.remote.createAt;
  int get editAt => _editAt;
  int get fileEditAt => _entry.local.fileEditAt;
  bool get syncConflict => _entry.local.syncConflict;
  int get locked => _entry.local.locked;
  // All LocalRecord fields are final; setLocalRecord replaces the whole thing during sync,
  // external callers can compare before/after to determine if file/title changed
  RecordEntry get record => _entry;

  @override
  String get dir => _path;
  @override
  String get key => _entry.local.uuid;

  void setLocalRecord(RecordEntry entry) {
    _entry = entry;
    _path = entry.local.path;
    _name = entry.local.name;
    _editAt = entry.local.editAt;
  }
}

class TreeContentFolder extends TreeContent {
  TreeContentFolder(super._path, super.name);

  @override
  String get dir => RecordPath.dirname(_path);
  @override
  String get key => _path;
}

class TreeNode extends TreeViewNode<TreeContent> {
  TreeNode(super.content, {super.children});

  void removeChild(String key) {
    children.removeWhere((f) => f.content.key == key);
  }

  int indexOfChild(String key) {
    for (var i = 0; i < children.length; i++) {
      if (children[i].content.key == key) {
        return i;
      }
    }
    return -1;
  }

  bool hasChild(String key) => children.any((f) => f.content.key == key);

  void insertChild(TreeNode node) {
    // Determine whether node is folder or file; files are always placed after folders,
    // folders sorted lexicographically among themselves, files sorted lexicographically among themselves
    final bool isFolder = node.content is TreeContentFolder;
    final String name = node.content.name;
    final list = children;

    int i = 0;
    if (isFolder) {
      // 1. If the new node is a folder, it must be inserted in the folder section (front of the List)
      for (; i < list.length; i++) {
        final existing = list[i].content;
        if (existing is! TreeContentFolder) break; // Reached file area, insert immediately here
        if (name.toLowerCase().compareTo(existing.name.toLowerCase()) < 0) break; // Found lexicographic position
      }
    } else {
      // 2. If the new node is a file, it must be inserted after all folders
      // First skip all preceding folders
      for (; i < list.length; i++) {
        if (list[i].content is! TreeContentFolder) break;
      }
      // Find insertion point in the file area by lexicographic order
      for (; i < list.length; i++) {
        final existing = list[i].content;
        if (name.toLowerCase().compareTo(existing.name.toLowerCase()) < 0) break;
      }
    }

    list.insert(i, node);
  }
}

class RecordTree extends TreeNode {
  final Map<String /* path */, TreeNode> _foldersMap = {};
  final Map<String /* uuid */, TreeNode> _filesMap = {};
  final Map<String /* uuid */, RecordEntry> _conflictMap = {};

  // Since TreeContentFile objects once created always exist and are only modified, never re-created until delete,
  // only insert and delete operations need to modify _recentlyFiles array; rename/name changes and edits only need sorting
  final RecordList _sortedFiles = RecordList();

  /// Stream of batched change events. Each event may carry multiple kinds
  /// of changes (e.g. both deletes and upserts from a sync pull).
  final StreamController<RecordEvent> _eventController = StreamController.broadcast();
  Stream<RecordEvent> get onEvent => _eventController.stream;

  /// Total record count; -1 while the first build is pending
  final ValueNotifier<int> countNotifier = ValueNotifier<int>(-1);

  RecordTree() : super(TreeContentFolder("/", ""));

  void _emit(RecordEvent event) {
    if (event.isEmpty) return;
    _eventController.add(event);
    countNotifier.value = _filesMap.length;
  }

  /// Clears the tree, keeps listeners in the loading state, then fills it
  /// once [loader] resolves and emits the rebuild event.
  void rebuild(List<RecordEntry> records) {
    children.clear();
    _foldersMap.clear();
    _filesMap.clear();
    _conflictMap.clear();
    _foldersMap["/"] = this;
    _sortedFiles.files.clear();

    for (final n in records) {
      final (node, isNew) = _insertRecord(n, null);
      if (node != null && isNew) {
        _sortedFiles.add(node.content as TreeContentFile);
      }
    }
    _sortedFiles.sort();

    final event = RecordEvent()..setRebuildRecords(records);
    AppLogger.i('RecordTree', "_emit rebuild count=${records.length}");
    _emit(event);
  }

  List<TreeContentFile> get sortedFiles => _sortedFiles.files;

  void setSortListType(int type) {
    _sortedFiles.setSortType(type);
    _sortedFiles.sort();
  }

  RecordEntry? findRecord(String uuid) {
    return (_filesMap[uuid]?.content as TreeContentFile?)?._entry;
  }

  TreeNode? findFileNode(String uuid) {
    return _filesMap[uuid];
  }

  /// Helper: ensure a folder exists by path; if not, recursively create and attach to tree.
  /// New folder creation is accumulated into [event.setCreateFolder] (overwritten if multiple
  /// folders are created, which only happens for nested creates in renameFolder).
  TreeNode _ensureFolderExists(String folderPath, RecordEvent? event) {
    if (_foldersMap.containsKey(folderPath)) {
      return _foldersMap[folderPath]!;
    }

    final segments = folderPath.split('/').where((s) => s.isNotEmpty).toList();

    String currentPath = '/';
    TreeNode current = this;

    for (final segment in segments) {
      currentPath += '$segment/';

      if (!_foldersMap.containsKey(currentPath)) {
        final newFolder = TreeContentFolder(currentPath, segment);
        final treeNode = TreeNode(newFolder);
        _foldersMap[currentPath] = treeNode;

        current.insertChild(treeNode);
        current = treeNode;

        event?.setCreateFolder(newFolder._path);
      }

      current = _foldersMap[currentPath]!;
    }

    return current;
  }

  List<RecordEntry> get conflictRecords => _conflictMap.values.toList();

  RecordEntry? findConflictRecord(String uuid) => _conflictMap[uuid];

  void _deleteRecord(String recordUuid, RecordEvent? event) {
    _conflictMap.remove(recordUuid);
    final TreeNode? file = _filesMap.remove(recordUuid);
    if (file == null) return;
    event?.addDeleteRecords(uuid: recordUuid);

    final String folder = file.content.dir;
    final TreeNode? parent = _foldersMap[folder];
    if (parent == null) return;
    parent.removeChild(recordUuid);
    _checkAndPurgeEmptyFolder(folder, event);
  }

  void _checkAndPurgeEmptyFolder(String folder, RecordEvent? event) {
    String current = folder;
    while (current != '/' && current != '') {
      final TreeNode? node = _foldersMap[current];
      if (node == null) return;
      if (node.children.isNotEmpty) return;

      _foldersMap.remove(current);
      event?.addDeleteFolder(current);
      String parentDir = RecordPath.dirname(current);
      _foldersMap[parentDir]?.removeChild(current);

      current = parentDir;
    }
  }

  (TreeNode?, bool) _insertRecord(RecordEntry newRecord, RecordEvent? event) {
    if (newRecord.local.editType == LocalEditType.delete) {
      _deleteRecord(newRecord.local.uuid, event);
      return (null, false);
    }

    bool isNew = false;
    TreeNode? node = _filesMap[newRecord.local.uuid];
    final newFolderPath = RecordPath.normalizePath(newRecord.local.path);
    final TreeContentFile? oldFile = node?.content as TreeContentFile?;
    _conflictMap.remove(newRecord.local.uuid);
    if (newRecord.local.syncConflict) {
      _conflictMap[newRecord.local.uuid] = newRecord;
    }

    if (oldFile != null && oldFile.path == newFolderPath) {
      oldFile.setLocalRecord(newRecord);
    } else if (oldFile != null) {
      final String oldFolder = oldFile.dir;
      final TreeNode? oldParent = _foldersMap[oldFolder];

      oldParent?.removeChild(newRecord.local.uuid);

      final newParent = _ensureFolderExists(newFolderPath, event);

      oldFile.setLocalRecord(newRecord);
      newParent.insertChild(node = TreeNode(oldFile));
      _filesMap[oldFile.uuid] = node;

      _checkAndPurgeEmptyFolder(oldFolder, event);
    } else {
      final newParent = _ensureFolderExists(newFolderPath, event);
      final file = TreeContentFile(newRecord);
      file.setLocalRecord(newRecord);
      node = TreeNode(file);
      newParent.insertChild(node);
      _filesMap[newRecord.local.uuid] = node;
      isNew = true;
    }

    event?.addUpsertRecords(entry: newRecord);
    return (node, isNew);
  }

  void _clearFolder(TreeNode node, RecordEvent? event) {
    for (final f in node.children) {
      if (f.content is TreeContentFolder) {
        _clearFolder(f as TreeNode, event);
        _foldersMap.remove(f.content.key);
      } else {
        final file = f.content as TreeContentFile;
        _filesMap.remove(f.content.key);
        _conflictMap.remove(f.content.key);
        event?.addDeleteRecords(uuid: file.uuid);
      }
    }
    node.children.clear();
  }

  Future<void> insertRecord(RecordEntry newRecord) async {
    final event = RecordEvent();
    final (node, isNew) = _insertRecord(newRecord, event);
    if (node != null && isNew) {
      _sortedFiles.add(node.content as TreeContentFile);
    }
    _sortedFiles.sort();
    _emit(event);
  }

  Future<void> deleteRecord(String recordUuid) async {
    final event = RecordEvent();
    _deleteRecord(recordUuid, event);
    _sortedFiles.delete(recordUuid);
    _emit(event);
  }

  Future<void> batchUpdateRecords(List<String> deleteUUids, List<RecordEntry> records) async {
    final event = RecordEvent();
    for (final uuid in deleteUUids) {
      _deleteRecord(uuid, event);
    }
    _sortedFiles.deleteSome(deleteUUids);
    for (final record in records) {
      final (node, isNew) = _insertRecord(record, event);
      if (node != null && isNew) {
        _sortedFiles.add(node.content as TreeContentFile);
      }
    }
    _sortedFiles.sort();
    _emit(event);
  }

  Future<void> deleteFolder(String folderPath) async {
    folderPath = RecordPath.normalizePath(folderPath);
    final folder = _foldersMap[folderPath];
    if (folder == null) return;
    final event = RecordEvent();
    _clearFolder(folder, event);
    _checkAndPurgeEmptyFolder(folderPath, event);
    _sortedFiles.deleteByPath(folderPath);
    _emit(event);
  }

  Future<void> renameFolder(String oldFolderPath, String newFolderPath, int time) async {
    final oldPath = RecordPath.normalizePath(oldFolderPath);
    final newPath = RecordPath.normalizePath(newFolderPath);

    if (oldPath == newPath || oldPath == '/') return;

    final sourceFolder = findFolder(oldPath);
    if (sourceFolder == null) return;
    final sourceParent = findFolder(RecordPath.dirname(sourceFolder.content.path));
    if (sourceParent == null) return;

    // Collect affected file uuids BEFORE merge (merge moves/recreates nodes).
    final affectedUuids = <String>[];
    _collectFileUuids(sourceFolder, affectedUuids);

    sourceParent.removeChild(sourceFolder.content.key);

    final event = RecordEvent();
    _ensureFolderExists(newPath, event);
    final targetFolder = findFolder(newPath)!;
    _mergeVirtualFolders(sourceFolder, targetFolder, time);

    _checkAndPurgeEmptyFolder(sourceParent.content.path, event);

    _sortedFiles.sort();

    // Accumulate upsert for each moved file so listeners (TagTree, ReminderTree,
    // bars) refresh their cached RecordEntry references, then the rename itself.
    final movedEntries = affectedUuids
        .map((uuid) => _filesMap[uuid]?.content as TreeContentFile?)
        .whereType<TreeContentFile>()
        .map((f) => f.record)
        .toList();
    event.addUpsertRecords(entries: movedEntries);
    event.setRenameFolder((oldPath, newPath));
    _emit(event);
  }

  /// Collect uuids of all TreeContentFile descendants under [node].
  void _collectFileUuids(TreeNode node, List<String> out) {
    for (final child in node.children) {
      if (child.content is TreeContentFile) {
        out.add((child.content as TreeContentFile).uuid);
      } else {
        _collectFileUuids(child as TreeNode, out);
      }
    }
  }

  void _mergeVirtualFolders(TreeNode source, TreeNode target, int time) {
    TreeNode? sourceParent = _foldersMap[source.content.dir];
    sourceParent?.removeChild(source.content.path);
    _foldersMap.remove(source.content.key);

    for (final child in source.children) {
      if (child.content is TreeContentFile) {
        final file = child.content as TreeContentFile;
        _filesMap.remove(file.key);
        file.setLocalRecord(RecordEntry(file.record.local.copyWith(path: target.content.path, editAt: time)));
        TreeNode fileNode = TreeNode(file);
        target.insertChild(fileNode);
        _filesMap[fileNode.content.key] = fileNode;
      } else {
        _foldersMap.remove(child.content.key);
        TreeNode folderNode = TreeNode(
          TreeContentFolder(child.content.path, child.content.name),
          children: child.children,
        );
        _updateDescendantsPath(folderNode, source.content.path, target.content.path, time);
        target.insertChild(folderNode);
      }
    }
    source.children.clear();
  }

  void _updateDescendantsPath(TreeNode currentFolder, String oldPrefix, String newPrefix, int time) {
    final oldFolderPath = currentFolder.content.path;
    _foldersMap.remove(oldFolderPath);

    final relativePath = oldFolderPath.substring(oldPrefix.length);
    final updatedFolderPath = newPrefix + relativePath;

    final content = currentFolder.content;
    content._path = updatedFolderPath;
    content._name = RecordPath.basename(updatedFolderPath);
    _foldersMap[updatedFolderPath] = currentFolder;

    for (final node in currentFolder.children) {
      if (node.content is TreeContentFile) {
        final file = node.content as TreeContentFile;
        final fileRelativePath = file.path.substring(oldPrefix.length);
        file.setLocalRecord(RecordEntry(file.record.local.copyWith(path: newPrefix + fileRelativePath, editAt: time)));
      } else {
        _updateDescendantsPath(node as TreeNode, oldPrefix, newPrefix, time);
      }
    }
  }

  TreeNode? findFolder(String path) {
    return _foldersMap[RecordPath.normalizePath(path)];
  }

  Future<void> createFolder(String path) async {
    final event = RecordEvent();
    _ensureFolderExists(path, event);
    _emit(event);
  }
}

class RecordList {
  final List<TreeContentFile> files = [];
  static final int sSortTypeName = 1;
  static final int sSortTypeByTime = 2;
  int sortType = 0;
  void sort() {
    if (sortType == sSortTypeName) {
      files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortType == sSortTypeByTime) {
      files.sort((a, b) {
        final c = b.editAt.compareTo(a.editAt);
        if (c != 0) return c;
        final d = b.createAt.compareTo(a.createAt);
        if (d != 0) return d;
        return b.uuid.compareTo(a.uuid);
      });
    }
  }

  void setSortType(int type) {
    sortType = type;
  }

  void delete(String uuid) {
    files.removeWhere((e) => e.uuid == uuid);
  }

  void deleteByPath(String path) {
    files.removeWhere((e) => e.path.startsWith(path));
  }

  void deleteSome(List<String> uuids) {
    files.removeWhere((e) => uuids.contains(e.uuid));
  }

  void add(TreeContentFile file) {
    files.add(file);
  }
}
