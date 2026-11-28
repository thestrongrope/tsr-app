import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/classes/models/class_model.dart';
import '../../features/classes/models/class_schedule.dart';
import '../../features/calendar/calendar_models.dart';
import 'notification_service.dart';

/// Professional notification messages for class reminders and conduction reporting.
class _ReminderMessages {
  static final _random = Random();

  // ── Class Reminder (before class) ──────────────────────────────────────

  static const _classReminderBodies = [
    'Your class {name} starts in {mins} minutes.',
    'Reminder: {name} is scheduled to begin in {mins} minutes.',
    '{name} will commence in {mins} minutes. Please be prepared.',
  ];

  // ── Conduction Reminder (after class for teacher) ──────────────────────

  static const _conductionReminderBodies = [
    'Please record attendance and submit the conduction report for {name}.',
    'Reminder to submit your conduction report for {name}.',
    '{name} session concluded. Tap here to record your conduction report.',
  ];

  static String _displayName(String code, String name) {
    if (code.isNotEmpty && name.isNotEmpty && code != name) {
      return '$code ($name)';
    }
    return code.isNotEmpty ? code : name;
  }

  /// Class reminder title
  static String classReminderTitle(String code, String name) {
    final display = code.isNotEmpty ? code : name;
    return 'Class Reminder: $display';
  }

  /// Class reminder body with class name and lead time
  static String classReminderBody(String code, String name, int leadMinutes) {
    final template =
        _classReminderBodies[_random.nextInt(_classReminderBodies.length)];
    return template
        .replaceAll('{name}', _displayName(code, name))
        .replaceAll('{mins}', leadMinutes.toString());
  }

  /// Conduction reminder title
  static String conductionReminderTitle(String code, String name) {
    final display = code.isNotEmpty ? code : name;
    return 'Conduction Report: $display';
  }

  /// Conduction reminder body
  static String conductionReminderBody(
    String code,
    String name,
    int delayMinutes,
  ) {
    final template =
        _conductionReminderBodies[_random.nextInt(
          _conductionReminderBodies.length,
        )];
    return template
        .replaceAll('{name}', _displayName(code, name))
        .replaceAll('{mins}', delayMinutes.toString());
  }
}

/// Notification type discriminator used in notification IDs and payloads.
enum _NotifType {
  classReminder(0),
  conductionReminder(1);

  const _NotifType(this.value);
  final int value;
}

/// Service that schedules weekly recurring local notifications based on each
/// class's [ClassSchedule] entries.
///
/// Notifications are scheduled via the Android `AlarmManager` / iOS
/// `UNNotificationRequest` through `flutter_local_notifications`, so they fire
/// even when the app is killed.
///
/// **Lifecycle**: Call [rescheduleAll] after login, class list refresh, or
/// settings change. Call [cancelAll] on logout.
class ScheduledNotificationService {
  ScheduledNotificationService._();
  static final ScheduledNotificationService instance =
      ScheduledNotificationService._();

  FlutterLocalNotificationsPlugin? _plugin;
  StudentCalendar? _eventCalendar;
  Future<void> _eventWork = Future<void>.value();
  final eventDropped = ValueNotifier<int>(0);

  /// Android channel for class reminders (before class).
  static const _classReminderChannel = AndroidNotificationChannel(
    'class_reminders',
    'Class Reminders',
    description: 'Reminds you before your scheduled classes start.',
    importance: Importance.high,
  );

  /// Android channel for conduction reminders (after class, teacher & class admin).
  static const _conductionReminderChannel = AndroidNotificationChannel(
    'class_conduction_reminders',
    'Conduction Reminders',
    description:
        'Reminds teachers and class admins to submit conduction reports after class.',
    importance: Importance.high,
  );

  /// Must be called once during app init. Pass the same plugin instance used
  /// by [NotificationService] to avoid double-initialization.
  Future<void> initialize(FlutterLocalNotificationsPlugin plugin) async {
    _plugin = plugin;
    _eventCalendar = null;

    // Create the dedicated Android channels.
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_classReminderChannel);
    await androidPlugin?.createNotificationChannel(_conductionReminderChannel);

