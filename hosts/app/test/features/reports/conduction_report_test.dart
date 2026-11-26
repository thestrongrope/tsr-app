import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/conduction_report.dart';

/// `GET /reports/conduction` as web/api/mobile/routes/reports.php sends it.
Map<String, dynamic> _body() => {
  'gender': 1,
  'year': 2026,
  'week': 40,
  'previous': {'year': 2026, 'week': 39},
  'next': null,
  'weekOf': '04-Oct to 10-Oct',
  'summaryStart': 'Mon, 01-Sep-26',
  'summaryEnd': 'Sun, 11-Oct-26',
  'levels': ['AMMAR', 'BILAL'],
  'classes': [
    {
      'level': 'AMMAR',
      'gender': 'Gents',
      'class': 'A1',
      'teacher': 'T',
      'expected': 6,
      'conducted': 4,
      'notFilled': 1,
      'notConducted': 1,
      'students': 20,
      'attendance': 48,
      'percentNotFilled': 17,
      'percentConduction': 80,
      'percentAttendance': 60,
    },
    {
      'level': 'BILAL',
      'class': 'B1',
      'teacher': null,
      'expected': 3,
      'conducted': 0,
      'notFilled': 3,
      'notConducted': 0,
      'students': 9,
      'percentNotFilled': 100,
      'percentConduction': 0,
      'percentAttendance': 0,
    },
  ],
  'lastWeek': [
    {
      'classId': 7,
      'level': 'AMMAR',
      'class': 'A1',
      'teacher': 'T',
      'status': 'Yes',
      'conductedOn': '2026-10-08',
      'duration': 60,
      'attendance': 14,
    },
    {'classId': 8, 'level': 'BILAL', 'class': 'B1', 'status': 'Not Filled'},
    {
      'classId': 9,
      'level': 'BILAL',
      'class': 'B2',
      'status': 'No',
      'reason': 'Teacher unwell',
    },
  ],
};

void main() {
  group('ConductionReport.fromJson', () {
    test('reads the week, the levels and the per-class figures', () {
      final report = ConductionReport.fromJson(_body());

      expect(report.week, 40);
      expect(report.previous, (year: 2026, week: 39));
      expect(report.next, isNull);
      expect(report.weekOf, '04-Oct to 10-Oct');
      expect(report.levels, ['AMMAR', 'BILAL']);
      expect(report.classes.first.className, 'A1');
      expect(report.classes.first.percentConduction, 80);
      expect(report.classes.first.neverHeld, isFalse);
    });

    test('a class with expected sessions but none held is never-held', () {
      final report = ConductionReport.fromJson(_body());

      expect(report.classes.last.neverHeld, isTrue);
      expect(report.classes.last.teacher, '');
    });

    test('week rows keep held, not held and not filled apart', () {
      final rows = ConductionReport.fromJson(_body()).lastWeek;

      expect(rows.map((r) => r.status), [
        WeekStatus.held,
        WeekStatus.notFilled,
        WeekStatus.notHeld,
      ]);
      expect(rows.first.attendance, 14);
      expect(rows.last.reason, 'Teacher unwell');
      expect(rows[1].conductedOn, isNull);
    });

    test('an empty week is an empty report, not an error', () {
      final report = ConductionReport.fromJson(
        _body()
          ..['classes'] = []
          ..['lastWeek'] = []
          ..['weekOf'] = '',
      );

      expect(report.classes, isEmpty);
      expect(report.lastWeek, isEmpty);
    });

    test('a body that is not a report throws, so the screen can retry', () {
      expect(
        () => ConductionReport.fromJson({'detail': 'Not Found'}),
        throwsFormatException,
      );
      expect(() => ConductionReport.fromJson(null), throwsFormatException);
    });
  });
}
