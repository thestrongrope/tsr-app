import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/mcq_adherence_report.dart';

void main() {
  test('parses each class with its figures, in the order sent', () {
    final report = McqAdherenceReport.fromJson({
      'gender': 2,
      'levels': ['AMMAR', 'BILAL'],
      'classes': [
        {
          'classId': 8,
          'class': 'B1',
          'level': 'BILAL',
          'teacher': 'T',
          'expected': 3,
          'conducted': 1,
          'pending': 1,
          'skipped': 1,
          'adherencePercent': 33.3,
        },
        {'classId': 7, 'class': 'A1', 'level': 'AMMAR'},
      ],
    });

    expect(report.gender, 2);
    expect(report.classes.map((c) => c.className), ['B1', 'A1']);
    final f = report.classes.first.figures;
    expect(f.expected, 3);
    expect(f.adherencePercent, 33.3);
    expect(report.classes.last.figures.expected, 0);
  });

  test('a whole percentage reads without a decimal', () {
    McqAdherenceFigures at(num p) =>
        McqAdherenceFigures.fromJson({'adherencePercent': p});

    expect(at(50.0).percentLabel, '50%');
    expect(at(33.3).percentLabel, '33.3%');
    expect(at(0).percentLabel, '0%');
  });

  test('a body that is not this report throws', () {
    expect(
      () => McqAdherenceReport.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });

  test('parses a class\'s MCQs with their status', () {
    final detail = McqAdherenceDetail.fromJson({
      'expected': 2,
      'conducted': 1,
      'pending': 1,
      'skipped': 0,
      'adherencePercent': 50.0,
      'mcqs': [
        {
          'topic': 'Fiqh',
          'subject': 'Wudu',
          'lesson': '1',
          'name': 'One',
          'status': 'conducted',
        },
        {
          'topic': 'Fiqh',
          'subject': 'Wudu',
          'lesson': '2',
          'name': 'Two',
          'status': 'pending',
        },
      ],
    });

    expect(detail.figures.conducted, 1);
    expect(detail.mcqs.map((m) => m.status), ['conducted', 'pending']);
    expect(detail.mcqs.first.name, 'One');
  });

  test('a class body that is not one throws', () {
    expect(
      () => McqAdherenceDetail.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });
}
