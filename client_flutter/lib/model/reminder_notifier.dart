import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/config/language_manager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/utils.dart';

/// Schedules local notifications for reminder tasks.
///
/// Strategy:
/// - Collect every task's upcoming occurrences, sort them by time.
/// - Schedule the nearest [_preScheduleCount] occurrences that fall within
///   [_scheduleWindow] (one month).
/// - If no occurrence falls inside the window, schedule the single nearest
///   upcoming occurrence across all tasks.
/// - Each scheduled notification is a one-shot system alarm; the OS fires it
///   at the scheduled time even when the app is in the background or killed.
/// - On app start, foreground return, or any reminder-tree change, all
///   scheduled notifications are cancelled and re-scheduled from scratch.
class ReminderNotifier with WidgetsBindingObserver {
  static final ReminderNotifier instance = ReminderNotifier._();
  ReminderNotifier._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<ReminderEvent>? _reminderSub;

  /// Emits the record uuid when the user taps a reminder notification.
  /// Listeners (e.g. the app shell) use it to open the corresponding note.
  final ValueNotifier<String?> notificationTapNotifier = ValueNotifier<String?>(null);

  /// Max notifications scheduled app-wide.
  static const int _preScheduleCount = 5;

  /// Max occurrences collected per task when scanning (covers a one-month
  /// window even for daily-repeating tasks).
  static const int _perTaskCollectLimit = 31;

  /// Only schedule occurrences within this window.
  static const Duration _scheduleWindow = Duration(days: 30);

  /// Upper bound (ms since epoch) for scheduled notifications. Windows uses a
  /// 32-bit signed Unix timestamp internally, so anything past 2038-01-19
  /// overflows and crashes the process. Stop scheduling before that.
  static const int _maxScheduleMs = 2147483647000;

  static const String _channelId = 'reminder';

