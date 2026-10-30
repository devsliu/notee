import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:notee/filesync/file_store.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/common/input_dialog.dart';
import 'package:notee/ui/common/popup_menu.dart';
import 'package:notee/ui/editor/share_record_dialog.dart';
import 'package:notee/ui/files/record_list_actions.dart';
import 'package:notee/ui/files/record_io.dart';
import 'package:notee/ui/files/record_move_dialog.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/utils.dart';
import 'package:flutter/material.dart';

Future<void> showRecordContextMenu(
  BuildContext context,
  TreeContent file,
  Offset position,
  ValueCallback<RecordEntry> onRecordCreate,
) async {
  final isFile = file is TreeContentFile;
  final isFolder = file is TreeContentFolder;
  final fullPath = isFolder ? file.path : '${file.path}${file.name}';
  final items = <PopupItem>[];

  Icon actionIcon(IconData icon) => Icon(icon, size: 18);

  if (isFile) {
    items.add(PopupItem(icon: actionIcon(Icons.drive_file_move_outline), label: l10n.moveRecord, value: 'move'));
    if (file.locked != 0) {
      items.add(PopupItem(icon: actionIcon(Icons.lock_open_outlined), label: l10n.unlockRecord, value: 'unlock'));
    } else {
      items.add(PopupItem(icon: actionIcon(Icons.lock_outline), label: l10n.lockRecord, value: 'lock'));
    }
    items.add(PopupItem(icon: actionIcon(Icons.delete_outline), label: l10n.deleteRecord, value: 'delete'));
    items.add(
      PopupItem(icon: actionIcon(Icons.check_box_outlined), label: l10n.multiSelect, value: 'multiSelect'),
    );
    items.add(PopupItem(icon: actionIcon(Icons.share_outlined), label: l10n.share, value: 'share'));
    items.add(
      PopupItem(icon: actionIcon(Icons.description_outlined), label: l10n.exportMd, value: 'exportMarkdown'),
    );
  } else {
    items.add(PopupItem(icon: actionIcon(Icons.edit_note_outlined), label: l10n.newRecord, value: 'newRecord'));
    items.add(
      PopupItem(icon: actionIcon(Icons.create_new_folder_outlined), label: l10n.newFolder, value: 'newFolder'),
    );
    items.add(
      PopupItem(icon: actionIcon(Icons.drive_file_rename_outline), label: l10n.renameFolder, value: 'rename'),
    );
    items.add(PopupItem(icon: actionIcon(Icons.move_up), label: l10n.moveFolder, value: 'move'));
    items.add(PopupItem(icon: actionIcon(Icons.delete_outline), label: l10n.deleteFolder, value: 'delete'));
    items.add(
      PopupItem(icon: actionIcon(Icons.description_outlined), label: l10n.exportMd, value: 'exportMarkdown'),
    );
    items.add(
      PopupItem(icon: actionIcon(Icons.upload_file_outlined), label: l10n.importDocument, value: 'importDocument'),
    );
    items.add(
      PopupItem(
        icon: actionIcon(Icons.create_new_folder_outlined),
        label: l10n.importFolder,
        value: 'importFolder',
      ),
    );
  }

  final result = await showPopup(
    maxWidth: 200,
    minWidth: 80,
    modal: true,
    context: context,
    position: position,
    items: items,
    title: Text(fullPath, style: const TextStyle(fontSize: 12)),
  );
  if (context.mounted == false || result == null) return;

  if (result == 'rename') {
    String oldName = file.name;
    final newName = await showInputDialog(context, l10n.rename, oldName, false);
    if (context.mounted && newName != null && newName.isNotEmpty && newName != oldName) {
      if (isFile) {
        await _renameRecord(context, file, newName);
      } else if (isFolder) {
        await _renameFolder(context, file, '${file.dir}$newName/');
      }
    }
  } else if (result == 'multiSelect' && isFile) {
    MultiSelectState.instance.enter(file.uuid);
  } else if (result == 'move' && isFile) {
    _showRecordMoveDialog(context, file);
  } else if (result == 'move' && isFolder) {
    showFolderMoveDialog(context, file);
  } else if (result == 'delete') {
    if (isFile) {
      _deleteRecord(context, file);
    } else if (isFolder) {
      _deleteFolder(context, file);
    }
  } else if (result == 'lock' && isFile) {
    showInputDialog(context, "${l10n.enterLockPassword} ${file.name}", "", false).then((pass) {
      if (pass == null || pass.isEmpty || context.mounted == false) return;
      _lockRecord(context, file, pass, true);
    });
  } else if (result == 'unlock' && isFile) {
    showInputDialog(context, "${l10n.enterUnlockPassword} ${file.name}", "", true).then((pass) async {
      if (pass == null || pass.isEmpty || context.mounted == false) return;
      await _lockRecord(context, file, pass, false);
    });
  } else if (result == 'newRecord' && isFolder) {
    RecordListActions.clickOnCreateRecordButton(context, file.path, onRecordCreate);
  } else if (result == 'newFolder' && isFolder) {
    RecordListActions.clickOnCreateFolderButton(context, file.path);
  } else if (result == 'importDocument' && isFolder) {
    RecordImport.pickAndImportDocuments(context, file.path);
  } else if (result == 'importFolder' && isFolder) {
    RecordImport.pickAndImportFolder(context, file.path);
  } else if (result == 'share' && isFile) {
    _shareRecord(context, file);
  } else if (result == 'exportMarkdown' && isFolder) {
    RecordExport.start(context, file.path);
  } else if (result == 'exportMarkdown' && isFile) {
    RecordExport.startSingle(context, file);
  }
}

