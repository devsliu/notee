import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/reminder_tree.dart';

/// Common interface for the per-mode date/time editor states. The parent
/// editor calls [validateAndGet] on save: on success it returns the encoded
/// `(date, time)` ints; on failure it highlights the invalid fields internally
/// and returns null.
abstract class DateTimeEditorState<T extends StatefulWidget> extends State<T> {
  (int date, int time)? validateAndGet();

  /// Whether the entered date should be treated as a lunar date.
  /// Only monthly/yearly editors override this.
  bool get isLunar => false;
}

// Field keys used for error highlighting inside the editors.
const String _fYear = 'year';
const String _fMonth = 'month';
const String _fDay = 'day';
const String _fHour = 'hour';
const String _fMinute = 'minute';
const String _fWeekdays = 'weekdays';

/// Dialog editor for a single reminder task. Extracted from ReminderPanel so
/// it can be reused by the calendar page.
class ReminderTaskEditor extends StatefulWidget {
  final ReminderTask task;
  final ValueChanged<ReminderTask> onSaved;

  /// Optional subtitle shown under the dialog title, e.g. the record path/name.
  final String? subtitle;

  const ReminderTaskEditor({super.key, required this.task, required this.onSaved, this.subtitle});

  @override
  State<ReminderTaskEditor> createState() => ReminderTaskEditorState();
}

class ReminderTaskEditorState extends State<ReminderTaskEditor> {
  late final TextEditingController _nameCtrl;
  late int _repeat;

  final _onceKey = GlobalKey<OnceEditorState>();
  final _weeklyKey = GlobalKey<WeeklyEditorState>();
  final _monthlyKey = GlobalKey<MonthlyEditorState>();
  final _yearlyKey = GlobalKey<YearlyEditorState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.task.name);
    _repeat = widget.task.repeat;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  (int, int)? _currentEditorValues() {
    switch (_repeat) {
      case ReminderTask.repeatOnce:
        return _onceKey.currentState?.validateAndGet();
      case ReminderTask.repeatWeekly:
        return _weeklyKey.currentState?.validateAndGet();
      case ReminderTask.repeatMonthly:
        return _monthlyKey.currentState?.validateAndGet();
      case ReminderTask.repeatYearly:
        return _yearlyKey.currentState?.validateAndGet();
      default:
        return null;
    }
  }

  void _save() {
    final values = _currentEditorValues();
    if (values == null) return;

    final isLunar = switch (_repeat) {
      ReminderTask.repeatMonthly => _monthlyKey.currentState?.isLunar ?? false,
      ReminderTask.repeatYearly => _yearlyKey.currentState?.isLunar ?? false,
      _ => false,
    };

    widget.onSaved(
      ReminderTask(
        id: widget.task.id,
        name: _nameCtrl.text.trim(),
        date: values.$1,
        time: values.$2,
        repeat: _repeat,
        done: widget.task.done,
        isLunar: isLunar,
      ),
    );
  }

  Widget _buildDateTimeEditor() {
    switch (_repeat) {
      case ReminderTask.repeatOnce:
        return OnceEditor(key: _onceKey, task: widget.task);
      case ReminderTask.repeatWeekly:
        return WeeklyEditor(key: _weeklyKey, task: widget.task);
      case ReminderTask.repeatMonthly:
        return MonthlyEditor(key: _monthlyKey, task: widget.task);
      case ReminderTask.repeatYearly:
        return YearlyEditor(key: _yearlyKey, task: widget.task);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeatLabels = [l10n.repeatOnce, l10n.repeatWeekly, l10n.repeatMonthly, l10n.repeatYearly];
    final repeatValues = [
      ReminderTask.repeatOnce,
      ReminderTask.repeatWeekly,
      ReminderTask.repeatMonthly,
      ReminderTask.repeatYearly,
    ];

    double screenWidth = MediaQuery.of(context).size.width;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.editReminder),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120))),
          ],
        ],
      ),
      content: SizedBox(
        width: math.min(450, screenWidth * 0.85),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: const OutlineInputBorder(),
                  hintText: l10n.taskName,
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildDateTimeEditor(),
              const SizedBox(height: 12),
              Text(l10n.repeat, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: List.generate(repeatValues.length, (i) {
                  final val = repeatValues[i];
                  final selected = _repeat == val;
                  return ChoiceChip(
                    label: Text(repeatLabels[i], style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _repeat = val);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        TextButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// Show the task editor dialog and return the saved task, or null if cancelled.
Future<ReminderTask?> showReminderTaskEditor(
  BuildContext context, {
  required ReminderTask task,
  String? subtitle,
}) async {
  ReminderTask? result;
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => ReminderTaskEditor(
      task: task,
      subtitle: subtitle,
      onSaved: (updated) {
        result = updated;
        Navigator.of(ctx).pop();
      },
    ),
  );
  return result;
}

// ---------------------------------------------------------------------------
// Date/time editor widgets (one per repeat mode)
// ---------------------------------------------------------------------------

class DateTimeField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final double width;
  final bool error;
  final VoidCallback? onChanged;

  const DateTimeField({
    super.key,
    required this.controller,
    required this.hint,
    required this.width,
    this.error = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderSide: error ? BorderSide(color: errorColor, width: 1.5) : BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderSide: error ? BorderSide(color: errorColor, width: 1.5) : const BorderSide(),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: error ? BorderSide(color: errorColor, width: 1.5) : BorderSide(color: primary, width: 1.5),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: error ? errorColor.withAlpha(150) : null),
        ),
        style: TextStyle(fontSize: 14, color: error ? errorColor : null),
      ),
    );
  }
}

