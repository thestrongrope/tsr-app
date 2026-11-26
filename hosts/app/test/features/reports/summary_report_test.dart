import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/summary_report.dart';

Map<String, dynamic> _class({Object? subjects}) => {
  'classId': 7,
  'level': 'AMMAR',
  'class': 'A1',
  'teacher': 'T',
  'expected': 12,
  'conducted': 8,
  'notFilled': 1,
  'notConducted': 3,
  'avgStudents': 14,
  'avgDuration': 55,
  'percentNotFilled': 8,
  'percentConduction': 67,
  'percentAttendance': 73,
  'subjects': subjects,
};

void main() {
  test('parses the period and each class\'s figures', () {
    final report = SummaryReport.fromJson({
      'gender': 2,
      'from': '07-2026',
      'to': '10-2026',
      'levels': ['AMMAR'],
      'classes': [_class()],
    });

    expect(report.gender, 2);
    expect(report.from, '07-2026');
    final c = report.classes.single;
    expect(c.expected, 12);
    expect(c.percentConduction, 67);
    expect(c.avgDuration, 55);
    expect(c.subjects, isNull);
  });

  test('a class that records subjects carries all five', () {
    final report = SummaryReport.fromJson({
      'classes': [
        _class(
          subjects: {
            'arabic': {'count': 4, 'percent': 50},
            'aqaed': {'count': 2, 'percent': 25},
            'ahkam': {'count': 1, 'percent': 13},
            'akhlaq': {'count': 0, 'percent': 0},
            'other': {'count': 3, 'percent': 38},
          },
        ),
      ],
    });

    final subjects = report.classes.single.subjects!;
    expect(subjects.arabic.count, 4);
    expect(subjects.ahkam.percent, 13);
    expect(subjects.akhlaq.count, 0);
    expect(subjects.other.percent, 38);
  });

  test('a period where nothing was expected has no sessions', () {
    final empty = SummaryReport.fromJson({
      'classes': [_class()..['expected'] = 0],
    });

    expect(empty.hasSessions, isFalse);
  });

  test('a body that is not a summary throws', () {
    expect(() => SummaryReport.fromJson('nope'), throwsFormatException);
    expect(() => SummaryReport.fromJson({'levels': []}), throwsFormatException);
  });
}
