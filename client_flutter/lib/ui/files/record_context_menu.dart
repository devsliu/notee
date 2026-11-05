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
import 'package:notee/ui/common/toast.dart';

Future<void> showRecordContextMenu(
  BuildContext context,
  TreeContent file,
  Offset position,
  ValueCallback<RecordEntry> onRecordCreate,
) async {
  final isFile = file is TreeContentFile;
  final isFolder = file is TreeContentFolder;
  final fullPath = isFolder ? file.path : '${file.path}${file.name}';
  final readOnly = Repository.get().syncConfigs.isPathReadOnly(file.path);
  final items = <PopupItem>[];

  Icon actionIcon(IconData icon) => Icon(icon);

  /// Shows the read-only hint snackbar; used as the onTap for disabled items.
  void showReadOnlyHint() {
    Toast.show(context, l10n.readOnlyCannotEdit);
  }

  if (isFile) {
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.drive_file_move_outline),
        title: l10n.move,
        value: 'move',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    if (file.locked != 0) {
      items.add(
        PopupItem.simple(
          icon: actionIcon(Icons.lock_open_outlined),
          title: l10n.unlock,
          value: 'unlock',
          disabled: readOnly,
          onTap: readOnly ? showReadOnlyHint : null,
        ),
      );
    } else {
      items.add(
        PopupItem.simple(
          icon: actionIcon(Icons.lock_outline),
          title: l10n.lock,
          value: 'lock',
          disabled: readOnly,
          onTap: readOnly ? showReadOnlyHint : null,
        ),
      );
    }
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.delete_outline),
        title: l10n.delete,
        value: 'delete',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.check_box_outlined),
        title: l10n.multiSelect,
        value: 'multiSelect',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(PopupItem.simple(icon: actionIcon(Icons.share_outlined), title: l10n.share, value: 'share'));
    items.add(
      PopupItem.simple(icon: actionIcon(Icons.description_outlined), title: l10n.export, value: 'export'),
    );
  } else {
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.edit_note_outlined),
        title: l10n.newRecord,
        value: 'newRecord',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.create_new_folder_outlined),
        title: l10n.newFolder,
        value: 'newFolder',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.drive_file_rename_outline),
        title: l10n.rename,
        value: 'rename',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.move_up),
        title: l10n.move,
        value: 'move',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.delete_outline),
        title: l10n.delete,
        value: 'delete',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(icon: actionIcon(Icons.description_outlined), title: l10n.export, value: 'export'),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.upload_file_outlined),
        title: l10n.importDocument,
        value: 'importDocument',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
    items.add(
      PopupItem.simple(
        icon: actionIcon(Icons.create_new_folder_outlined),
        title: l10n.importFolder,
        value: 'importFolder',
        disabled: readOnly,
        onTap: readOnly ? showReadOnlyHint : null,
      ),
    );
  }

  final result = await showPopup(
    maxWidth: 130,
    minWidth: 90,
    modal: true,
    columns: 2,
    context: context,
    position: position,
    items: items,
    title: Text(readOnly ? '${l10n.readOnlyLabel} $fullPath' : fullPath, style: const TextStyle(fontSize: 12)),
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
    showInputDialogs(
      context,
      title: "${l10n.enterLockPassword} ${file.name}",
      lines: [
        InputLine(obscure: true, autofocus: true, placeholder: l10n.enterLockPassword),
        InputLine(
          obscure: true,
          placeholder: l10n.confirmPassword,
          validator: (v, all, _) => v == all[0] ? null : l10n.passwordMismatch,
        ),
      ],
    ).then((values) {
      if (values == null || values.isEmpty || values.first.isEmpty || context.mounted == false) return;
      _lockRecord(context, file, values.first, true);
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
  } else if (result == 'export' && isFolder) {
    RecordExport.start(context, file.path);
  } else if (result == 'export' && isFile) {
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
      Toast.show(context, l10n.saveRecordFailed);
    }
    return;
  }
  if (context.mounted) {
    final fileName = newRecord.local.name;
    Toast.show(context, l10n.movedToPath(fileName, newPath), duration: const Duration(seconds: 2));
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
      Toast.show(context, l10n.cannotReadRecordContent);
    }
    return;
  }
  String lockTips = lock ? l10n.lock : l10n.unlock;
  // Only the content body is encrypted; the [[image]] asset header stays plaintext.
  final (assets, body) = RecordSections.splitContent(content);
  final transformed = lock ? Utils.encryptContent(body, pass) : Utils.decryptContent(body, pass);
  if (transformed == null) {
    if (context.mounted) {
      Toast.show(context, l10n.lockUnlockFailedCheckPassword(lockTips));
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
      Toast.show(context, l10n.recordLockUnlockCompleted(lockTips));
    }
  } catch (e) {
    if (context.mounted) {
      Toast.show(context, l10n.saveLockUnlockContentFailed(lockTips));
    }
  }
}

Future<void> _shareRecord(BuildContext context, TreeContentFile file) async {
  final content = await _readRecordFile(file);
  if (content == null) {
    if (context.mounted) {
      Toast.show(context, l10n.cannotReadRecordContent);
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
        Toast.show(context, l10n.passwordIncorrect);
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
          child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm != true || context.mounted == false) return;
  Toast.show(context, l10n.recordDeleted(file.name));
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
          child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm != true || context.mounted == false) return;
  Toast.show(context, l10n.folderDeleted(folder.path));

  Repository.get().deleteFolder(folder.path);
}
