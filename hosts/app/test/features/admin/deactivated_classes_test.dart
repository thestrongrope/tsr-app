import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/deactivated_classes.dart';

Map<String, dynamic> _class({String code = 'MK1'}) => {
  'id': 4,
  'code': code,
  'level': 'MIQDAD',
  'gender': 1,
  'teacher': 'Ali',
  'type': 'shutdown',
  'effectiveDate': '2026-09-01',
  'reason': 'Low turnout',
  'performedBy': 'Admin A',
  'performedAt': '2026-09-02T10:00:00Z',
};

Map<String, dynamic> _entry() => {
  'id': 2,
  'code': 'MK1',
  'level': 'MIQDAD',
  'gender': 1,
  'type': 'completed',
  'effectiveDate': '2026-09-01',
  'reason': 'Done',
  'performedBy': 'Admin A',
  'performedAt': '2026-09-02T10:00:00Z',
};

void main() {
  test('reads the envelope, the classes and the log', () {
    final r = DeactivatedClasses.fromJson({
      'deactivated': [_class(), _class(code: 'MK2')],
      'log': [_entry()],
    });

    expect(r.deactivated.map((c) => c.code), ['MK1', 'MK2']);
    final c = r.deactivated.first;
    expect(c.id, 4);
    expect(c.level, 'MIQDAD');
    expect(c.teacher, 'Ali');
    expect(c.type, 'shutdown');
    expect(c.effectiveDate, '2026-09-01');
    expect(c.reason, 'Low turnout');
    expect(c.performedBy, 'Admin A');
    expect(r.log.single.code, 'MK1');
    expect(r.log.single.type, 'completed');
  });

  test('a time is read as UTC, never as local', () {
    final c = DeactivatedClass.fromJson(_class());

    expect(c.performedAt, DateTime.utc(2026, 9, 2, 10));
    expect(c.performedAt!.isUtc, isTrue);
  });

  test('a missing or unreadable time is null, not a crash', () {
    expect(
      DeactivatedClass.fromJson({..._class(), 'performedAt': null}).performedAt,
      isNull,
    );
    expect(
      DeactivatedClass.fromJson({
        ..._class(),
        'performedAt': 'soon',
      }).performedAt,
      isNull,
    );
    expect(
      DeactivationLogEntry.fromJson(
        {..._entry()}..remove('performedAt'),
      ).performedAt,
      isNull,
    );
  });

  test(
    'a reason that arrives as a number or null reads as empty, not a crash',
    () {
      for (final reason in [0, null]) {
        final r = DeactivatedClasses.fromJson({
          'deactivated': [
            {..._class(), 'reason': reason},
          ],
          'log': [
            {..._entry(), 'reason': reason},
          ],
        });

        expect(r.deactivated.single.reason, '', reason: '$reason');
        expect(r.log.single.reason, '', reason: '$reason');
      }
    },
  );

  test('a row with nothing in it reads as empty text', () {
    final c = DeactivatedClass.fromJson({'id': 9});

    expect(c.code, '');
    expect(c.teacher, '');
    expect(c.reason, '');
    expect(c.genderName, '');
    expect(c.typeName, '');
  });

  test('gender and type read as words', () {
    expect(genderLabel(1), 'Gents');
    expect(genderLabel(2), 'Ladies');
    expect(genderLabel(0), '');
    expect(deactivationTypeLabel('completed'), 'Completed');
    expect(deactivationTypeLabel('shutdown'), 'Shutdown');
    expect(deactivationTypeLabel('other'), 'other');
  });

  test('a search looks in the same fields as the web table', () {
    final c = DeactivatedClass.fromJson(_class());

    expect(
      c.searchFields,
      containsAll([
        'MK1',
        'MIQDAD',
        'Gents',
        'Ali',
        'shutdown',
        '2026-09-01',
        'Low turnout',
        'Admin A',
      ]),
    );
  });

  test('a row that is not an object is skipped', () {
    final r = DeactivatedClasses.fromJson({
      'deactivated': ['junk', _class()],
      'log': [5],
    });

    expect(r.deactivated, hasLength(1));
    expect(r.log, isEmpty);
  });

  test('a body that is not this answer throws, so the screen can retry', () {
    expect(
      () => DeactivatedClasses.fromJson({'deactivated': []}),
      throwsFormatException,
    );
    expect(() => DeactivatedClasses.fromJson('nope'), throwsFormatException);
  });

  test('reads the candidates with what the confirmation shows', () {
    final list = DeactivationCandidate.listFromJson({
      'classes': [
        {
          'id': 7,
          'code': 'AB2',
          'level': 'AMMAR',
          'gender': 2,
          'teacher': 'Zainab',
          'city': 'Dubai',
          'students': 12,
        },
        {'id': 8, 'code': 'AB3', 'gender': 1},
      ],
    });

    expect(list.first.students, 12);
    expect(list.first.summary, 'AMMAR · Ladies · Zainab · Dubai');
    expect(list.first.searchFields, [
      'AB2',
      'AMMAR',
      'Ladies',
      'Zainab',
      'Dubai',
    ]);
    expect(list.last.summary, 'Gents', reason: 'what is unknown is left out');
    expect(list.last.students, 0);
  });

  test('candidates from a body that is not that answer throw', () {
    expect(() => DeactivationCandidate.listFromJson({}), throwsFormatException);
    expect(
      () => DeactivationCandidate.listFromJson('x'),
      throwsFormatException,
    );
    expect(DeactivationCandidate.listFromJson({'classes': []}), isEmpty);
  });
}
