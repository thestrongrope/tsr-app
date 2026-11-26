import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/mcq_summary_report.dart';

void main() {
  test('parses the period and each class\'s counts', () {
    final report = McqSummaryReport.fromJson({
      'gender': 2,
      'from': '2026-09-01',
      'to': '2026-09-30',
      'levels': ['AMMAR'],
      'classes': [
        {
          'classId': 7,
          'class': 'A1',
          'level': 'AMMAR',
          'teacher': 'T',
          'mcqs': 4,
          'students': 12,
        },
      ],
    });

    expect(report.gender, 2);
    expect(report.from, '2026-09-01');
    final c = report.classes.single;
    expect(c.className, 'A1');
    expect(c.mcqs, 4);
    expect(c.students, 12);
  });

  test('a body that is not this report throws', () {
    expect(
      () => McqSummaryReport.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });

  test('a student with no attempts has no score, and no topic scores', () {
    final detail = McqSummaryDetail.fromJson({
      'mcqs': 4,
      'maxMarks': 20,
      'students': [
        {
          'name': 'Ali',
          'attempted': 3,
          'pending': 1,
          'correct': 15,
          'percent': 75,
          'topics': [
            {'topic': 'Wudu', 'max': 12, 'correct': 9},
          ],
        },
        {
          'name': 'Zayd',
          'attempted': 0,
          'pending': 4,
          'correct': 0,
          'percent': null,
          'topics': [
            {'topic': 'Wudu', 'max': 12, 'correct': null},
          ],
        },
      ],
    });

    expect(detail.mcqs, 4);
    expect(detail.maxMarks, 20);
    expect(detail.students.first.percent, 75);
    expect(detail.students.first.topics.single.correct, 9);
    expect(detail.students.last.percent, isNull);
    expect(detail.students.last.topics.single.correct, isNull);
  });

  test('a class body that is not one throws', () {
    expect(
      () => McqSummaryDetail.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });
}
