import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';

Map<String, dynamic> _json(String? role) => {
  'id': 10,
  'code': 'C10',
  'name': 'Class 10',
  'level': 1,
  'gender': 2,
  'status': 'A',
  'role': role,
};

void main() {
  test('managing is neither conducting nor attending', () {
    final cls = ClassModel.fromJson(_json('managing'));
    expect(cls.isManaging, isTrue);
    expect(cls.isConducting, isFalse);
    expect(cls.isAttending, isFalse);
    expect(cls.isStaff, isTrue);
  });

  test('conducting is staff, not attending', () {
    final cls = ClassModel.fromJson(_json('conducting'));
    expect(cls.isConducting, isTrue);
    expect(cls.isManaging, isFalse);
    expect(cls.isAttending, isFalse);
    expect(cls.isStaff, isTrue);
  });

  test('attending and a missing role are attending, not staff', () {
    for (final role in ['attending', null]) {
      final cls = ClassModel.fromJson(_json(role));
      expect(cls.isAttending, isTrue);
      expect(cls.isStaff, isFalse);
    }
  });

  test('gender carries the same values as scopes.gender', () {
    final cls = ClassModel.fromJson(_json('managing'));
    expect(cls.gender, 2);
    expect(cls.isLadies, isTrue);
  });
}
