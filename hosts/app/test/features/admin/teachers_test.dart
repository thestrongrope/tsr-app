import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/teachers.dart';

Map<String, dynamic> _level(String key, String code) => {
  'key': key,
  'code': code,
  'name': key,
};

Map<String, dynamic> _list({List<dynamic>? teachers}) => {
  'gender': 1,
  'levels': [_level('salman', 'SM'), _level('abuzar', 'AG')],
  'teachers':
      teachers ??
      [
        {
          'token': 7,
          'name': 'Ali',
          'level': 'AMMAR',
          'classes': 2,
          'flags': {'salman': true},
          'conducting': ['A1', 'B2'],
        },
      ],
};

Map<String, dynamic> _detail() => {
  'token': 7,
  'name': 'Ali',
  'email': 'ali@example.test',
  'mobile': null,
  'state': 'MH',
  'city': 'Pune',
  'country': 'India',
  'zip': '411001',
  'trained': true,
  'flags': {'salman': true, 'ammar': true},
  'conducting': [
    {
      'id': 1,
      'code': 'A1',
      'level': 'AMMAR',
      'city': 'Pune',
      'country': 'India',
      'startedOn': '2026-01-01',
      'endedOn': null,
      'comments': null,
      'schedules': ['Monday 19:30 IST'],
    },
  ],
  'conducted': [],
  'attending': [
    {
      'id': 3,
      'code': 'M1',
      'level': 'MIQDAD',
      'teacher': 'Fatima',
      'teacherToken': 5,
      'city': 'Mumbai',
      'country': 'India',
      'startedOn': null,
      'comments': 0,
      'schedules': [],
    },
  ],
  'attended': [],
  'history': [
    {'comments': 'ADD: Imported', 'by': 'Admin A', 'on': '2026-03-03'},
  ],
};

void main() {
  group('TeachersList', () {
    test('reads the envelope, the levels and the rows', () {
      final r = TeachersList.fromJson(_list());

      expect(r.gender, 1);
      expect(r.levels.map((l) => l.code), ['SM', 'AG']);
      final t = r.teachers.single;
      expect(t.token, 7);
      expect(t.classes, 2);
      expect(t.conducting, ['A1', 'B2']);
      expect(t.searchFields, ['Ali', '7', 'A1', 'B2']);
    });

    test('a flag the server left out is false', () {
      final t = TeachersList.fromJson(_list()).teachers.single;

      expect(t.flags, {'salman': true, 'abuzar': false});
      expect(t.isTrainedFor('salman'), isTrue);
      expect(t.isTrainedFor('abuzar'), isFalse);
    });

    test('one odd row does not stop the list loading', () {
      final r = TeachersList.fromJson(
        _list(
          teachers: [
            'junk',
            {'token': 'x', 'name': 0, 'flags': 'nope', 'conducting': 3},
            {'token': 8, 'name': 'Zayd'},
          ],
        ),
      );

      expect(r.teachers.length, 2);
      expect(r.teachers.first.name, '', reason: 'a number is not a name');
      expect(r.teachers.first.flags.values, everyElement(isFalse));
      expect(r.teachers.last.name, 'Zayd');
    });

    test('a body that is not this answer throws', () {
      expect(() => TeachersList.fromJson(null), throwsFormatException);
      expect(() => TeachersList.fromJson([]), throwsFormatException);
      expect(
        () => TeachersList.fromJson({'gender': 1, 'levels': []}),
        throwsFormatException,
      );
    });
  });

  group('TeacherDetail', () {
    test('reads contact details, flags, classes and history', () {
      final d = TeacherDetail.fromJson(_detail());

      expect(d.name, 'Ali');
      expect(d.email, 'ali@example.test');
      expect(d.mobile, isNull);
      expect(d.address, 'Pune, MH, India, 411001');
      expect(d.trained, isTrue);
      expect(d.flags, {
        'salman': true,
        'abuzar': false,
        'miqdad': false,
        'ammar': true,
        'bilal': false,
      });
      final c = d.conducting.single;
      expect(c.startedOn, '2026-01-01');
      expect(c.endedOn, isNull);
      expect(c.place, 'Pune, India');
      expect(c.schedules, ['Monday 19:30 IST']);
      expect(d.history.single.by, 'Admin A');
    });

    test('empty and non-text values are null, not 0 or blank', () {
      final a = TeacherDetail.fromJson(_detail()).attending.single;

      expect(a.teacher, 'Fatima');
      expect(a.teacherToken, 5);
      expect(a.startedOn, isNull);
      expect(a.comments, isNull, reason: 'the server can send 0 for empty');
    });

    test('a body that is not this answer throws', () {
      expect(() => TeacherDetail.fromJson(null), throwsFormatException);
      expect(
        () => TeacherDetail.fromJson({'name': 'x'}),
        throwsFormatException,
      );
    });

    test('missing lists are empty', () {
      final d = TeacherDetail.fromJson({'token': 7, 'flags': {}});

      expect(d.conducting, isEmpty);
      expect(d.history, isEmpty);
      expect(d.address, '');
    });
  });

  test('a change goes out as the server reads it', () {
    expect(
      const TrainingChange(token: 7, level: 'ammar', added: true).toJson(),
      {'token': 7, 'level': 'ammar', 'action': 'added'},
    );
    expect(
      const TrainingChange(
        token: 7,
        level: 'bilal',
        added: false,
      ).toJson()['action'],
      'removed',
    );
  });
}
