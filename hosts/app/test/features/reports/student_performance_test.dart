import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/student_performance.dart';
import 'package:the_strong_rope/features/reports/screens/student_performance_screen.dart';

StudentPerformance _student(
  String name, {
  String token = '1',
  int tsr = 50,
  int attendance = 50,
  int mcq = 50,
  int recitation = 0,
}) => StudentPerformance(
  token: token,
  name: name,
  level: 'AMMAR',
  className: 'A1',
  sessions: 8,
  attendance: attendance,
  totalMcqs: 4,
  mcqAttempted: 75,
  mcqPerformance: mcq,
  recitation: recitation,
  recitationAvg: 0,
  tsrScore: tsr,
);

void main() {
  test('parses the period, the pickers\' lists and each student', () {
    final report = StudentsReport.fromJson({
      'gender': 2,
      'from': '2026-09-13',
      'to': '2026-10-13',
      'levels': ['AMMAR'],
      'classes': [
        {'class': 'A1', 'level': 'AMMAR'},
      ],
      'students': [
        {
          'token': '101',
          'name': 'Ann',
          'level': 'AMMAR',
          'class': 'A1',
          'sessions': 8,
          'attendance': 83,
          'totalMcqs': 4,
          'mcqAttempted': 75,
          'mcqPerformance': 50,
          'recitation': 10,
          'recitationAvg': 1.25,
          'tsrScore': 69,
        },
      ],
    });

    expect(report.gender, 2);
    expect(report.classes.single.className, 'A1');
    final s = report.students.single;
    expect(s.token, '101');
    expect(s.attendance, 83);
    expect(s.recitationAvg, 1.25);
    expect(s.tsrScore, 69);
  });

  test('a body that is not a report throws', () {
    expect(() => StudentsReport.fromJson('nope'), throwsFormatException);
    expect(
      () => StudentsReport.fromJson({'levels': []}),
      throwsFormatException,
    );
  });

  group('sortStudents', () {
    final students = [
      _student('Bea', token: '2', tsr: 60, attendance: 90, recitation: 1),
      _student('Cal', token: '3', tsr: 80, attendance: 50, recitation: 5),
      _student('Abe', token: '1', tsr: 60, attendance: 70, recitation: 9),
    ];

    List<String> names(StudentSort sort) => [
      for (final s in sortStudents(students, sort)) s.name,
    ];

    test('the best first by each figure', () {
      expect(names(StudentSort.attendance), ['Bea', 'Abe', 'Cal']);
      expect(names(StudentSort.recitation), ['Abe', 'Cal', 'Bea']);
    });

    test('ties fall back to name, so the order is the same every time', () {
      expect(names(StudentSort.tsrScore), ['Cal', 'Abe', 'Bea']);
    });

    test('by name is A to Z', () {
      expect(names(StudentSort.name), ['Abe', 'Bea', 'Cal']);
    });

    test('does not change the list it is given', () {
      sortStudents(students, StudentSort.name);

      expect(students.first.name, 'Bea');
    });
  });
}
