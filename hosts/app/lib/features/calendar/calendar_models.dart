import 'package:timezone/timezone.dart' as tz;

const eventOffsets = [0, -5, -15, -30, -60, -1440, -2880];

String offsetLabel(int value) => switch (value) {
  0 => 'At event time',
  -1440 => '24 hours before',
  -2880 => '48 hours before',
  _ => '${value.abs()} minutes before',
};

Map<String, Object?> calendarMap(Object? value) =>
    Map<String, Object?>.from(value as Map);

class CalendarEvent {
  CalendarEvent(this.json);
  final Map<String, Object?> json;
  String get key => json['key'] as String;
  int get classId => (json['class_id'] as num).toInt();
  String get message => json['message'] as String;
  String? get description => json['description'] as String?;
  String? get link => json['action_link'] as String?;

  /// Empty when the server has no zone for a legacy timetable slot.
  String get timezone => json['timezone'] as String? ?? '';
  String get time => json['send_time'] as String;
  List<int> get weekdays => (json['weekdays'] as List).cast<int>();
  bool get editable => json['editable_by_me'] == true;
  bool get takeover => json['takeover'] == true;
  String get className => json['class_name'] as String? ?? 'Class $classId';
  String get cadence {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = weekdays
        .map((d) => d >= 1 && d <= 7 ? names[d - 1] : 'Day $d')
        .join(', ');
    return timezone.isEmpty ? '$days at $time' : '$days at $time · $timezone';
  }
}

class EventSetting {
  const EventSetting({
    this.offset = 0,
    this.muted = false,
    this.deleted = false,
  });
  final int offset;
  final bool muted;
  final bool deleted;
  factory EventSetting.fromJson(Map<String, Object?> json) => EventSetting(
    offset: (json['offset_minutes'] as num?)?.toInt() ?? 0,
    muted: json['muted'] == true,
    deleted: json['deleted'] == true,
  );
}

class StudentCalendar {
  StudentCalendar(this.json);
  final Map<String, Object?> json;
  List<CalendarEvent> get events {
    final result = <CalendarEvent>[];
    for (final raw in json['classes'] as List? ?? []) {
      final group = calendarMap(raw);
      for (final kind in ['events', 'slots']) {
        for (final rawEvent in group[kind] as List? ?? []) {
          final event = CalendarEvent(
            calendarMap(rawEvent)..['class_name'] = group['name'],
          );
          if (!setting(event.key).deleted) result.add(event);
        }
      }
    }
    return result;
  }

  EventSetting setting(String key) {
    final settings = calendarMap(json['settings'] ?? <String, Object?>{});
    final value = settings[key];
    return value == null
        ? const EventSetting()
        : EventSetting.fromJson(calendarMap(value));
  }
}

class EventAlarm {
  const EventAlarm(this.event, this.weekday, this.at);
  final CalendarEvent event;
  final int weekday;
  final tz.TZDateTime at;
}

/// Build the event instant in its stored zone, then apply an elapsed duration.
tz.TZDateTime nextEventAlarm(
  CalendarEvent event,
  int weekday,
  int offset,
  DateTime now,
) {
  final location = tz.getLocation(event.timezone);
  final local = tz.TZDateTime.from(now, location);
  final parts = event.time.split(':').map(int.parse).toList();
  for (var day = 0; day <= 14; day++) {
    final occurrence = tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day + day,
      parts[0],
      parts[1],
    );
    if (occurrence.weekday != weekday) continue;
    final alarm = occurrence.add(Duration(minutes: offset));
    if (alarm.isAfter(now)) return alarm;
  }
  throw StateError('No next occurrence for ${event.key}');
}

/// Null when the event cannot be timed: a legacy timetable slot may carry no
/// zone, an obsolete zone, or a weekday outside 1-7.
List<EventAlarm>? _alarmsFor(CalendarEvent event, int offset, DateTime now) {
  final weekdays = event.weekdays;
  if (weekdays.isEmpty || weekdays.any((d) => d < 1 || d > 7)) return null;
  try {
    return [
      for (final weekday in weekdays)
        EventAlarm(event, weekday, nextEventAlarm(event, weekday, offset, now)),
    ];
  } on tz.LocationNotFoundException {
    return null;
  } on FormatException {
    return null;
  }
}

({List<EventAlarm> alarms, int dropped}) planEventAlarms(
  StudentCalendar calendar,
  DateTime now,
  int capacity,
) {
  final candidates = <EventAlarm>[];
  final omittedKeys = <String>{};
  for (final event in calendar.events) {
    final setting = calendar.setting(event.key);
    if (setting.muted || setting.deleted) continue;
    final alarms = _alarmsFor(event, setting.offset, now);
    if (alarms == null) {
      // Surface it in the unarmed count without preventing valid events
      // from being scheduled.
      omittedKeys.add(event.key);
      continue;
    }
    candidates.addAll(alarms);
  }
  candidates.sort((a, b) {
    final order = a.at.compareTo(b.at);
    return order != 0
        ? order
        : '${a.event.key}:${a.weekday}'.compareTo(
            '${b.event.key}:${b.weekday}',
          );
  });
  final selected = candidates.take(capacity < 0 ? 0 : capacity).toList();
  omittedKeys.addAll(candidates.skip(selected.length).map((a) => a.event.key));
  return (alarms: selected, dropped: omittedKeys.length);
}