    debugPrint('✅ ScheduledNotificationService initialized');
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Cancel every scheduled class/conduction reminder and re-schedule from
  /// scratch using the latest [classes] list and user settings.
  ///
  /// [classReminderEnabled] / [conductionReminderEnabled]: read from the
  /// settings provider before calling this method.
  /// Returns how many class and conduction reminders it scheduled (#395).
  Future<({int classReminders, int conductionReminders})> rescheduleAll({
    required List<ClassModel> classes,
    required bool classReminderEnabled,
    required bool conductionReminderEnabled,
    required bool Function(ClassModel cls) remindsConduction,
    int classReminderLeadMinutes = 15,
    int conductionReminderDelayMinutes = 45,
  }) async {
    await cancelAll();

    if (!classReminderEnabled && !conductionReminderEnabled) {
      if (_eventCalendar != null) await scheduleEvents(_eventCalendar!);
      debugPrint('🔕 All class reminders disabled — nothing to schedule');
      return (classReminders: 0, conductionReminders: 0);
    }

    var classReminders = 0;
    var conductionReminders = 0;

    for (final cls in classes) {
      for (var i = 0; i < cls.schedules.length; i++) {
        final schedule = cls.schedules[i];

        // ── Class Reminder ──
        // Not for a class the user only manages: a super admin's list holds
        // every class, and the OS keeps only a few dozen pending alarms.
        if (classReminderEnabled && !cls.isManaging) {
          await _scheduleWeekly(
            id: _notificationId(cls.id, i, _NotifType.classReminder),
            channelId: _classReminderChannel.id,
            channelName: _classReminderChannel.name,
            title: _ReminderMessages.classReminderTitle(cls.code, cls.name),
            body: _ReminderMessages.classReminderBody(
              cls.code,
              cls.name,
              classReminderLeadMinutes,
            ),
            schedule: schedule,
            offsetMinutes: -classReminderLeadMinutes,
            payloadType: 'class_reminder',
            classId: cls.id,
          );
          classReminders++;
        }

        // ── Conduction Reminder (see PermissionsPayload.remindsConduction) ──
        if (conductionReminderEnabled && remindsConduction(cls)) {
          await _scheduleWeekly(
            id: _notificationId(cls.id, i, _NotifType.conductionReminder),
            channelId: _conductionReminderChannel.id,
            channelName: _conductionReminderChannel.name,
            title: _ReminderMessages.conductionReminderTitle(
              cls.code,
              cls.name,
            ),
            body: _ReminderMessages.conductionReminderBody(
              cls.code,
              cls.name,
              conductionReminderDelayMinutes,
            ),
            schedule: schedule,
            offsetMinutes: conductionReminderDelayMinutes,
            payloadType: 'conduction_reminder',
            classId: cls.id,
          );
          conductionReminders++;
        }
      }
    }

    debugPrint(
      '🔔 Scheduled ${classReminders + conductionReminders} class notification(s)',
    );
    if (_eventCalendar != null) await scheduleEvents(_eventCalendar!);
    return (
      classReminders: classReminders,
      conductionReminders: conductionReminders,
    );
  }

  /// Cancel all scheduled class & conduction reminders.
  Future<void> cancelAll() async {
    final plugin = _plugin;
    if (plugin == null) return;

    final pending = await plugin.pendingNotificationRequests();
    int cancelled = 0;
    for (final req in pending) {
      // Only cancel our own notifications (IDs in the class-reminder range).
      if (_isClassNotificationId(req.id)) {
        await plugin.cancel(req.id);
        cancelled++;
      }
    }
    if (cancelled > 0) {
      debugPrint('🗑️ Cancelled $cancelled scheduled class notification(s)');
    }
  }

  /// Event alarm ids start here and run to the largest id Android accepts
  /// (2^31 - 1), so they sit above every class reminder id: those grow with
  /// the class id, 100_000 + classId * 1000, and stay below this up to class 999_000.
  static const _eventIdBase = 1000000000;

