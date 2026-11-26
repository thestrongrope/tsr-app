import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/tsr_report.dart';

Map<String, dynamic> _body() => {
  'gender': 1,
  'from': '2026-09-29',
  'to': '2026-10-13',
  'conduction': {
    'levels': [
      {
        'levelId': 3,
        'level': 'AMMAR',
        'conducted': 4,
        'total': 6,
        'percent': 66.7,
      },
      {
        'levelId': 4,
        'level': 'BILAL',
        'conducted': 3,
        'total': 3,
        'percent': 100.0,
      },
      {
        'levelId': 5,
        'level': 'SALMAN',
        'conducted': 0,
        'total': 2,
        'percent': 0.0,
      },
    ],
    'classes': [
      {
        'level': 'AMMAR',
        'class': 'A1',
        'teacher': 'T',
        'lastConducted': '2026-10-08',
      },
      {'level': 'AMMAR', 'class': 'A2', 'teacher': 'U', 'lastConducted': null},
    ],
  },
  'mcq': {
    'levels': [
      {
        'levelId': 3,
        'level': 'AMMAR',
        'conducted': 1,
        'total': 6,
        'percent': 16.7,
      },
    ],
    'classes': [
      {
        'level': 'AMMAR',
        'class': 'A1',
        'teacher': 'T',
        'lastConducted': '2026-10-02',
      },
    ],
  },
  'attendance': {
    'levels': [
      {'levelId': 3, 'level': 'AMMAR', 'percent': 83},
    ],
    'classes': [
      {'level': 'AMMAR', 'class': 'A1', 'teacher': 'T', 'percent': 76},
    ],
  },
  'recitation': {
    'levels': [
      {'levelId': 3, 'level': 'AMMAR', 'total': 12},
    ],
    'classes': [
      {'level': 'AMMAR', 'class': 'A1', 'teacher': 'T', 'total': 7},
    ],
  },
};

void main() {
  test('builds the four sections in the web page\'s order', () {
    final report = TsrReport.fromJson(_body());

    expect(report.gender, 1);
    expect(report.from, '2026-09-29');
    expect(
      [for (final s in report.sections) s.title],
      ['Class conduction', 'MCQ conduction', 'Attendance', 'Recitation'],
    );
  });

  test(
    'conduction reads as counts and a percentage, as the page prints it',
    () {
      final levels = TsrReport.fromJson(_body()).sections[0].levels;

      expect(levels[0].summary, '4 of 6 (66.7%)');
      expect(levels[1].summary, '3 of 3 (100%)');
      expect(levels[2].summary, '0 of 2 (0%)');
    },
  );

  test('attendance is a percentage and recitation a total', () {
    final report = TsrReport.fromJson(_body());

    expect(report.sections[2].levels.single.summary, '83%');
    expect(report.sections[3].levels.single.summary, '12');
  });

  test('a class says when it last held a session, or that it has not', () {
    final classes = TsrReport.fromJson(_body()).sections[0].classes;

    expect(classes[0].detail, 'Last held 2026-10-08');
    expect(classes[1].detail, 'None in this period');
    expect(
      TsrReport.fromJson(_body()).sections[1].classes.single.detail,
      'Last MCQ 2026-10-02',
    );
  });

  test('classesOf gives only the level\'s classes', () {
    final section = TsrReport.fromJson(_body()).sections[0];

    expect(section.classesOf('AMMAR'), hasLength(2));
    expect(section.classesOf('BILAL'), isEmpty);
  });

  test('a period with no levels has no classes', () {
    final empty = _body()
      ..['conduction'] = {'levels': [], 'classes': []}
      ..['mcq'] = {'levels': [], 'classes': []}
      ..['attendance'] = {'levels': [], 'classes': []}
      ..['recitation'] = {'levels': [], 'classes': []};

    expect(TsrReport.fromJson(empty).hasClasses, isFalse);
    expect(TsrReport.fromJson(_body()).hasClasses, isTrue);
  });

  test('a body that is not a report throws', () {
    expect(() => TsrReport.fromJson('nope'), throwsFormatException);
    expect(() => TsrReport.fromJson({'conduction': {}}), throwsFormatException);
  });
}
