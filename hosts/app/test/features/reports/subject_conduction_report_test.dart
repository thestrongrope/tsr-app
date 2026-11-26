import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/subject_conduction_report.dart';

Map<String, dynamic> _row(String cls, String level, String week) => {
  'class': cls,
  'level': level,
  'teacher': 'T $cls',
  'week': week,
  'heldOn': '09 Sep 2026',
  'arabic': 'Conducted',
  'aqaed': '',
  'ahkam': 'Wudu; Ghusl',
  'akhlaq': '',
  'other': '',
};

void main() {
  test('groups the rows by class and keeps the weeks in order', () {
    final report = SubjectConductionReport.fromJson({
      'gender': 2,
      'from': '09-2026',
      'to': '09-2026',
      'levels': ['AMMAR', 'BILAL'],
      'rows': [
        _row('A1', 'AMMAR', '2026-W36'),
        _row('A1', 'AMMAR', '2026-W37'),
        _row('B1', 'BILAL', '2026-W37'),
      ],
    });

    expect(report.gender, 2);
    expect(report.classes.map((c) => c.className), ['A1', 'B1']);
    expect(report.classes.first.weeks.map((w) => w.week), [
      '2026-W36',
      '2026-W37',
    ]);
    expect(report.classes.first.teacher, 'T A1');
    expect(report.hasSessions, isTrue);
  });

  test('a subject not taught is an empty string, not missing', () {
    final week = SubjectConductionReport.fromJson({
      'rows': [_row('A1', 'AMMAR', '2026-W37')],
    }).classes.single.weeks.single;

    expect(week.arabic, 'Conducted');
    expect(week.aqaed, '');
    expect(week.ahkam, 'Wudu; Ghusl');
    expect(week.heldOn, '09 Sep 2026');
  });

  test('no rows means nothing was held', () {
    final report = SubjectConductionReport.fromJson({'rows': []});

    expect(report.hasSessions, isFalse);
  });

  test('a body that is not this report throws', () {
    expect(
      () => SubjectConductionReport.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });

  test('the classes in reach are read, including one with no rows', () {
    final report = SubjectConductionReport.fromJson({
      'rows': [],
      'classes': [
        {'classId': 7, 'class': 'C1', 'level': 'AMMAR', 'teacher': 'T C1'},
      ],
    });

    expect(report.classChoices.single.classId, 7);
    expect(report.classChoices.single.className, 'C1');
    expect(report.classChoices.single.level, 'AMMAR');
  });
}
