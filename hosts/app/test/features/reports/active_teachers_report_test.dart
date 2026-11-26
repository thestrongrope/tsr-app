import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/active_teachers_report.dart';

void main() {
  test('parses each teacher in the order sent', () {
    final report = ActiveTeachersReport.fromJson({
      'gender': 2,
      'teachers': [
        {
          'token': 1001,
          'name': 'Ali',
          'attendingClass': 'C1, C2',
          'selfTeacher': 'T1, T2',
          'maxLevel': 'AMMAR',
          'totalClasses': 2,
          'conductingClasses': 'A1, A2',
        },
        {
          'token': 2002,
          'name': 'Zayd',
          'attendingClass': null,
          'selfTeacher': null,
          'maxLevel': 'BILAL',
          'totalClasses': 1,
          'conductingClasses': 'B1',
        },
      ],
    });

    expect(report.gender, 2);
    expect(report.teachers.map((t) => t.name), ['Ali', 'Zayd']);
    final ali = report.teachers.first;
    expect(ali.token, 1001);
    expect(ali.totalClasses, 2);
    expect(ali.conductingClasses, 'A1, A2');
    expect(ali.attendingClass, 'C1, C2');
  });

  test('a teacher who attends nothing has empty attending fields', () {
    final zayd = ActiveTeacher.fromJson({
      'token': 2002,
      'name': 'Zayd',
      'attendingClass': null,
      'selfTeacher': null,
      'maxLevel': 'BILAL',
      'totalClasses': 1,
      'conductingClasses': 'B1',
    });

    expect(zayd.attendingClass, '');
    expect(zayd.selfTeacher, '');
  });

  test('a body that is not this report throws', () {
    expect(
      () => ActiveTeachersReport.fromJson({'detail': 'nope'}),
      throwsFormatException,
    );
  });
}