class TimeFields extends StatelessWidget {
  final TextEditingController hourCtrl;
  final TextEditingController minuteCtrl;
  final bool hourError;
  final bool minuteError;
  final VoidCallback? onChanged;

  const TimeFields({
    super.key,
    required this.hourCtrl,
    required this.minuteCtrl,
    required this.hourError,
    required this.minuteError,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DateTimeField(controller: hourCtrl, hint: l10n.unitHour, width: 48, error: hourError, onChanged: onChanged),
        const SizedBox(width: 4),
        const Text(':', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        DateTimeField(
          controller: minuteCtrl,
          hint: l10n.unitMinute,
          width: 48,
          error: minuteError,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// once: 年-月-日 + 时:分
class OnceEditor extends StatefulWidget {
  final ReminderTask task;
  const OnceEditor({super.key, required this.task});

  @override
  State<OnceEditor> createState() => OnceEditorState();
}

class OnceEditorState extends DateTimeEditorState<OnceEditor> {
  late final TextEditingController _yearCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _invalid = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 3));
    final hasTime = widget.task.time > 0;
    final d = widget.task.onceDate;
    final hasDate = widget.task.date > 0;
    _yearCtrl = TextEditingController(text: '${hasDate ? d.$1 : now.year}');
    _monthCtrl = TextEditingController(text: '${hasDate ? d.$2 : now.month}');
    _dayCtrl = TextEditingController(text: '${hasDate ? d.$3 : now.day}');
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null) invalid.add(_fYear);
    final month = int.tryParse(_monthCtrl.text.trim());
    if (month == null || month < 1 || month > 12) invalid.add(_fMonth);
    final day = int.tryParse(_dayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) {
      invalid.add(_fDay);
    } else if (year != null && month != null) {
      final dim = DateTime(year, month + 1, 0).day;
      if (day > dim) invalid.add(_fDay);
    }
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (ReminderTask.encodeOnceDate(year!, month!, day!), ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DateTimeField(
          controller: _yearCtrl,
          hint: l10n.unitYear,
          width: 64,
          error: _invalid.contains(_fYear),
          onChanged: _onFieldChanged,
        ),
        const Text('-', style: TextStyle(fontSize: 14)),
        DateTimeField(
          controller: _monthCtrl,
          hint: l10n.unitMonth,
          width: 48,
          error: _invalid.contains(_fMonth),
          onChanged: _onFieldChanged,
        ),
        const Text('-', style: TextStyle(fontSize: 14)),
        DateTimeField(
          controller: _dayCtrl,
          hint: l10n.unitDay,
          width: 48,
          error: _invalid.contains(_fDay),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 8),
        TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }
}

/// weekly: 周一~周日 chips, then 时:分 below
class WeeklyEditor extends StatefulWidget {
  final ReminderTask task;
  const WeeklyEditor({super.key, required this.task});

  @override
  State<WeeklyEditor> createState() => WeeklyEditorState();
}

class WeeklyEditorState extends DateTimeEditorState<WeeklyEditor> {
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  late final List<int> _weekdays;
  final _invalid = <String>{};
  late final List<String> _labels = l10n.weekdays.split('|');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 3));
    final hasTime = widget.task.time > 0;
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
    _weekdays = [...widget.task.weekdaySet];
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  void _toggleWeekday(int day) {
    setState(() {
      _invalid.remove(_fWeekdays);
      if (_weekdays.contains(day)) {
        _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    if (_weekdays.isEmpty) invalid.add(_fWeekdays);
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (ReminderTask.encodeWeeklyDate([..._weekdays]), ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: List.generate(7, (i) {
            final day = i + 1;
            return ChoiceChip(
              label: Text(_labels[i], style: const TextStyle(fontSize: 12)),
              selected: _weekdays.contains(day),
              onSelected: (_) => _toggleWeekday(day),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }),
        ),
        if (_invalid.contains(_fWeekdays)) ...[
          const SizedBox(height: 4),
          Text(l10n.atLeastOneWeekday, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 10),
        TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }
}

/// monthly: 日 + 时:分
class MonthlyEditor extends StatefulWidget {
  final ReminderTask task;
  const MonthlyEditor({super.key, required this.task});

  @override
  State<MonthlyEditor> createState() => MonthlyEditorState();
}

class MonthlyEditorState extends DateTimeEditorState<MonthlyEditor> {
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _invalid = <String>{};
  late bool _isLunar;

  @override
  bool get isLunar => _isLunar;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 3));
    final hasTime = widget.task.time > 0;
    final day = widget.task.monthlyDay;
    final hasDate = widget.task.date > 0;
    _dayCtrl = TextEditingController(text: '${hasDate ? day : now.day}');
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
    _isLunar = widget.task.isLunar;
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    final day = int.tryParse(_dayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) invalid.add(_fDay);
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (day!, ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DateTimeField(
          controller: _dayCtrl,
          hint: l10n.unitDay,
          width: 48,
          error: _invalid.contains(_fDay),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        Text(l10n.unitDay, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 12),
        _LunarCheckbox(value: _isLunar, onChanged: (v) => setState(() => _isLunar = v)),
      ],
    );
  }
}

/// yearly: 月 日 + 时:分
class YearlyEditor extends StatefulWidget {
  final ReminderTask task;
  const YearlyEditor({super.key, required this.task});

  @override
  State<YearlyEditor> createState() => YearlyEditorState();
}

class YearlyEditorState extends DateTimeEditorState<YearlyEditor> {
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _invalid = <String>{};
  late bool _isLunar;

  @override
  bool get isLunar => _isLunar;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 3));
    final hasTime = widget.task.time > 0;
    final md = widget.task.yearlyMonthDay;
    final hasDate = widget.task.date > 0;
    _monthCtrl = TextEditingController(text: '${hasDate ? md.$1 : now.month}');
    _dayCtrl = TextEditingController(text: '${hasDate ? md.$2 : now.day}');
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
    _isLunar = widget.task.isLunar;
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    final month = int.tryParse(_monthCtrl.text.trim());
    if (month == null || month < 1 || month > 12) invalid.add(_fMonth);
    final day = int.tryParse(_dayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) {
      invalid.add(_fDay);
    } else if (month != null) {
      final dim = DateTime(2000, month + 1, 0).day;
      if (day > dim) invalid.add(_fDay);
    }
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (ReminderTask.encodeYearlyDate(month!, day!), ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DateTimeField(
          controller: _monthCtrl,
          hint: l10n.unitMonth,
          width: 48,
          error: _invalid.contains(_fMonth),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        Text(l10n.unitMonth, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        DateTimeField(
          controller: _dayCtrl,
          hint: l10n.unitDay,
          width: 48,
          error: _invalid.contains(_fDay),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        Text(l10n.unitDay, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 12),
        _LunarCheckbox(value: _isLunar, onChanged: (v) => setState(() => _isLunar = v)),
      ],
    );
  }
}

/// A compact checkbox row for toggling the lunar (Chinese calendar) option.
class _LunarCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _LunarCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),
          const SizedBox(width: 2),
          Text(l10n.lunar, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
