import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/this_week.dart';

// The answer of `GET /reports/this-week` and `GET /reports/this-week/class/{id}`
// (#615), as the server sends them.

Map<String, dynamic> _row({String? mobile = '+910000000'}) => {
  'classId': 5,
  'code': 'A1',
  'level': 'MIQDAD',
  'teacher': 'Teacher T',
  'teacherToken': 105,
  'teacherMobile': mobile,
  'detail': 'No class for 2 weeks',
  'action': 'message',
  'quiet': [
    {'subject': 'ahkam', 'weeks': 2},
  ],
};

Map<String, dynamic> _screen() => {
  'gender': 1,
  'week': {'from': '2026-10-11', 'to': '2026-10-17'},
  'summary': <String, dynamic>{
    'met': 3,
    'of': 4,
    'formsMissing': 1,
    'attendance': 0.62,
    'flagged': 2,
  },
  'stages': {
    'cform': <dynamic>[],
    'conduction': [_row()],
    'attendance': <dynamic>[],
    'alignment': [_row(mobile: null)],
    'met': [_row(mobile: null)],
    'attended': [_row(mobile: null)],
  },
};

void main() {
  test('the screen parses its summary, week and stages', () {
    final screen = ThisWeek.fromJson(_screen());

    expect(screen.gender, 1);
    expect(screen.weekFrom, '2026-10-11');
    expect(screen.weekTo, '2026-10-17');
    expect(screen.summary.met, 3);
    expect(screen.summary.total, 4);
    expect(screen.summary.formsMissing, 1);
    expect(screen.summary.attendance, 0.62);
    expect(screen.summary.flagged, 2);
    expect(screen.cform, isEmpty);
    expect(screen.conduction.single.code, 'A1');
    expect(screen.conduction.single.quiet.single.subject, 'ahkam');
    expect(screen.conduction.single.quiet.single.weeks, 2);
    expect(screen.met.single.code, 'A1');
    expect(screen.attended.single.code, 'A1');
  });

  test('an answer without the met and attended stages has none', () {
    final body = _screen();
    (body['stages'] as Map<String, dynamic>)
      ..remove('met')
      ..remove('attended');

    final screen = ThisWeek.fromJson(body);

    expect(screen.met, isEmpty);
    expect(screen.attended, isEmpty);
  });

  test('a row with no teacher number has none', () {
    final screen = ThisWeek.fromJson(_screen());

    expect(screen.conduction.single.teacherMobile, '+910000000');
    expect(screen.alignment.single.teacherMobile, isNull);
  });

  test('attendance can be absent', () {
    final json = _screen();
    (json['summary'] as Map<String, dynamic>)['attendance'] = null;

    expect(ThisWeek.fromJson(json).summary.attendance, isNull);
  });

  test('a body that is not the screen throws so the screen can retry', () {
    expect(() => ThisWeek.fromJson('nope'), throwsFormatException);
    expect(() => ThisWeek.fromJson({'gender': 1}), throwsFormatException);
  });

  test('a class alignment parses its weeks, topics and chart', () {
    final a = ClassAlignment.fromJson({
      'classId': 7,
      'code': 'A1',
      'level': 'MIQDAD',
      'weeks': [
        {
          'from': '2026-10-11',
          'to': '2026-10-17',
          'status': 'taught',
          'subjects': {'ahkam': 'Wuzu'},
        },
        {
          'from': '2026-10-04',
          'to': '2026-10-10',
          'status': 'no form',
          'subjects': <String, dynamic>{},
        },
      ],
      'chart': {
        'ahkam': {
          'Wuzu': ['Step one'],
        },
      },
    });

    expect(a.weeks.map((w) => w.status), ['taught', 'no form']);
    expect(a.weeks.first.subjects, {'ahkam': 'Wuzu'});
    expect(a.weeks.last.subjects, isEmpty);
    expect(a.chart, isNotNull);
  });

  test('a level with no chart has a null chart', () {
    final a = ClassAlignment.fromJson({
      'classId': 7,
      'code': 'B1',
      'level': 'AMMAR',
      'weeks': <dynamic>[],
      'chart': null,
    });

    expect(a.chart, isNull);
  });

  group('dialableNumber', () {
    test('a bare ten-digit number is an Indian number', () {
      expect(dialableNumber('9000000001'), '919000000001');
    });

    test('a plus, spaces and punctuation are dropped', () {
      expect(dialableNumber('+91 90000-00001'), '919000000001');
      expect(dialableNumber('+971 50 000 0000'), '971500000000');
    });

    test('one leading zero is dropped before the country code is added', () {
      expect(dialableNumber('09000000001'), '919000000001');
    });

    test('a number with a plus keeps its own country code at any length', () {
      expect(dialableNumber('+6591234567'), '6591234567');
      expect(dialableNumber('+13125550100'), '13125550100');
    });

    test('nothing usable is empty', () {
      expect(dialableNumber(''), '');
      expect(dialableNumber('n/a'), '');
    });
  });
}
