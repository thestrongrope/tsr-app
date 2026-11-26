import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/whatsapp_reminders.dart';

void main() {
  group('WhatsappReminder', () {
    test('reads a reminder with no country, day or time', () {
      final list = WhatsappReminder.listFromJson({
        'reminders': [
          {
            'id': 1,
            'name': 'Mumbai gents',
            'gender': 'gents',
            'city': 'Mumbai',
            'country': null,
            'levels': 'BILAL,AMMAR',
            'lang': 'hinglish',
            'leewayDays': 10,
            'timezone': 'Asia/Kolkata',
            'weekday': null,
            'sendTime': null,
            'scheduleOn': false,
            'enabled': true,
          },
        ],
      });

      final r = list.single;
      expect(r.place, 'Mumbai');
      expect(r.when, '');
      expect(r.scheduleOn, isFalse);
      expect(r.enabled, isTrue);
    });

    test('names the day and shows the time without seconds', () {
      final r = WhatsappReminder.fromJson({
        'id': 2,
        'name': 'US gents',
        'country': 'United States',
        'weekday': 7,
        'sendTime': '13:00:00',
        'timezone': 'America/Chicago',
        'scheduleOn': true,
      });

      expect(r.sendTimeShort, '13:00');
      expect(r.when, 'Sunday 13:00 (America/Chicago)');
    });

    test('a body that is not the answer throws', () {
      expect(
        () => WhatsappReminder.listFromJson({'runs': []}),
        throwsFormatException,
      );
      expect(
        () => WhatsappReminder.oneFromJson({'reminder': 3}),
        throwsFormatException,
      );
    });
  });

  group('WhatsappRun', () {
    test('reads the counts, the window and the UTC times', () {
      final run = WhatsappRun.fromJson({
        'id': 4,
        'reminderId': 1,
        'startedAt': '2026-10-19T12:00:00Z',
        'finishedAt': null,
        'fromDate': '2026-10-12',
        'toDate': '2026-10-18',
        'status': 'running',
        'sent': 0,
        'skipped': 1,
        'failed': 2,
        'dryRun': true,
        'error': null,
      });

      expect(run.isRunning, isTrue);
      expect(run.dryRun, isTrue);
      expect(run.failed, 2);
      expect(run.window, '2026-10-12 → 2026-10-18');
      expect(run.startedAt, DateTime.utc(2026, 10, 19, 12));
      expect(run.finishedAt, isNull);
    });

    test('a run with no window has none to show', () {
      final run = WhatsappRun.fromJson({'id': 5, 'status': 'test'});

      expect(run.window, isNull);
      expect(run.isRunning, isFalse);
    });
  });

  group('WhatsappRunDetail', () {
    test('reads each teacher, tolerating a missing name and count', () {
      final d = WhatsappRunDetail.fromJson({
        'run': {'id': 4, 'status': 'success'},
        'messages': [
          {
            'mobile': '919800000000',
            'name': null,
            'missing': null,
            'status': 'failed',
            'error': 'not on WhatsApp',
          },
        ],
      });

      final m = d.messages.single;
      expect(m.name, isNull);
      expect(m.missing, isNull);
      expect(m.error, 'not on WhatsApp');
    });

    test('a body that is not the answer throws', () {
      expect(
        () => WhatsappRunDetail.fromJson({'run': {}}),
        throwsFormatException,
      );
    });
  });
}
