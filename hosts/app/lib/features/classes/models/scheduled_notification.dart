/// One row of `GET /classes/{id}/notifications/scheduled`.
///
/// Plain classes rather than freezed: the payload is read-only here — v1 has no
/// edit flow — so a generated copyWith would have no caller.
class ClassScheduleSlot {
  final int id;
  final int day;
  final int hour;
  final int minute;
  final String timezone;

  const ClassScheduleSlot({
    required this.id,
    required this.day,
    required this.hour,
    required this.minute,
    required this.timezone,
  });

  factory ClassScheduleSlot.fromJson(Map<String, dynamic> json) =>
      ClassScheduleSlot(
        id: (json['id'] as num).toInt(),
        day: (json['day'] as num).toInt(),
        hour: (json['hour'] as num).toInt(),
        minute: (json['minute'] as num).toInt(),
        timezone: (json['timezone'] ?? '') as String,
      );
}

/// What became of one slot's queued pushes, read back from the push queue.
class ScheduledNotificationDelivery {
  final int queued;
  final int sent;
  final int failed;
  final int dead;

  const ScheduledNotificationDelivery({
    this.queued = 0,
    this.sent = 0,
    this.failed = 0,
    this.dead = 0,
  });

  factory ScheduledNotificationDelivery.fromJson(Map<String, dynamic> json) =>
      ScheduledNotificationDelivery(
        queued: (json['queued'] as num?)?.toInt() ?? 0,
        sent: (json['sent'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
        dead: (json['dead'] as num?)?.toInt() ?? 0,
      );

  /// Deliveries that ended without a send after the retries.
  int get stillFailing => failed + dead;
}

class ScheduledNotificationRun {
  final String? runAt;
  final int? notificationId;
  final int studentCount;
  final int deviceCount;
  final int successCount;
  final int failureCount;
  final String? skippedReason;
  final ScheduledNotificationDelivery? delivery;

  const ScheduledNotificationRun({
    this.runAt,
    this.notificationId,
    required this.studentCount,
    required this.deviceCount,
    required this.successCount,
    required this.failureCount,
    this.skippedReason,
    this.delivery,
  });

  factory ScheduledNotificationRun.fromJson(Map<String, dynamic> json) =>
      ScheduledNotificationRun(
        runAt: json['run_at'] as String?,
        notificationId: (json['notification_id'] as num?)?.toInt(),
        studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
        deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
        successCount: (json['success_count'] as num?)?.toInt() ?? 0,
        failureCount: (json['failure_count'] as num?)?.toInt() ?? 0,
        skippedReason: json['skipped_reason'] as String?,
        delivery: json['delivery'] is Map<String, dynamic>
            ? ScheduledNotificationDelivery.fromJson(
                json['delivery'] as Map<String, dynamic>,
              )
            : null,
      );
}

class ClassScheduledNotification {
  final int id;

  /// `ONCE`, `WEEKLY` or `REMINDER`.
  final String kind;
  final String title;
  final String body;
  final String? actionLink;

  /// `active` or `done`.
  final String status;

  /// The member token of the creator (users.token).
  final int createdBy;
  final String? creatorName;
  final String? createdAt;

  /// The next fire, already in the schedule's timezone, ISO 8601.
  final String? nextRun;

  /// ONCE only: the wall-clock date and time the sender chose, ISO 8601 with
  /// no offset. Read it in [timezone].
  final String? sendAt;

  /// WEEKLY only: ISO weekdays (1 = Monday).
  final List<int> weekdays;
  final String? sendTime;
  final String? timezone;

  /// REMINDER only.
  final int? classScheduleId;
  final int? offsetMinutes;
  final bool repeatWeekly;
  final ClassScheduleSlot? schedule;

  final ScheduledNotificationRun? lastRun;

  const ClassScheduledNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.actionLink,
    required this.status,
    required this.createdBy,
    this.creatorName,
    this.createdAt,
    this.nextRun,
    this.sendAt,
    this.weekdays = const [],
    this.sendTime,
    this.timezone,
    this.classScheduleId,
    this.offsetMinutes,
    this.repeatWeekly = false,
    this.schedule,
    this.lastRun,
  });

  factory ClassScheduledNotification.fromJson(Map<String, dynamic> json) {
    final schedule = json['schedule'];
    final lastRun = json['last_run'];
    return ClassScheduledNotification(
      id: (json['id'] as num).toInt(),
      kind: (json['kind'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      actionLink: json['action_link'] as String?,
      status: (json['status'] ?? '') as String,
      createdBy: (json['created_by'] as num?)?.toInt() ?? 0,
      creatorName: json['creator_name'] as String?,
      createdAt: json['created_at'] as String?,
      nextRun: json['next_run'] as String?,
      sendAt: json['send_at'] as String?,
      weekdays: ((json['weekdays'] as List?) ?? const [])
          .map((d) => (d as num).toInt())
          .toList(),
      sendTime: json['send_time'] as String?,
      timezone: json['timezone'] as String?,
      classScheduleId: (json['class_schedule_id'] as num?)?.toInt(),
      offsetMinutes: (json['offset_minutes'] as num?)?.toInt(),
      repeatWeekly: (json['repeat_weekly'] as bool?) ?? false,
      schedule: schedule is Map<String, dynamic>
          ? ClassScheduleSlot.fromJson(schedule)
          : null,
      lastRun: lastRun is Map<String, dynamic>
          ? ScheduledNotificationRun.fromJson(lastRun)
          : null,
    );
  }

  bool get isActive => status == 'active';
}

class ScheduledNotificationsPayload {
  final List<ClassScheduledNotification> items;

  /// The class's live schedule slots, for the reminder form.
  final List<ClassScheduleSlot> schedules;

  const ScheduledNotificationsPayload({
    this.items = const [],
    this.schedules = const [],
  });

  factory ScheduledNotificationsPayload.fromJson(Map<String, dynamic> json) =>
      ScheduledNotificationsPayload(
        items: ((json['items'] as List?) ?? const [])
            .map(
              (i) => ClassScheduledNotification.fromJson(
                i as Map<String, dynamic>,
              ),
            )
            .toList(),
        schedules: ((json['schedules'] as List?) ?? const [])
            .map((s) => ClassScheduleSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
