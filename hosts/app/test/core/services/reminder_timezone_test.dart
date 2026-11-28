import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Every distinct `class_schedules.timezone` value in production, captured
/// 2026-09-21. The point of the list is that it is **not** all `Asia/Kolkata`:
/// 46 schedules sit in ten other zones, six of which observe DST.
///
/// `US/Central` and `US/Eastern` are tzdata "backward" links. Only
/// `package:timezone/data/latest_all.dart` carries those; the plain
/// `latest.dart` would throw on them, and the scheduler's catch-and-fall-back
/// would silently move ten classes to IST. That is exactly the kind of failure
/// this test exists to catch, so assert the names the database actually holds.
const productionZones = <String>[
  'Asia/Kolkata',
  'America/Chicago',
  'Asia/Dubai',
  'US/Central',
  'Africa/Dar_es_Salaam',
  'America/Toronto',
  'US/Eastern',
  'America/New_York',
  'America/Los_Angeles',
  'Europe/London',
  'America/Managua',
];

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('every timezone present in production resolves', () {
    for (final name in productionZones) {
      expect(
        () => tz.getLocation(name),
        returnsNormally,
        reason:
            '$name does not resolve, so those classes would silently '
            'fall back to the default zone',
      );
    }
  });

  test(
    'tz.local is UTC until set, which is why the scheduler never reads it',
    () {
      // Guards the original defect: initializeTimeZones() alone leaves tz.local
      // as UTC. If a future change starts reading tz.local instead of the
      // per-schedule location, reminders silently move by the UTC offset.
      expect(tz.local.name, 'UTC');
    },
  );

  test('a DST zone really does change offset across the year', () {
    final chicago = tz.getLocation('America/Chicago');
    final winter = tz.TZDateTime(chicago, 2026, 1, 15, 19, 30);
    final summer = tz.TZDateTime(chicago, 2026, 7, 15, 19, 30);
    expect(winter.timeZoneOffset, isNot(equals(summer.timeZoneOffset)));
  });

  test('adding 7 days across a DST boundary shifts the wall clock', () {
    // The reason _nextOccurrence must not reach its target date by adding a
    // Duration: TZDateTime.add is absolute, so a week added across a
    // transition lands an hour off the intended local time.
    final chicago = tz.getLocation('America/Chicago');
    // 2026-03-08 is the US spring-forward date.
    final before = tz.TZDateTime(chicago, 2026, 3, 1, 19, 30);
    final plusWeek = before.add(const Duration(days: 7));
    expect(
      plusWeek.hour,
      isNot(19),
      reason: 'absolute addition is expected to drift here',
    );

    // Rebuilding from calendar fields keeps 19:30 local.
    final rebuilt = tz.TZDateTime(chicago, 2026, 3, 8, 19, 30);
    expect(rebuilt.hour, 19);
  });
}
