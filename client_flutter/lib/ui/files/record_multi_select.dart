import 'package:flutter/material.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/common/input_dialog.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/files/record_move_dialog.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/ui/common/toast.dart';

/// Multi-select state for the record list (batch move/tag/delete).
/// Selection stores record uuids; folders are not selectable.
class MultiSelectState extends ChangeNotifier {
  MultiSelectState._();
  static final MultiSelectState instance = MultiSelectState._();

  bool _active = false;
  final Set<String> _selected = {};

  bool get active => _active;
  Set<String> get selected => Set.unmodifiable(_selected);
  int get count => _selected.length;

  void enter(String uuid) {
    _active = true;
    _selected.add(uuid);
    notifyListeners();
  }

  void toggle(String uuid) {
    if (!_active) return;
    if (_selected.contains(uuid)) {
      _selected.remove(uuid);
      // Auto-exit when nothing left selected
      if (_selected.isEmpty) _active = false;
    } else {
      _selected.add(uuid);
    }
    notifyListeners();
  }

  void exit() {
    _active = false;
    _selected.clear();
    notifyListeners();
  }
}

/// Batch move: reuse the single-record move dialog, apply the chosen path to all selected.
Future<void> batchMoveSelected(BuildContext context) async {
  final uuids = MultiSelectState.instance.selected.toList();
  if (uuids.isEmpty) return;
  final first = Repository.get().recordTree.findRecord(uuids.first);
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: RecordMoveControl(
        title: l10n.moveRecord,
        initFolder: first?.local.path ?? "/",
        onConfirm: (path) async {
          final now = DateTime.now().millisecondsSinceEpoch;
          for (final uuid in uuids) {
            await Repository.get().editRecord(uuid, false, now, path: path);
          }
          if (context.mounted) {
            Toast.show(context, l10n.movedSelectedRecords(uuids.length, path));
          }
          MultiSelectState.instance.exit();
        },
      ),
    ),
  );
}

/// Batch delete: single confirmation, then delete each selected record.
Future<void> batchDeleteSelected(BuildContext context) async {
  final uuids = MultiSelectState.instance.selected.toList();
  if (uuids.isEmpty) return;
  final confirm = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteSelectedRecords(uuids.length)),
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
  for (final uuid in uuids) {
    Repository.get().deleteRecord(uuid);
  }
  Toast.show(context, l10n.deletedSelectedRecords(uuids.length));
  MultiSelectState.instance.exit();
}

/// Batch tag: input one tag name, append it to every selected record.
Future<void> batchTagSelected(BuildContext context) async {
  final uuids = MultiSelectState.instance.selected.toList();
  if (uuids.isEmpty) return;
  final tag = await showInputDialog(context, l10n.addTag, "", false);
  if (tag == null || tag.trim().isEmpty || context.mounted == false) return;
  final trimmed = tag.trim();
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final uuid in uuids) {
    final record = Repository.get().recordTree.findRecord(uuid);
    if (record == null) continue;
    final tags = record.tags;
    if (tags.contains(trimmed)) continue;
    await Repository.get().editRecord(uuid, false, now, tags: TagFormat.serialize([...tags, trimmed]));
  }
  MultiSelectState.instance.exit();
}

/// App bar shown while multi-select is active: count + tag/move/delete/close actions.
PreferredSizeWidget buildMultiSelectAppBar(BuildContext context) {
  final count = MultiSelectState.instance.count;
  return createAppBar(
    automaticallyImplyLeading: false,
    titleSpacing: 12,
    title: l10n.selectedCount(count),
    actions: [
      IconButton(
        onPressed: count == 0 ? null : () => batchTagSelected(context),
        icon: const Icon(Icons.label_outline),
        tooltip: l10n.addTag,
      ),
      IconButton(
        onPressed: count == 0 ? null : () => batchMoveSelected(context),
        icon: const Icon(Icons.drive_file_move_outlined),
        tooltip: l10n.moveRecord,
      ),
      IconButton(
        onPressed: count == 0 ? null : () => batchDeleteSelected(context),
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.delete,
      ),
      IconButton(
        onPressed: () => MultiSelectState.instance.exit(),
        icon: const Icon(Icons.close),
        tooltip: l10n.close,
      ),
    ],
  );
}
