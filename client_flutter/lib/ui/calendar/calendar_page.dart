import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:notee/ui/desktop/desktop_tabs_page.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/calendar/reminder_task_editor.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/utils/lunar.dart';

class CalendarPage extends StatefulWidget {
  final bool showAppBar;
  final ValueCallback<BuildContext> closeCallback;

  const CalendarPage({
    super.key,
    this.showAppBar = true,
    this.closeCallback = Navigator.pop,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> implements DesktopTabPageState {
  List<ReminderEntry> _entries = [];
  bool _loading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  static const int _modeCalendar = 0;
  static const int _modeList = 1;
  int _viewMode = _modeCalendar;
  StreamSubscription<ReminderEvent>? _reminderSub;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _load();
    _reminderSub = Repository.get().reminderTree.onEvent.listen((_) => _load());
  }

  @override
  void dispose() {
    _reminderSub?.cancel();
    super.dispose();
  }

  @override
  void setInForeground(bool value) {
    // No editor lifecycle to manage; refresh on focus so new reminders appear.
    if (value) _load();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _entries = Repository.get().reminderTree.entries;
      _loading = false;
    });
  }

  List<ReminderEntry> _entriesForDay(DateTime day) {
    return _entries.where((e) => reminderOccursOnDay(e.task, day)).toList();
  }

  void _openRecord(String uuid) {
    AppNavigator.of(context).navigate('${AppNavigator.uriRecord}$uuid');
  }

  /// Load the task list of the record that owns [entry], mutate via [update],
  /// then persist and refresh the calendar view.
  Future<void> _mutateEntryTask(ReminderEntry entry, void Function(List<ReminderTask>) update) async {
    final repo = Repository.get();
    final record = repo.recordTree.findRecord(entry.recordUuid);
    if (record == null) return;
    final tasks = ReminderTask.fromJsonString(record.local.reminder);
    update(tasks);
    final json = ReminderTask.toJsonString(tasks);
    await repo.editRecord(entry.recordUuid, false, DateTime.now().millisecondsSinceEpoch, reminder: json);
    if (mounted) _load();
  }

  void _toggleDone(ReminderEntry entry) {
    _mutateEntryTask(entry, (tasks) {
      final idx = tasks.indexWhere((t) => t.id == entry.task.id);
      if (idx < 0) return;
      final old = tasks[idx];
      tasks[idx] = old.copyWith(done: !old.done);
    });
  }

  Future<void> _editEntry(ReminderEntry entry) async {
    final updated = await showReminderTaskEditor(
      context,
      task: entry.task,
      subtitle: '${entry.recordPath}${entry.recordName}',
    );
    if (updated == null || !mounted) return;
    _mutateEntryTask(entry, (tasks) {
      final idx = tasks.indexWhere((t) => t.id == updated.id);
      if (idx >= 0) tasks[idx] = updated;
    });
  }

  Future<void> _deleteEntry(ReminderEntry entry) async {
    final repo = Repository.get();
    // When the record has only this task and no content (no work file,
    // remoteMd5 empty), delete the whole record instead of leaving
    // an empty task-holder behind.
    final tasks = repo.reminderTree.tasksForRecord(entry.recordUuid);
    final isOnlyTask = tasks.length == 1 && tasks.first.id == entry.task.id;
    final record = isOnlyTask ? repo.recordTree.findRecord(entry.recordUuid) : null;
    if (record != null &&
        record.local.remoteMd5.isEmpty &&
        !(repo.fileStore?.isWorkFileExist(entry.recordUuid) ?? false)) {
      await repo.deleteRecord(entry.recordUuid);
      return;
    }
    _mutateEntryTask(entry, (tasks) {
      tasks.removeWhere((t) => t.id == entry.task.id);
    });
  }

