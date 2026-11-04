import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/ui/calendar/reminder_task_editor.dart';

class ReminderPanel extends StatefulWidget {
  final String uuid;

  /// Maximum number of task rows to show before scrolling.
  final int maxLines;

  /// Whether tasks can be edited/added/deleted.
  final bool editable;

  /// Optional subtitle shown at the top (e.g. record path).
  final String? subtitle;

  const ReminderPanel({super.key, required this.uuid, this.maxLines = 10, this.editable = true, this.subtitle});

  @override
  State<ReminderPanel> createState() => ReminderPanelState();
}

class ReminderPanelState extends State<ReminderPanel> {
  List<ReminderTask> _tasks = [];
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _loadTasks() {
    final record = Repository.get().recordTree.findRecord(widget.uuid);
    if (record == null) return;
    setState(() {
      _tasks = ReminderTask.fromJsonString(record.local.reminder);
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _saveTasks);
  }

  Future<void> _saveTasks() async {
    final repo = Repository.get();
    final json = ReminderTask.toJsonString(_tasks);
    await repo.editRecord(widget.uuid, false, DateTime.now().millisecondsSinceEpoch, reminder: json);
  }

  /// Show the task editor dialog for adding a new task.
  void showAddDialog() {
    if (!widget.editable) return;
    final task = ReminderTask(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    _showEditor(task, isNew: true);
  }

  Future<void> _showEditor(ReminderTask task, {required bool isNew}) async {
    final updated = await showReminderTaskEditor(context, task: task);
    if (updated == null || !mounted) return;
    final idx = _tasks.indexWhere((t) => t.id == updated.id);
    setState(() {
      if (idx >= 0) {
        _tasks[idx] = updated;
      } else {
        _tasks.add(updated);
      }
    });
    _scheduleSave();
  }

  void _removeTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
    _scheduleSave();
  }

  void _toggleDone(ReminderTask task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    setState(() {
      _tasks[idx] = task.copyWith(done: !task.done);
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final itemHeight = 40.0;
    final maxHeight = widget.maxLines * itemHeight + 60; // +32: header row scrolls with the items

    final rows = <Widget>[];
    for (var i = 0; i < _tasks.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, color: theme.colorScheme.outline.withAlpha(30)));
      rows.add(
        _TaskRow(
          task: _tasks[i],
          editable: widget.editable,
          onToggle: () => _toggleDone(_tasks[i]),
          onEdit: () => _showEditor(_tasks[i], isNew: false),
          onRemove: () => _removeTask(_tasks[i].id),
        ),
      );
    }
    final header = Row(
      children: [
        const SizedBox(width: 8),
        Icon(Icons.notifications_active_outlined, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          l10n.reminderTasks,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const Spacer(),
        if (widget.editable)
          IconButton(
            icon: Icon(Icons.add, size: 24, color: theme.colorScheme.primary),
            onPressed: showAddDialog,
            tooltip: l10n.addReminder,
          ),
      ],
    );

    final subtitle = widget.subtitle != null
        ? Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              widget.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
            ),
          )
        : null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, ?subtitle]),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: rows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final ReminderTask task;
  final bool editable;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _TaskRow({
    required this.task,
    required this.editable,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = Utils.reminderTimeStr(task);
    final nameColor = theme.colorScheme.onSurface;
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: task.done,
              onChanged: editable ? (_) => onToggle() : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),
          Expanded(
            child: Text(
              task.name.isEmpty ? l10n.unnamedTask : task.name,
              style: TextStyle(
                fontSize: 14,
                decoration: task.done ? TextDecoration.lineThrough : null,
                color: nameColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            task.repeat != ReminderTask.repeatOnce ? Icons.repeat : Icons.schedule,
            size: 11,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(width: 2),
          Text(timeStr, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(100))),
          if (editable) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.primary),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ],
      ),
    );
  }
}
