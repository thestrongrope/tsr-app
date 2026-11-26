import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/student_transfers.dart';

TransferClass _class(
  int id,
  String code, {
  int gender = 1,
  String level = 'Bilal',
  String? teacher = 'Teacher',
  String? city = 'Mumbai',
  String? country = 'IN',
  bool active = true,
}) => TransferClass(
  id: id,
  code: code,
  name: 'Class $code',
  level: level,
  gender: gender,
  teacher: teacher,
  city: city,
  country: country,
  students: 3,
  active: active,
);

void main() {
  final classes = [
    _class(1, 'AG1'),
    _class(2, 'AG2', level: 'Ammar', teacher: 'Mr Raza'),
    _class(3, 'AG3', active: false, city: 'Dubai', country: 'AE'),
    _class(4, 'LG1', gender: 2, teacher: null),
  ];

  List<int> ids(List<TransferClass> l) => [for (final c in l) c.id];

  group('filterTransferClasses', () {
    test('no filters keeps every class, deactivated ones included', () {
      expect(ids(filterTransferClasses(classes)), [1, 2, 3, 4]);
    });

    test('narrows by gender and by level', () {
      expect(ids(filterTransferClasses(classes, gender: 2)), [4]);
      expect(ids(filterTransferClasses(classes, level: 'Ammar')), [2]);
      expect(ids(filterTransferClasses(classes, gender: 1, level: 'Bilal')), [
        1,
        3,
      ]);
    });

    test('a destination is an active class', () {
      expect(ids(filterTransferClasses(classes, activeOnly: true)), [1, 2, 4]);
    });

    test('searches code, teacher, city and country in any case', () {
      expect(ids(filterTransferClasses(classes, query: 'ag2')), [2]);
      expect(ids(filterTransferClasses(classes, query: 'RAZA')), [2]);
      expect(ids(filterTransferClasses(classes, query: 'dubai')), [3]);
      expect(ids(filterTransferClasses(classes, query: 'ae')), [3]);
      expect(ids(filterTransferClasses(classes, query: 'nowhere')), isEmpty);
    });

    test('a class with no teacher is still found by its code', () {
      expect(ids(filterTransferClasses(classes, query: 'lg1')), [4]);
    });
  });

  group('parsing', () {
    test('the classes answer', () {
      final parsed = TransferClasses.fromJson({
        'classes': [
          {
            'id': 6,
            'code': 'AG3',
            'name': 'Class AG3',
            'level': 'Bilal',
            'gender': 1,
            'teacher': null,
            'city': 'Mumbai',
            'country': 'IN',
            'students': 3,
            'active': false,
          },
        ],
        'levels': ['Bilal'],
      });
      expect(parsed.levels, ['Bilal']);
      expect(parsed.classes.single.active, isFalse);
      expect(parsed.classes.single.teacher, isNull);
      expect(parsed.classes.single.subtitle, 'Bilal · Mumbai · IN');
    });

    test('a body that is not the answer throws', () {
      expect(() => TransferClasses.fromJson('oops'), throwsFormatException);
      expect(() => TransferResult.fromJson(null), throwsFormatException);
    });

    test(
      'a student, with the cohort mark and a search that sees every field',
      () {
        final students = TransferStudent.listFromJson({
          'students': [
            {
              'token': 101,
              'name': 'Ali Raza',
              'email': 'ali@example.test',
              'mobile': '+100',
              'joinedOn': '2026-09-01',
              'removedOn': null,
              'fromDeactivation': true,
            },
          ],
        });
        final s = students.single;
        expect(s.fromDeactivation, isTrue);
        expect(s.matches(''), isTrue);
        expect(s.matches('raza'), isTrue);
        expect(s.matches('101'), isTrue);
        expect(s.matches('EXAMPLE.test'), isTrue);
        expect(s.matches('+100'), isTrue);
        expect(s.matches('zayd'), isFalse);
      },
    );

    test('a move answer names who moved and who did not, with reasons', () {
      final r = TransferResult.fromJson({
        'moved': [
          {'token': 101, 'name': 'Ali'},
        ],
        'failed': [
          {'token': 102, 'name': 'Zayd', 'reason': 'already enrolled'},
          {'token': 999, 'name': null, 'reason': 'not in the source'},
        ],
      });
      expect(r.moved.single.label, 'Ali');
      expect(r.failed[0].reason, 'already enrolled');
      expect(r.failed[1].label, 'Student 999');
    });

    test('a history page', () {
      final page = TransferHistoryPage.fromJson({
        'total': 7,
        'page': 1,
        'pageSize': 50,
        'items': [
          {
            'id': 1,
            'studentToken': 101,
            'studentName': 'Ali',
            'type': 'promotion',
            'fromCode': 'AG1',
            'toCode': 'AG2',
            'reason': null,
            'transferredBy': 'Admin',
            'transferredAt': '2026-10-20T10:00:00',
          },
        ],
      });
      expect(page.total, 7);
      expect(page.items.single.reason, isNull);
      expect(
        page.items.single.transferredAt!.toUtc(),
        DateTime.utc(2026, 10, 20, 10),
      );
    });
  });
}
