import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/ui/calendar/reminder_panel.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/utils/state_ext.dart';

/// Show a dialog with the full [ReminderPanel] for a record, including
/// a title bar with filename + path.
void showReminderDialog(BuildContext context, String uuid) {
  final record = Repository.get().recordTree.findRecord(uuid);
  if (record == null) return;
  final screenWidth = MediaQuery.of(context).size.width;
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (_) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: math.min(400, screenWidth * 0.85),
        child: ReminderPanel(uuid: uuid, subtitle: '${record.local.path}${record.local.name}', maxLines: 5),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done))],
    ),
  );
}

/// Compact one-line reminder summary bar. Shows task count + first task's
/// name and time. Tapping opens the full [ReminderPanel] in a dialog.
class ReminderBar extends StatefulWidget {
  final String uuid;
  const ReminderBar({super.key, required this.uuid});

  @override
  State<ReminderBar> createState() => _ReminderBarState();
}

class _ReminderBarState extends BaseState<ReminderBar> {
  @override
  void initState() {
    super.initState();
    subscribe(Repository.get().recordTree.onEvent, _onEvent);
  }

  void _onEvent(RecordEvent event) {
    final isRebuild = event.rebuildRecords != null;
    final isMine =
        (event.deleteRecords?.contains(widget.uuid) ?? false) ||
        (event.upsertRecords?.any((r) => r.local.uuid == widget.uuid) ?? false);
    if (!isRebuild && !isMine) return;
    if (mounted) safeSetState();
  }

  @override
  Widget build(BuildContext context) {
    final record = Repository.get().recordTree.findRecord(widget.uuid);
    final tasks = record == null ? const <ReminderTask>[] : ReminderTask.fromJsonString(record.local.reminder);
    if (tasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final first = tasks.first;
    final timeStr = Utils.reminderTimeStr(first);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showReminderDialog(context, widget.uuid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${first.name.isEmpty ? l10n.unnamedTask : first.name} · $timeStr',
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