  static bool isEventNotificationId(int id) => id >= _eventIdBase;

  Future<void> cancelEvents() async {
    _eventCalendar = null;
    await _eventOperation(() async {
      await _cancelEventsNow();
      eventDropped.value = 0;
      return 0;
    });
  }

  Future<int> _eventOperation(Future<int> Function() operation) {
    final result = _eventWork.then((_) => operation());
    // The returned result reports the error to its caller; the queue must
    // still accept the next cancellation or retry after a platform failure.
    _eventWork = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> _cancelEventsNow() async {
    final plugin = _plugin;
    if (plugin == null) return;
    for (final item in await plugin.pendingNotificationRequests()) {
      if (isEventNotificationId(item.id)) await plugin.cancel(item.id);
    }
  }

  /// Reserve room for existing reminders and arm the nearest event alarms first.
  Future<int> scheduleEvents(StudentCalendar calendar) {
    _eventCalendar = calendar;
    return _eventOperation(() => _scheduleEventsNow(calendar));
  }

  Future<int> _scheduleEventsNow(StudentCalendar calendar) async {
    final plugin = _plugin;
    if (plugin == null) return 0;
    await _cancelEventsNow();
    final other = await plugin.pendingNotificationRequests();
    final plan = planEventAlarms(calendar, DateTime.now(), 60 - other.length);
    var id = _eventIdBase;
    for (final alarm in plan.alarms) {
      await plugin.zonedSchedule(
        id++,
        alarm.event.message,
        alarm.event.description ?? alarm.event.className,
        alarm.at,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_events',
            'Class Events',
            channelDescription:
                'Your personal alerts for class events and timetable slots.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode({
          'action_link':
              alarm.event.link ?? '/classes/${alarm.event.classId}/dashboard',
          'class_id': alarm.event.classId.toString(),
          notificationPayloadTitleKey: alarm.event.message,
          notificationPayloadBodyKey: alarm.event.description ?? '',
        }),
      );
    }
    eventDropped.value = plan.dropped;
    return plan.dropped;
  }

  /// Cancel reminders for a specific class only.
  Future<void> cancelForClass(int classId) async {
    final plugin = _plugin;
    if (plugin == null) return;

    final pending = await plugin.pendingNotificationRequests();
    for (final req in pending) {
      if (_classIdFromNotificationId(req.id) == classId) {
        await plugin.cancel(req.id);
      }
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Schedule a single weekly-repeating local notification.
  Future<void> _scheduleWeekly({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required ClassSchedule schedule,
    required int offsetMinutes,
    required String payloadType,
    required int classId,
  }) async {
    final plugin = _plugin;
    if (plugin == null) {
      debugPrint('⚠️ ScheduledNotificationService not initialized');
      return;
    }

    final scheduledTime = nextOccurrence(schedule, offsetMinutes);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelId == _classReminderChannel.id
          ? _classReminderChannel.description
          : _conductionReminderChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: jsonEncode({
        'type': payloadType,
        'class_id': classId.toString(),
        notificationPayloadTitleKey: title,
        notificationPayloadBodyKey: body,
      }),
    );
  }

  /// Resolve the location a schedule's wall-clock time is expressed in.
  ///
  /// `tz.local` is NOT usable here: `initializeTimeZones()` only loads the
  /// database, and the `timezone` package leaves `tz.local` as UTC until
  /// `setLocalLocation()` is called. Reading it would schedule a 19:00 IST
  /// class for 19:00 UTC — 00:30 the next morning.
  ///
  /// The server sends the zone per schedule (`api_schedule_spec`), so use it
  /// when present and fall back to the constant below otherwise.
  tz.Location _locationFor(ClassSchedule schedule) {
    final name = schedule.timezone;
    if (name != null && name.isNotEmpty) {
      try {
        return tz.getLocation(name);
      } catch (_) {
        // Unknown zone name on the wire — fall through to the default.
      }
    }
    return tz.getLocation(_defaultTimezone);
  }

  /// Fallback zone for the schedules that carry no `timezone` — 8 rows in
  /// production as of 2026-09-21.
  ///
  /// **Classes are not all in India.** 338 schedules are `Asia/Kolkata`, but 46
  /// are spread across ten other zones — `America/Chicago`, `Asia/Dubai`,
  /// `Africa/Dar_es_Salaam`, `Europe/London` and others — six of which observe
  /// DST. This constant is only the last resort for a NULL or unrecognised
  /// value; the per-schedule zone is what almost every class actually uses.
  static const _defaultTimezone = 'Asia/Kolkata';

  /// Compute the next `TZDateTime` for a [ClassSchedule] entry, adjusted by
  /// [offsetMinutes] (negative = before, positive = after the class start).
  ///
  /// Exposed for test: the DST and timezone handling below is the part of this
  /// service that can be wrong without anything visibly failing, and it cannot
  /// be reached through `rescheduleAll` without a platform plugin.
  ///
  /// [clock] overrides "now" and exists only so a test can stand either side of
  /// a DST transition; production never passes it.
  @visibleForTesting
  tz.TZDateTime nextOccurrence(
    ClassSchedule schedule,
    int offsetMinutes, {
    tz.TZDateTime? clock,
  }) {
    final location = _locationFor(schedule);
    final now = clock == null
        ? tz.TZDateTime.now(location)
        : tz.TZDateTime.from(clock, location);

    // Adjust to the correct day-of-week. `schedule.day` is already an ISO
    // weekday: the web admin writes 1 = Monday .. 7 = Sunday (the `weekdays`
    // list in web/edit_class.php), which is exactly Dart's
    // `DateTime.weekday` numbering, so it maps across unchanged. The zero
    // case is defensive only -- no row uses it -- and is kept so a legacy
    // 0 would mean Sunday rather than silently landing a day out.
    final targetWeekday = schedule.day == 0 ? 7 : schedule.day; // ISO weekday
    final dayShift = targetWeekday - now.weekday;

    // Reach the target date through the constructor's calendar fields, never
    // by adding a Duration. `TZDateTime.add` is absolute: crossing a DST
    // transition moves the wall clock by the offset change, so a 19:30 class
    // in America/Chicago would remind at 18:30 or 20:30 for half the year.
    // Building from y/m/d keeps the intended local time, and the constructor
    // normalises a day number that overflows the month.
    var candidate = _at(location, now, dayShift, schedule, offsetMinutes);

    // If that has already passed, take the same wall-clock slot next week --
    // again by calendar, for the same reason.
    if (!candidate.isAfter(now)) {
      candidate = _at(location, now, dayShift + 7, schedule, offsetMinutes);
    }

    return candidate;
  }

  /// The schedule's wall-clock slot [dayShift] days from [now], plus
  /// [offsetMinutes]. The offset stays a Duration deliberately: it is a lead or
  /// delay measured from the class start, not a wall-clock time of its own.
  tz.TZDateTime _at(
    tz.Location location,
    tz.TZDateTime now,
    int dayShift,
    ClassSchedule schedule,
    int offsetMinutes,
  ) {
    return tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day + dayShift,
      schedule.hour,
      schedule.minute,
    ).add(Duration(minutes: offsetMinutes));
  }

  // ── Notification ID scheme ──────────────────────────────────────────────
  //
  // Layout: classId * 1000 + scheduleIndex * 10 + notifType
  //
  // This allows up to 100 schedules per class and 10 notification types,
  // which is more than sufficient (classes rarely have > 3 schedules).
  //
  // We reserve the range 100_000 .. 999_999_999 for class notifications so
  // they don't collide with FCM-triggered notification hashCode IDs.

  static const _idBase = 100000;

  static int _notificationId(int classId, int scheduleIdx, _NotifType type) {
    return _idBase + classId * 1000 + scheduleIdx * 10 + type.value;
  }

  static bool _isClassNotificationId(int id) =>
      id >= _idBase && id < _eventIdBase;

  static int _classIdFromNotificationId(int id) {
    return ((id - _idBase) ~/ 1000);
  }
}
