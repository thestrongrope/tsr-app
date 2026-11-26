import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/pending_report.dart';

Map<String, dynamic> _class(
  int id,
  String code,
  String level,
  int forms,
  int mcq,
) => {
  'classId': id,
  'level': level,
  'class': code,
  'notFilled': forms,
  'mcqPending': mcq,
  'mcqConducted': 4,
  'mcqExpected': 20,
};

Map<String, dynamic> _body() => {
  'gender': 1,
  'from': '09-2026',
  'to': '10-2026',
  'levels': ['AMMAR', 'BILAL'],
  'teachers': [
    {
      'teacherToken': 100,
      'teacher': 'Teacher A',
      'notFilled': 5,
      'mcqPending': 3,
      'classes': [
        _class(1, 'A1', 'AMMAR', 3, 3),
        _class(2, 'B1', 'BILAL', 2, 0),
      ],
    },
  ],
};

void main() {
  test('parses the period, the levels and each teacher\'s classes', () {
    final report = PendingReport.fromJson(_body());

    expect(report.gender, 1);
    expect(report.from, '09-2026');
    expect(report.levels, ['AMMAR', 'BILAL']);
    final t = report.teachers.single;
    expect(t.token, 100);
    expect(t.name, 'Teacher A');
    expect(t.classes.first.className, 'A1');
    expect(t.classes.first.mcqExpected, 20);
  });

  test('a teacher\'s totals are the sum of their classes', () {
    final t = PendingReport.fromJson(_body()).teachers.single;

    expect(t.notFilled, 5);
    expect(t.mcqPending, 3);
  });

  test('inLevel keeps only that level\'s classes and recounts the totals', () {
    final t = PendingReport.fromJson(_body()).teachers.single;

    final bilal = t.inLevel('BILAL');
    expect(bilal.classes.map((c) => c.className), ['B1']);
    expect(bilal.notFilled, 2);
    expect(bilal.mcqPending, 0);
    expect(t.inLevel(null).classes, hasLength(2));
    expect(t.inLevel('SALMAN').classes, isEmpty);
  });

  test('a body that is not a report throws', () {
    expect(() => PendingReport.fromJson('nope'), throwsFormatException);
    expect(() => PendingReport.fromJson({'levels': []}), throwsFormatException);
  });

  group('PendingNudge', () {
    test('parses the message and whether the teacher was reminded', () {
      final n = PendingNudge.fromJson({
        'teacher': 'Teacher A',
        'title': 'Reminder',
        'body': 'Please complete the following',
        'alreadyReminded': true,
        'lastReminded': '2026-10-14 08:00:00',
        'sent': false,
      });

      expect(n.teacher, 'Teacher A');
      expect(n.body, 'Please complete the following');
      expect(n.alreadyReminded, isTrue);
      expect(n.lastReminded, '2026-10-14 08:00:00');
      expect(n.sent, isFalse);
    });

    test('is not sent unless the server says true', () {
      expect(
        PendingNudge.fromJson({'body': 'x', 'sent': 'true'}).sent,
        isFalse,
      );
      expect(PendingNudge.fromJson({'body': 'x', 'sent': true}).sent, isTrue);
    });

    test('a body that is not an answer throws', () {
      expect(() => PendingNudge.fromJson('nope'), throwsFormatException);
      expect(
        () => PendingNudge.fromJson({'teacher': 'A'}),
        throwsFormatException,
      );
    });
  });
}
