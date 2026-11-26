import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/config/auth_emulator.dart';

void main() {
  test('an empty value gives no target, in debug or release', () {
    expect(authEmulatorTarget(release: false, value: ''), isNull);
    expect(authEmulatorTarget(release: true, value: ''), isNull);
  });

  test('host:port parses to a host and a port', () {
    final target = authEmulatorTarget(release: false, value: '127.0.0.1:9099')!;

    expect(target.host, '127.0.0.1');
    expect(target.port, 9099);
  });

  test('a release build with any value throws, even a valid one', () {
    expect(
      () => authEmulatorTarget(release: true, value: '127.0.0.1:9099'),
      throwsStateError,
    );
    expect(
      () => authEmulatorTarget(release: true, value: 'garbage'),
      throwsStateError,
    );
  });

  test('a malformed value throws', () {
    for (final bad in [
      'localhost',
      ':9099',
      '127.0.0.1:',
      '127.0.0.1:abc',
      '127.0.0.1:0',
      '127.0.0.1:70000',
      '127.0.0.1:9099:1',
    ]) {
      expect(
        () => authEmulatorTarget(release: false, value: bad),
        throwsStateError,
        reason: bad,
      );
    }
  });
}
