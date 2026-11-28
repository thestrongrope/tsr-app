import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/unplaced_registrations.dart';

Map<String, dynamic> _registrant({String name = 'Ali'}) => {
  'name': name,
  'city': 'Dubai',
  'country': 'AE',
  'preferredLocation': 'Online',
  'requestedClass': 'A1',
  'status': 'Accepted',
  'registeredOn': '2026-10-02',
};

void main() {
  test('reads the envelope and each registrant', () {
    final r = UnplacedRegistrations.fromJson({
      'gender': 2,
      'registrants': [_registrant(), _registrant(name: 'Zayd')],
    });

    expect(r.gender, 2);
    expect(r.registrants.map((x) => x.name), ['Ali', 'Zayd']);
    final ali = r.registrants.first;
    expect(ali.city, 'Dubai');
    expect(ali.country, 'AE');
    expect(ali.preferredLocation, 'Online');
    expect(ali.requestedClass, 'A1');
    expect(ali.status, 'Accepted');
    expect(ali.registeredOn, '2026-10-02');
  });

  test('place joins what was given: city and country, one, or none', () {
    Registrant of(String? city, String? country) =>
        Registrant.fromJson({'name': 'A', 'city': city, 'country': country});

    expect(of('Dubai', 'AE').place, 'Dubai, AE');
    expect(of('Dubai', null).place, 'Dubai');
    expect(of(null, 'AE').place, 'AE');
    expect(of(null, null).place, '');
  });

  test('a registrant with nulls reads as empty text, not a crash', () {
    final r = Registrant.fromJson({
      'name': 'Ali',
      'city': null,
      'country': null,
      'preferredLocation': null,
      'requestedClass': null,
      'status': 'Pending',
      'registeredOn': '2026-09-20',
    });

    expect(r.preferredLocation, '');
    expect(r.requestedClass, '');
  });

  test('a body that is not this report throws, so the screen can retry', () {
    expect(
      () => UnplacedRegistrations.fromJson({'gender': 1}),
      throwsFormatException,
    );
    expect(() => UnplacedRegistrations.fromJson('nope'), throwsFormatException);
  });

  test('a row that is not an object is skipped', () {
    final r = UnplacedRegistrations.fromJson({
      'registrants': ['junk', _registrant()],
    });

    expect(r.registrants, hasLength(1));
    expect(r.gender, 1);
  });

  test('reads every detail the web details panel shows', () {
    final r = Registrant.fromJson({
      ..._registrant(),
      'id': 9,
      'token': 1002,
      'email': 'ali@example.test',
      'mobile': '+971500000000',
      'residenceLocation': 'Deira',
      'workLocation': 'Bur Dubai',
      'birthYear': 1990,
      'classLevel': 'Primary',
      'classNumber': '3',
      'profession': 'Engineer',
      'islamicStudyYears': '3',
      'interests': '["Research","Teaching"]',
      'zip': '12345',
    });

    expect(r.id, 9);
    expect(r.token, 1002);
    expect(r.email, 'ali@example.test');
    expect(r.mobile, '+971500000000');
    expect(r.residenceLocation, 'Deira');
    expect(r.workLocation, 'Bur Dubai');
    expect(r.birthYear, 1990);
    expect(r.classLevel, 'Primary');
    expect(r.classNumber, '3');
    expect(r.profession, 'Engineer');
    expect(r.islamicStudyYears, '3');
    expect(r.zip, '12345');
  });

  test('details the server left out are empty, and no birth year is null', () {
    final r = Registrant.fromJson(_registrant());

    expect(r.id, 0);
    expect(r.email, '');
    expect(r.profession, '');
    expect(r.birthYear, isNull);
    expect(r.ageIn(DateTime(2026, 10, 15)), isNull);
  });

  test('age is worked out in the given year, as the web does', () {
    final r = Registrant.fromJson({..._registrant(), 'birthYear': 1990});

    expect(r.ageIn(DateTime(2026, 10, 15)), 36);
  });

  test('interests read as a list from JSON, else from plain text', () {
    List<String> of(String interests) => Registrant.fromJson({
      ..._registrant(),
      'interests': interests,
    }).interestList;

    expect(of('["Research", "Teaching"]'), ['Research', 'Teaching']);
    expect(of('Research, Teaching'), ['Research', 'Teaching']);
    expect(of('["Research", ""]'), ['Research']);
    expect(of(''), isEmpty);
  });

  test('reads the classes a registrant could be placed in', () {
    final classes = PlacementClass.listFromJson({
      'classes': [
        {
          'id': 10,
          'code': 'A1',
          'level': 'Primary',
          'teacher': 'Fatima',
          'location': 'Dubai',
          'students': 12,
        },
        {
          'id': 11,
          'code': 'A2',
          'level': 'Primary',
          'teacher': null,
          'location': null,
          'students': 0,
        },
      ],
    });

    expect(classes.map((c) => c.code), ['A1', 'A2']);
    expect(classes.first.teacher, 'Fatima');
    expect(classes.first.students, 12);
    expect(classes.last.teacher, '');
    expect(classes.last.location, '');
  });

  test('nobody to place them in is an empty list', () {
    expect(PlacementClass.listFromJson({'classes': []}), isEmpty);
  });

  test('classes from a body that is not that answer throw', () {
    expect(() => PlacementClass.listFromJson({}), throwsFormatException);
    expect(() => PlacementClass.listFromJson('nope'), throwsFormatException);
  });
}
