import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/class_create.dart';

void main() {
  test('the create options parse as the server sends them', () {
    final options = CreateClassOptions.fromJson({
      'genders': [1, 2],
      'tags': [
        {'id': 3, 'name': 'Kids'},
      ],
      'timezones': [
        {'timezone': 'Asia/Kolkata', 'label': 'India'},
      ],
    });

    expect(options.genders, [1, 2]);
    expect(options.tags.single.name, 'Kids');
    expect(options.timezones.single.timezone, 'Asia/Kolkata');
  });

  test(
    'a body that is not the options throws, so the screen offers a retry',
    () {
      expect(() => CreateClassOptions.fromJson('oops'), throwsFormatException);
      expect(
        () => CreateClassOptions.fromJson({'genders': 'x'}),
        throwsA(anything),
      );
    },
  );
}
