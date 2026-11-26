import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/donors.dart';

void main() {
  test('donors parse as the server sends them', () {
    final donors = Donor.listFromJson({
      'donors': [
        {
          'name': 'Ali Raza',
          'email': 'ali@example.test',
          'mobile': '+971500000000',
          'city': 'Dubai',
          'state': null,
          'country': 'AE',
          'zip': null,
        },
      ],
    });

    expect(donors.single.name, 'Ali Raza');
    expect(donors.single.state, '');
    expect(donors.single.place, 'Dubai, AE');
  });

  test('the place leaves out what is missing and ends with the zip', () {
    const donor = Donor(
      name: 'Zayd',
      email: '',
      mobile: '',
      city: 'Mumbai',
      state: 'MH',
      country: 'IN',
      zip: '400001',
    );

    expect(donor.place, 'Mumbai, MH, IN 400001');
  });

  test('one odd field does not stop the list loading', () {
    final donors = Donor.listFromJson({
      'donors': [
        {'name': 0, 'email': 'a@example.test'},
      ],
    });

    expect(donors.single.name, '');
    expect(donors.single.email, 'a@example.test');
  });

  test('a body that is not the list throws, so the screen offers a retry', () {
    expect(() => Donor.listFromJson('oops'), throwsFormatException);
    expect(() => Donor.listFromJson({'donors': 'x'}), throwsFormatException);
  });

  test('search fields are every column the list shows', () {
    const donor = Donor(
      name: 'A',
      email: 'B',
      mobile: 'C',
      city: 'D',
      state: 'E',
      country: 'F',
      zip: 'G',
    );

    expect(donor.searchFields, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
  });
}