  void _onLongClickDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
    _createTask(day: day);
  }

  Future<void> _createTask({DateTime? day}) async {
    final task = ReminderTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      date: day != null ? ReminderTask.encodeOnceDate(day.year, day.month, day.day) : 0,
    );
    final saved = await showReminderTaskEditor(context, task: task);
    if (saved == null || !mounted || saved.name.isEmpty) return;
    final repo = Repository.get();
    await repo.createRecord('/#calendar/', '##reminder##', true, 0, reminder: ReminderTask.toJsonString([saved]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segmented = _buildSegmentedControl(context);
    if (!widget.showAppBar) {
      return SizedBox.expand(
        child: Material(
          color: theme.colorScheme.surface,
          child: Stack(
            children: [
              _buildBody(context),
              Positioned(right: 16, bottom: 12, child: segmented),
              if (_viewMode == _modeList)
                Positioned(
                  right: 16,
                  bottom: 56,
                  child: FloatingActionButton.small(onPressed: _createTask, child: const Icon(Icons.add)),
                ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: createAppBar(
        title: l10n.calendar,
        leading: IconButton(onPressed: () => widget.closeCallback(context), icon: Icon(Icons.arrow_back)),
        titleSpacing: 0,
        actions: [
          segmented,
          SizedBox(width: AppEnv.pageHorizontalPadding),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    final theme = Theme.of(context);
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Color.lerp(theme.colorScheme.surface, theme.colorScheme.onSurface, 0.20);
          }
          if (states.contains(WidgetState.pressed)) {
            return Color.lerp(theme.colorScheme.surface, theme.colorScheme.onSurface, 0.10);
          }
          return theme.colorScheme.surface;
        }),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 0)),
      ),
      segments: [
        ButtonSegment(value: _modeCalendar, icon: const Icon(Icons.calendar_month, size: 18)),
        ButtonSegment(value: _modeList, icon: const Icon(Icons.list, size: 18)),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) => setState(() => _viewMode = set.first),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_viewMode == _modeCalendar) return _buildCalendarView(context);
    return _buildListView(context);
  }

  Widget _buildCalendarView(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEntries = _selectedDay != null ? _entriesForDay(_selectedDay!) : <ReminderEntry>[];

    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar<ReminderEntry>(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            rowHeight: 80,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) setState(() => _calendarFormat = format);
            },
            onPageChanged: (focused) => _focusedDay = focused,
            eventLoader: (day) => _entriesForDay(day),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focused) => _buildDayCell(context, day),
              todayBuilder: (context, day, focused) => _buildDayCell(context, day, isToday: true),
              selectedBuilder: (context, day, focused) =>
                  _buildDayCell(context, day, selected: true, isToday: isSameDay(day, DateTime.now())),
              outsideBuilder: (context, day, focused) => _buildDayCell(context, day, isOutside: true),
              markerBuilder: (context, day, events) => const SizedBox.shrink(),
            ),
          ),
          const Divider(height: 1),
          selectedEntries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      l10n.noRemindersToday,
                      style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedEntries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(100)),
                  itemBuilder: (context, i) => _buildEntryTile(context, selectedEntries[i]),
                ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    bool selected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final theme = Theme.of(context);
    final entries = _entriesForDay(day);
    final text = entries.isEmpty ? '' : (entries.first.task.name.isEmpty ? l10n.reminder : entries.first.task.name);

    final dayColor = isOutside
        ? theme.colorScheme.onSurface.withAlpha(80)
        : selected
        ? Colors.white
        : isToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    final lunar = solarToLunar(day);
    final lunarColor = lunar.solarTerm != null
        ? (selected ? Colors.white : theme.colorScheme.error)
        : dayColor.withAlpha(selected ? 200 : 110);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: isOutside ? null : () => _onLongClickDay(day),
      onSecondaryTap: isOutside ? null : () => _onLongClickDay(day),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : isToday
              ? theme.colorScheme.primary.withAlpha(15)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isToday ? l10n.today : '${day.day}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dayColor,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                lunar.cellText,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: lunarColor,
                  fontSize: 10,
                  fontWeight: lunar.solarTerm != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    style: TextStyle(color: dayColor, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Text(
                    l10n.noReminderTasks,
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
                  ),
                )
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(100)),
                  itemBuilder: (context, i) => _buildEntryTile(context, _entries[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(BuildContext context, ReminderEntry entry) {
    final task = entry.task;
    final theme = Theme.of(context);
    final timeStr = Utils.reminderTimeStr(task);
    final nameColor = task.done ? theme.colorScheme.onSurface.withAlpha(120) : theme.colorScheme.onSurface;
    final shrink = Utils.isDesktop();
    return ListTile(
      dense: shrink,
      visualDensity: shrink ? const VisualDensity(vertical: -4) : null,
      contentPadding: const EdgeInsets.only(left: AppEnv.pageHorizontalPadding, right: 8),
      onTap: () => _openRecord(entry.recordUuid),
      title: Text(
        task.name.isEmpty ? l10n.unnamedTask : task.name,
        style: TextStyle(decoration: task.done ? TextDecoration.lineThrough : null, color: nameColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${entry.recordPath}${entry.recordName}  ·  $timeStr',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(180)),
      ),
      trailing: PopupMenuButton<String>(
          popUpAnimationStyle: AnimationStyle.noAnimation,
        icon: Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
        tooltip: l10n.edit,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        splashRadius: 18,
        onSelected: (v) {
          switch (v) {
            case 'toggle':
              _toggleDone(entry);
              break;
            case 'edit':
              _editEntry(entry);
              break;
            case 'delete':
              _deleteEntry(entry);
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(task.done ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
                const SizedBox(width: 8),
                Text(task.done ? l10n.markUnfinished : l10n.markFinished),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [const Icon(Icons.edit_outlined, size: 18), const SizedBox(width: 8), Text(l10n.edit)],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(l10n.delete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
