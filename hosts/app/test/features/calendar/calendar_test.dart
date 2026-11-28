import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/calendar/calendar_models.dart';
import 'package:the_strong_rope/features/calendar/calendar_repository.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Map<String, Object?> event({
  String key = 'event:1',
  String zone = 'America/New_York',
}) => {
  'key': key,
  'kind': 'event',
  'class_id': 7,
  'message': 'Lesson',
  'description': 'Read chapter two',
  'action_link': '/classes/7/dashboard',
  'weekdays': [7],
  'send_time': '09:00',
  'timezone': zone,
  'editable_by_me': false,
};

Map<String, Object?> payload({
  Map<String, Object?> settings = const {},
  List<Map<String, Object?>>? events,
}) => {
  'server_time': '2027-03-12T00:00:00Z',
  'settings': settings,
  'classes': [
    {
      'class_id': 7,
      'name': 'My class',
      'events': events ?? [event()],
      'slots': [],
    },
  ],
};

void main() {
  setUpAll(tzdata.initializeTimeZones);
  for (final offset in eventOffsets) {
    test('offset $offset is an elapsed duration across DST', () {
      final alarm = nextEventAlarm(
        CalendarEvent(event()),
        7,
        offset,
        DateTime.utc(2027, 3, 11),
      );
      final occurrence = tz.TZDateTime(
        tz.getLocation('America/New_York'),
        2027,
        3,
        14,
        9,
      );
      expect(occurrence.difference(alarm).inMinutes, -offset);
    });
  }
  test('nearest alarms win the cap and muted events arm nothing', () {
    final later = event(key: 'event:2')..['send_time'] = '20:00';
    final calendar = StudentCalendar(payload(events: [later, event()]));
    final plan = planEventAlarms(calendar, DateTime.utc(2027, 3, 11), 1);
    expect(plan.alarms.single.event.key, 'event:1');
    expect(plan.dropped, 1);
    final muted = StudentCalendar(
      payload(
        settings: {
          'event:1': {'muted': true},
        },
      ),
    );
    expect(
      planEventAlarms(muted, DateTime.utc(2027, 3, 11), 60).alarms,
      isEmpty,
    );
  });

  test('invalid legacy slot zone does not suppress valid alarms', () {
    final calendar = StudentCalendar(
      payload(
        events: [
          event(),
          event(key: 'slot:2', zone: 'Moon/Base'),
        ],
      ),
    );
    final plan = planEventAlarms(calendar, DateTime.utc(2027, 3, 11), 60);
    expect(plan.alarms.single.event.key, 'event:1');
    expect(plan.dropped, 1);
  });

  test(
    'a slot with no zone or a weekday outside 1-7 arms nothing else wrong',
    () {
      final noZone = event(key: 'slot:2')..['timezone'] = null;
      final badDay = event(key: 'slot:3')..['weekdays'] = [0];
      final calendar = StudentCalendar(
        payload(events: [event(), noZone, badDay]),
      );
      final plan = planEventAlarms(calendar, DateTime.utc(2027, 3, 11), 60);
      expect(plan.alarms.single.event.key, 'event:1');
      expect(plan.dropped, 2);
      expect(CalendarEvent(noZone).cadence, 'Sun at 09:00');
      expect(CalendarEvent(badDay).cadence, contains('at 09:00'));
    },
  );

  group('persistent calendar and outbox', () {
    late Directory directory;
    late Box box;
    late DateTime now;
    late bool online;
    late bool ownerCurrent;
    late Map<String, Object?> server;
    late List<Map<String, Object?>> sent;
    late bool refuseUploads;
    CalendarRepository repository(int owner) => CalendarRepository(
      owner: owner,
      box: box,
      clock: () => now,
      isCurrentOwner: () => ownerCurrent,
      fetch: () async {
        if (!online) throw const ApiException('offline', 0);
        return server;
      },
      upload: (request) async {
        sent.add(request);
        if (refuseUploads) throw const ApiException('refused', 422);
        final changes = <String, Object?>{};
        for (final raw in request['changes'] as List) {
          final change = calendarMap(raw);
          changes[change['event_key'] as String] = change;
        }
        server = {...server, 'settings': changes};
        return {'settings': changes, 'clock_skew': false};
      },
    );
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('calendar_test');
      Hive.init(directory.path);
      box = await Hive.openBox('calendar');
      now = DateTime.utc(2027, 3, 12);
      online = true;
      ownerCurrent = true;
      server = payload();
      sent = [];
      refuseUploads = false;
    });
    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    test(
      'a change the server refuses is dropped, not retried for ever',
      () async {
        final repo = repository(1);
        await repo.initialize();
        await repo.refresh();
        await repo.change('event:1', const EventSetting(muted: true));
        refuseUploads = true;
        final refreshed = await repo.refresh();
        expect(refreshed.setting('event:1').muted, isFalse);
        refuseUploads = false;
        sent.clear();
        await repo.refresh();
        expect(sent, isEmpty);
      },
    );
    test(
      'offline copy survives restart but is never shown to another member',
      () async {
        final first = repository(1);
        await first.initialize();
        await first.refresh();
        online = false;
        final restart = repository(1);
        await restart.initialize();
        expect((await restart.refresh()).events.single.message, 'Lesson');
        final other = repository(2);
        await other.initialize();
        expect(other.current, isNull);
        ownerCurrent = false;
        expect(restart.current, isNull);
      },
    );
    test(
      'delete hides immediately, holds for ten seconds and supports Undo',
      () async {
        final repo = repository(1);
        await repo.initialize();
        await repo.refresh();
        await repo.change(
          'event:1',
          const EventSetting(deleted: true),
          holdDelete: true,
        );
        expect(repo.current!.events, isEmpty);
        await repo.refresh();
        expect(sent, isEmpty);
        now = now.add(const Duration(seconds: 9));
        expect(await repo.undo('event:1'), isTrue);
        expect(repo.current!.events, hasLength(1));
        await repo.change(
          'event:1',
          const EventSetting(deleted: true),
          holdDelete: true,
        );
        now = now.add(const Duration(seconds: 10));
        expect(await repo.undo('event:1'), isFalse);
        await repo.refresh();
        expect(sent, hasLength(1));
        expect(repo.current!.events, isEmpty);
      },
    );
    test(
      'restart commits held tombstones and fresh phone restores settings',
      () async {
        final repo = repository(1);
        await repo.initialize();
        await repo.refresh();
        await repo.change(
          'event:1',
          const EventSetting(offset: -60, muted: true, deleted: true),
          holdDelete: true,
        );
        final restart = repository(1);
        await restart.initialize();
        await restart.refresh();
        expect(sent, hasLength(1));
        await box.clear();
        final newPhone = repository(1);
        await newPhone.initialize();
        final restored = await newPhone.refresh();
        expect(restored.setting('event:1').offset, -60);
        expect(restored.setting('event:1').muted, isTrue);
        expect(restored.events, isEmpty);
      },
    );
    test('canonical server response corrects a stale phone', () async {
      final repo = CalendarRepository(
        owner: 1,
        box: box,
        clock: () => now,
        isCurrentOwner: () => true,
        fetch: () async => payload(),
        upload: (_) async => {
          'settings': {
            'event:1': {'offset_minutes': -30, 'muted': true, 'deleted': false},
          },
        },
      );
      await repo.initialize();
      await repo.refresh();
      await repo.change('event:1', const EventSetting(offset: -5));
      final corrected = await repo.refresh();
      expect(corrected.setting('event:1').offset, -30);
      expect(corrected.setting('event:1').muted, isTrue);
    });
  });
}