  /// Stable GUID used for the Windows notification COM server registration.
  static const String _windowsGuid = '1B6FE65B-3B6F-4A2E-8E3A-2C4F5D6E7A8B';

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      AppLogger.w('ReminderNotifier', "failed to set local timezone: $e, fallback to UTC");
    }

    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final linux = LinuxInitializationSettings(
      defaultActionName: l10n.reminderChannel,
      defaultIcon: AssetsLinuxIcon('assets/icon/app_icon.png'),
    );
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final iconFile = File('$exeDir/data/flutter_assets/assets/icon/app_icon.png');
    final windows = WindowsInitializationSettings(
      appName: AppEnv.appTitle,
      appUserModelId: AppEnv.packageName,
      guid: _windowsGuid,
      iconPath: Uri.file(iconFile.path, windows: true).toString(),
    );
    final settings = InitializationSettings(android: android, iOS: ios, linux: linux, windows: windows);
    try {
      await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: _onNotificationResponse);
    } catch (e) {
      AppLogger.e('ReminderNotifier', "initialize failed: $e");
      return;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _reminderSub = Repository.get().reminderTree.onEvent.listen(_onTreeChanged);
    WidgetsBinding.instance.addObserver(this);

    _initialized = true;
    AppLogger.d('ReminderNotifier', "initialized");

    // One full pass at startup.
    unawaited(rescheduleAll());
  }

  /// Re-scan and reschedule from scratch when the app returns to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      unawaited(rescheduleAll());
    }
  }

  /// Any tree change may alter which occurrences should be scheduled, so we
  /// recompute everything from scratch.
  void _onTreeChanged(ReminderEvent _) {
    unawaited(rescheduleAll());
  }

  /// Compute the next occurrence timestamp (ms since epoch) for [task]
  /// strictly after [fromMs], or null if there is no future occurrence.
  int? _nextOccurrenceMs(ReminderTask task, int fromMs) {
    if (task.time <= 0) return null;
    final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final next = nextReminderOccurrence(task, from);
    return next?.millisecondsSinceEpoch;
  }

  /// Collect upcoming occurrences for [entry]'s task, up to
  /// [_perTaskCollectLimit] entries.
  List<(ReminderEntry, int)> _collectOccurrences(ReminderEntry entry, int nowMs) {
    final result = <(ReminderEntry, int)>[];
    final task = entry.task;
    if (task.done || task.time <= 0) return result;
    var fromMs = nowMs;
    for (var i = 0; i < _perTaskCollectLimit; i++) {
      final occurrenceMs = _nextOccurrenceMs(task, fromMs);
      if (occurrenceMs == null) break;
      if (occurrenceMs > _maxScheduleMs) break;
      result.add((entry, occurrenceMs));
      fromMs = occurrenceMs;
    }
    return result;
  }

  /// Cancel everything, then schedule the globally nearest upcoming
  /// occurrences. Rules:
  /// - At most [_preScheduleCount] notifications app-wide.
  /// - Only occurrences within [_scheduleWindow] (one month) are picked.
  /// - If nothing falls inside the window, schedule the single nearest
  ///   upcoming occurrence across all tasks.
  /// - Nothing past [_maxScheduleMs] is scheduled (2038 overflow guard).
  Future<void> rescheduleAll() async {
    await _plugin.cancelAll();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowEndMs = nowMs + _scheduleWindow.inMilliseconds;

    final all = <(ReminderEntry, int)>[];
    for (final entry in Repository.get().reminderTree.entries) {
      all.addAll(_collectOccurrences(entry, nowMs));
    }
    all.sort((a, b) => a.$2.compareTo(b.$2));

    final inWindow = all.where((e) => e.$2 <= windowEndMs).toList();
    final toSchedule = inWindow.isNotEmpty ? inWindow.take(_preScheduleCount).toList() : all.take(1).toList();

    for (var i = 0; i < toSchedule.length; i++) {
      final entry = toSchedule[i].$1;
      final task = entry.task;
      final occurrenceMs = toSchedule[i].$2;
      final id = _notificationId('slot_$i');
      final title = task.name.isEmpty ? l10n.reminder : task.name;
      final body = _buildBody(task, entry.recordPath, entry.recordName);
      final detail = _notificationDetails();
      final payload = jsonEncode({'recordUuid': entry.recordUuid});
      AppLogger.d('ReminderNotifier', "scheduling slot $i task ${task.id} at $occurrenceMs");
      try {
        final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, occurrenceMs);
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTime,
          notificationDetails: detail,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
        AppLogger.d('ReminderNotifier', "scheduled slot $i");
      } catch (e) {
        AppLogger.e('ReminderNotifier', "schedule failed for slot $i: $e");
      }
    }
    if (toSchedule.isNotEmpty) {
      AppLogger.i('ReminderNotifier', "rescheduled ${toSchedule.length} notifications");
    }
  }

  /// Called when the user taps a notification. Parses the payload and emits
  /// the target record uuid via [notificationTapNotifier].
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final recordUuid = map['recordUuid'] as String?;
      if (recordUuid != null && recordUuid.isNotEmpty) {
        AppLogger.d('ReminderNotifier', "notification tapped, opening $recordUuid");
        notificationTapNotifier.value = recordUuid;
      }
    } catch (e) {
      AppLogger.e('ReminderNotifier', "failed to parse notification payload: $e");
    }
  }

  /// Stable positive int32 id from a string (FNV-1a).
  int _notificationId(String s) {
    var hash = 2166136261;
    for (final c in s.codeUnits) {
      hash = ((hash ^ c) * 16777619) & 0xFFFFFFFF;
    }
    return (hash % 0x7FFFFFFF) + 1;
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.reminderChannel,
        channelDescription: l10n.reminderChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
  }

  String _buildBody(ReminderTask task, String path, String name) {
    // Note location (e.g. "/work/meeting") plus the same time formatting as
    // the calendar task item, e.g. "周一 08:00" or "2026-10-12 14:30".
    return '${l10n.reminderDueBody} \n$path$name \n${Utils.reminderTimeStr(task)}';
  }

}
