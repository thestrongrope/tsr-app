import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/class_sessions_report.dart';

Map<String, dynamic> _class({String? aqaed}) => {
  'classId': 7,
  'class': 'A1',
  'level': 'AMMAR',
  'teacher': 'T',
  'totalSessions': 3,
  'lastDate': '2026-09-09',
  'lastQuran': 'Maryam:5',
  'lastArabic': 'Alphabet',
  'lastAqaed': aqaed,
  'lastAhkam': null,
  'lastAkhlaq': null,
  'lastOther': null,
};

void main() {
  test(
    'parses each class and keeps only the subjects the last session covered',
    () {
      final report = ClassSessionsReport.fromJson({
        'gender': 2,
        'levels': ['AMMAR'],
        'classes': [_class()],
      });

      expect(report.gender, 2);
      final c = report.classes.single;
      expect(c.className, 'A1');
      expect(c.totalSessions, 3);
      expect(c.lastDate, '2026-09-09');
      expect(c.lastQuran, 'Maryam:5');
      expect(c.lastTopics, {'Arabic': 'Alphabet'});
    },
  );

  test('a class with no session has no last date', () {
    final c = ClassSessionsClass.fromJson({
      'classId': 7,
      'class': 'A1',
      'level': 'AMMAR',
      'totalSessions': 0,
      'lastDate': null,
    });

    expect(c.lastDate, isNull);
    expect(c.lastTopics, isEmpty);
    expect(c.teacher, '');
  });

  test('a body that is not this report throws', () {
    expect(
      () => ClassSessionsReport.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });

  test('parses a history, keeping the server\'s newest-first order', () {
    final sessions = ClassSession.listFromJson({
      'sessions': [
        {
          'date': '2026-09-09',
          'held': true,
          'reason': null,
          'quran': 'Maryam:5',
          'arabic': 'Alphabet',
          'aqaed': '',
          'ahkam': 'Wudu',
          'akhlaq': '',
          'other': '',
        },
        {
          'date': '2026-09-02',
          'held': false,
          'reason': 'Eid',
          'quran': '',
          'arabic': '',
          'aqaed': '',
          'ahkam': '',
          'akhlaq': '',
          'other': '',
        },
      ],
    });

    expect(sessions.map((s) => s.date), ['2026-09-09', '2026-09-02']);
    expect(sessions.first.topics, {'Arabic': 'Alphabet', 'Ahkam': 'Wudu'});
    expect(sessions.last.held, isFalse);
    expect(sessions.last.reason, 'Eid');
  });

  test('a history body that is not one throws', () {
    expect(
      () => ClassSession.listFromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });
}