void _showRecordMoveDialog(BuildContext context, TreeContentFile file) {
  // Use RecordMoveControl for type and folder selection
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: RecordMoveControl(
        title: l10n.moveRecordTo(file.name),
        initFolder: file.path,
        onConfirm: (path) {
          moveRecordToPath(context, file, path);
        },
      ),
    ),
  );
}

void showFolderMoveDialog(BuildContext context, TreeContentFolder folder) {
  // Use RecordMoveControl for type and folder selection
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: RecordMoveControl(
        title: l10n.moveRecordTo(folder.name),
        initFolder: "/",
        onConfirm: (path) {
          _renameFolder(context, folder, "$path${folder.name}/");
        },
      ),
    ),
  );
}

Future<void> moveRecordToPath(BuildContext context, TreeContentFile file, String newPath) async {
  var newRecord = await Repository.get().editRecord(
    file.uuid,
    false,
    DateTime.now().millisecondsSinceEpoch,
    path: newPath,
  );
  if (newRecord == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveRecordFailed)));
    }
    return;
  }
  if (context.mounted) {
    final fileName = newRecord.local.name;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.movedToPath(fileName, newPath)), duration: const Duration(seconds: 2)));
  }
}

Future<void> moveFolderToPath(BuildContext context, TreeContentFolder folder, String newParentPath) async {
  await _renameFolder(context, folder, "$newParentPath${folder.name}/");
}

Future<void> _lockRecord(BuildContext context, TreeContentFile record, String pass, bool lock) async {
  FileStore? fileStore = Repository.get().fileStore;
  if (fileStore == null) {
    return;
  }
  String? content = await _readRecordFile(record);
  if (content == null) {
    if (context.mounted) {
      // If content cannot be read, prompt user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotReadRecordContent)));
    }
    return;
  }
  String lockTips = lock ? l10n.lock : l10n.unlock;
  // Only the content body is encrypted; the [[image]] asset header stays plaintext.
  final (assets, body) = RecordSections.splitContent(content);
  final transformed = lock ? Utils.encryptContent(body, pass) : Utils.decryptContent(body, pass);
  if (transformed == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.lockUnlockFailedCheckPassword(lockTips))));
    }
    return;
  }
  final newContent = RecordSections.buildRecordContent(assets, transformed);

  // Save locked content to file
  try {
    await fileStore.createWorkFile(record.uuid, newContent);

    await Repository.get().editRecord(
      record.uuid,
      true,
      DateTime.now().millisecondsSinceEpoch,
      locked: lock ? 1 : 0,
      md5: Utils.generateMd5(newContent),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.recordLockUnlockCompleted(lockTips))));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveLockUnlockContentFailed(lockTips))));
    }
  }
}

Future<void> _shareRecord(BuildContext context, TreeContentFile file) async {
  final content = await _readRecordFile(file);
  if (content == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotReadRecordContent)));
    }
    return;
  }
  if (!context.mounted) return;
  // Extract the content body; locked records store the body encrypted.
  final (_, body) = RecordSections.splitContent(content);
  // Locked records are stored encrypted; prompt for the password to get plaintext
  String plaintext = body;
  if (file.locked == 1) {
    final password = await showInputDialog(context, l10n.recordLocked, '', true);
    if (password == null || password.isEmpty) return;
    final decrypted = Utils.decryptContent(body, password);
    if (decrypted == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordIncorrect)));
      }
      return;
    }
    plaintext = decrypted;
  }
  // Work files store either a rich-text JSON document or plain text/markdown
  String markdown = plaintext;
  final trimmed = plaintext.trim();
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      markdown = documentToMarkdown(Document.fromJson(jsonDecode(trimmed) as Map<String, dynamic>));
    } catch (_) {}
  }
  if (context.mounted) {
    ShareRecordDialog.show(
      context,
      uuid: file.uuid,
      markdown: markdown,
      title: file.name,
      pathName: '${file.path}${file.name}',
    );
  }
}

Future<String?> _readRecordFile(TreeContentFile record) async {
  FileStore? fileStore = Repository.get().fileStore;
  if (fileStore == null) {
    return null;
  }
  File file = File(fileStore.getWorkFile(record.uuid));
  if (record.version > 0 && !file.existsSync()) {
    file = File(fileStore.getBaseFile(record.uuid));
    if (!file.existsSync()) {
      // If this is an existing record, try downloading from cloud
      await fileStore.downloadBaseFile(record.uuid);
    }
  }
  if (!file.existsSync()) {
    return null;
  }
  return file.readAsStringSync();
}

// Show password input dialog to lock/unlock records

// File/folder operation interface
Future<void> _renameRecord(BuildContext context, TreeContentFile record, String newName) async {
  String oldName = record.name;
  if (oldName == newName) return; // No actual change

  await Repository.get().editRecord(record.uuid, false, DateTime.now().millisecondsSinceEpoch, name: newName);
}

Future<void> _renameFolder(BuildContext context, TreeContentFolder folder, String newPath) async {
  final oldPath = folder.path;
  if (oldPath == newPath) return; // No actual change

  Repository.get().renameFolder(folder.path, newPath);
}

void _deleteRecord(BuildContext context, TreeContentFile file) async {
  // First save to pending-sync table, operation type is delete
  final confirm = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteThisRecord),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm != true || context.mounted == false) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.recordDeleted('file.name'))));
  Repository.get().deleteRecord(file.uuid);
}

void _deleteFolder(BuildContext context, TreeContentFolder folder) async {
  // First save to pending-sync table, operation type is delete
  final confirm = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteThisFolderAndAllRecords),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm != true || context.mounted == false) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.folderDeleted(folder.path))));

  Repository.get().deleteFolder(folder.path);
}
