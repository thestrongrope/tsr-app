import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/conduction_report.dart';
import 'package:the_strong_rope/features/reports/models/weekly_report.dart';

void main() {
  test('parses weeks, classes and each class\'s cell per week', () {
    final report = WeeklyReport.fromJson({
      'gender': 2,
      'from': '09-2026',
      'to': '09-2026',
      'levels': ['AMMAR'],
      'weeks': [
        {
          'month': 'Sep-2026',
          'label': 'Wk 1',
          'from': '2026-08-30',
          'to': '2026-09-05',
        },
      ],
      'classes': [
        {
          'classId': 7,
          'level': 'AMMAR',
          'class': 'A1',
          'teacher': 'T',
          'weeks': [
            {'status': 'held', 'sessions': 2},
          ],
        },
      ],
    });

    expect(report.gender, 2);
    expect(report.weeks.single.label, 'Wk 1');
    final cell = report.classes.single.weeks.single;
    expect(cell.status, WeekStatus.held);
    expect(cell.sessions, 2);
  });

  test('an unknown status is not filled, never held', () {
    final cell = WeeklyCell.fromJson({'status': 'surprise'});

    expect(cell.status, WeekStatus.notFilled);
  });

  test('a class with only not-filled weeks has no sessions', () {
    const empty = WeeklyClass(
      classId: 1,
      level: 'L',
      className: 'C',
      teacher: '',
      weeks: [WeeklyCell(status: WeekStatus.notFilled, sessions: 0)],
    );
    const filled = WeeklyClass(
      classId: 2,
      level: 'L',
      className: 'D',
      teacher: '',
      weeks: [WeeklyCell(status: WeekStatus.notHeld, sessions: 0)],
    );

    expect(empty.hasSessions, isFalse);
    expect(filled.hasSessions, isTrue);
  });

  test('a body that is not a report throws', () {
    expect(() => WeeklyReport.fromJson('nope'), throwsFormatException);
    expect(() => WeeklyReport.fromJson({'weeks': []}), throwsFormatException);
  });
}
