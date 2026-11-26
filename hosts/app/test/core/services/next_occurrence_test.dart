import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:the_strong_rope/core/services/scheduled_notification_service.dart';
import 'package:the_strong_rope/features/classes/models/class_schedule.dart';

/// Regression tests for the reminder instant.
///
/// These exist because every defect this method has had was silent: a reminder
/// computed in the wrong zone, or an hour out after a DST change, still
/// schedules successfully and simply arrives at the wrong time — or never, if
/// the user has moved on by then.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  final service = ScheduledNotificationService.instance;

  test('uses the schedule timezone, not tz.local', () {
    // tz.local is UTC in tests (and in the app — setLocalLocation is never
    // called). If this regressed to reading tz.local, the offset below would
    // be zero instead of +05:30.
    const schedule = ClassSchedule(
      day: 1,
      hour: 19,
      minute: 30,
      timezone: 'Asia/Kolkata',
    );

    final next = service.nextOccurrence(schedule, 0);

    expect(next.location.name, 'Asia/Kolkata');
    expect(next.timeZoneOffset, const Duration(hours: 5, minutes: 30));
    expect(next.hour, 19);
    expect(next.minute, 30);
  });

  test('honours a non-IST zone', () {
    // 46 production schedules are outside India; this is the case the original
    // "every class runs in India" assumption would have broken.
    const schedule = ClassSchedule(
      day: 3,
      hour: 18,
      minute: 0,
      timezone: 'America/Chicago',
    );

    final next = service.nextOccurrence(schedule, 0);

    expect(next.location.name, 'America/Chicago');
    expect(next.hour, 18);
  });

  test('falls back to Asia/Kolkata when the timezone is null', () {
    // 8 production rows carry no timezone.
    const schedule = ClassSchedule(day: 2, hour: 7, minute: 15);

    final next = service.nextOccurrence(schedule, 0);

    expect(next.location.name, 'Asia/Kolkata');
    expect(next.hour, 7);
  });

  test('falls back rather than throwing on an unrecognised zone', () {
    const schedule = ClassSchedule(
      day: 2,
      hour: 7,
      minute: 15,
      timezone: 'Mars/Olympus_Mons',
    );

    final next = service.nextOccurrence(schedule, 0);

    expect(next.location.name, 'Asia/Kolkata');
  });

  test('lands on the requested ISO weekday', () {
    // day is an ISO weekday: 1 = Monday .. 7 = Sunday, as the web admin writes
    // it (web/edit_class.php). Checked for every day rather than one, since an
    // off-by-one here is invisible until a reminder arrives on the wrong day.
    for (var day = 1; day <= 7; day++) {
      final schedule = ClassSchedule(
        day: day,
        hour: 12,
        minute: 0,
        timezone: 'Asia/Kolkata',
      );

      final next = service.nextOccurrence(schedule, 0);

      expect(next.weekday, day, reason: 'day $day landed on ${next.weekday}');
    }
  });

  test('the reminder instant is always in the future', () {
    for (var day = 1; day <= 7; day++) {
      final schedule = ClassSchedule(
        day: day,
        hour: 0,
        minute: 0,
        timezone: 'Asia/Kolkata',
      );

      final next = service.nextOccurrence(schedule, -15);
      final now = tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'));

      expect(next.isAfter(now), isTrue, reason: 'day $day is in the past');
    }
  });

  test('applies a negative offset as a lead before class start', () {
    const schedule = ClassSchedule(
      day: 5,
      hour: 19,
      minute: 30,
      timezone: 'Asia/Kolkata',
    );

    final start = service.nextOccurrence(schedule, 0);
    final lead = service.nextOccurrence(schedule, -15);

    expect(start.difference(lead), const Duration(minutes: 15));
    expect(lead.hour, 19);
    expect(lead.minute, 15);
  });

  test('keeps the wall-clock hour when the target is across a DST change', () {
    // This is the regression that motivated the rewrite, and it needs a fixed
    // clock to be reproducible. US DST starts 02:00 on Sunday 8 March 2026.
    //
    // Standing on Wednesday 4 March (CST, UTC-6) and asking for the next
    // Sunday 18:00 lands on 8 March, which is CDT (UTC-5). The old code got
    // there with `.add(Duration(days: 4))` — absolute arithmetic — and so
    // produced 19:00 local. Building from calendar fields gives 18:00.
    final chicago = tz.getLocation('America/Chicago');
    final wednesday = tz.TZDateTime(chicago, 2026, 3, 4, 12);

    const schedule = ClassSchedule(
      day: 7, // Sunday, ISO
      hour: 18,
      minute: 0,
      timezone: 'America/Chicago',
    );

    final next = service.nextOccurrence(schedule, 0, clock: wednesday);

    expect(next.month, 3);
    expect(next.day, 8, reason: 'should be the Sunday after the 4th');
    expect(next.weekday, DateTime.sunday);
    expect(next.hour, 18, reason: 'absolute day arithmetic would give 19');
    expect(next.timeZoneOffset, const Duration(hours: -5), reason: 'CDT');
  });

  test('keeps the wall-clock hour rolling forward a week across DST', () {
    // Same transition, but reached through the "already passed, take next
    // week" branch: standing on Sunday 1 March after 18:00 pushes to 8 March.
    final chicago = tz.getLocation('America/Chicago');
    final sundayLate = tz.TZDateTime(chicago, 2026, 3, 1, 20);

    const schedule = ClassSchedule(
      day: 7,
      hour: 18,
      minute: 0,
      timezone: 'America/Chicago',
    );

    final next = service.nextOccurrence(schedule, 0, clock: sundayLate);

    expect(next.day, 8);
    expect(next.hour, 18, reason: 'the +7 day roll must not drift either');
  });
}
