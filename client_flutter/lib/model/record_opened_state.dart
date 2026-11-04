import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';

/// Tracks which folder and record are currently open in the UI.
///
/// This is navigation/selection state rather than part of the record tree
/// structure, so it lives separately from [RecordTree]. The tree resolves the
/// stored path/uuid to actual nodes/content when needed.
///
/// On first access via [get], this state binds to `Repository.get().recordTree`
/// and listens to its refresh events. When a folder is deleted and it was the
/// currently opened folder, the opened folder is moved to its parent.
class RecordOpenedState {
  static final RecordOpenedState _instance = RecordOpenedState._();
  RecordOpenedState._();

  static RecordOpenedState get() {
    if (_instance._tree == null) {
      _instance.bind(Repository.get().recordTree);
    }
    return _instance;
  }

  //path
  final ValueNotifier<String> openedFolderNotifier = ValueNotifier<String>("/");
  //uuid
  final ValueNotifier<String> openedFileNotifier = ValueNotifier<String>("");

  /// Stack of opened record uuids; the last element is the currently active one.
  final List<String> openedUuids = [];

  RecordTree? _tree;
  StreamSubscription<RecordEvent>? _treeSub;

  /// Attach to [tree] and start listening for folder delete events so the
  /// opened folder can be adjusted automatically.
  void bind(RecordTree tree) {
    _tree = tree;
    _treeSub = tree.onEvent.listen(_onTreeEvent);
  }

  void _onTreeEvent(RecordEvent event) {
    // rebuild: re-validate opened folder / file against the fresh tree
    if (event.rebuildRecords != null) {
      final tree = _tree;
      if (tree != null) {
        final currentFolder = openedFolderNotifier.value;
        if (tree.findFolder(currentFolder) == null) {
          setOpenedFolder("/");
        }
        final currentUuid = openedFileNotifier.value;
        if (currentUuid.isNotEmpty && tree.findRecord(currentUuid) == null) {
          closeFile(currentUuid);
        }
      }
    }

    // deleteFolders: close if the opened folder or any ancestor was deleted
    if (event.deleteFolders != null) {
      final current = openedFolderNotifier.value;
      for (final deletedPath in event.deleteFolders!) {
        if (current == deletedPath || current.startsWith(deletedPath)) {
          setOpenedFolder(RecordPath.dirname(deletedPath));
          break;
        }
      }
    }

    // renameFolder: remap the opened folder if it was renamed or a descendant
    if (event.renameFolder != null) {
      final (oldPath, newPath) = event.renameFolder!;
      final current = openedFolderNotifier.value;
      if (current == oldPath || current.startsWith(oldPath)) {
        setOpenedFolder(newPath + current.substring(oldPath.length));
      }
    }

    // deleteRecords: close if the currently opened file got deleted
    if (event.deleteRecords != null) {
      final currentUuid = openedFileNotifier.value;
      if (currentUuid.isNotEmpty && event.deleteRecords!.contains(currentUuid)) {
        closeFile(currentUuid);
      }
    }
  }

  /// Open [uuid]: move it to the top of the stack (or add it) and make it the
  /// currently active record.
  void openFile(String uuid) {
    openedUuids.remove(uuid);
    openedUuids.add(uuid);
    _syncOpenedFile();
  }

  /// Close [uuid]: remove it from the stack. The previous record (if any)
  /// becomes active again.
  void closeFile(String uuid) {
    openedUuids.remove(uuid);
    _syncOpenedFile();
  }

  void _syncOpenedFile() {
    final uuid = openedUuids.isNotEmpty ? openedUuids.last : "";
    openedFileNotifier.value = uuid;
    if (uuid.isNotEmpty) {
      final record = _tree?.findRecord(uuid);
      if (record != null) {
        openedFolderNotifier.value = record.local.path;
      }
    }
  }

  void setOpenedFolder(String path) {
    openedFolderNotifier.value = path;
  }

  TreeNode? get openedFileNode {
    return _tree?.findFileNode(openedFileNotifier.value);
  }

  TreeNode get openedFolderNode {
    return _tree?.findFolder(openedFolderNotifier.value) ?? _tree!;
  }

  TreeContentFolder get openedFolder {
    return openedFolderNode.content as TreeContentFolder;
  }

  TreeContentFile? get openedFile => openedFileNode?.content as TreeContentFile?;
}
