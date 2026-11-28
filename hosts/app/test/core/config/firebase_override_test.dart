import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/config/firebase_override.dart';

void main() {
  const dev = (
    apiKey: 'dev-key',
    appId: '1:1:android:dev',
    senderId: '1',
    projectId: 'tsr-dev',
  );

  test('with nothing set there is no override, in debug or release', () {
    expect(firebaseOverride(release: false, android: true), isNull);
    expect(firebaseOverride(release: true, android: true), isNull);
    expect(firebaseOverride(release: true, android: false), isNull);
  });

  test('a full override in a debug build gives the developer\'s options', () {
    final o = firebaseOverride(
      release: false,
      android: true,
      apiKey: dev.apiKey,
      appId: dev.appId,
      senderId: dev.senderId,
      projectId: dev.projectId,
      storageBucket: 'tsr-dev.appspot.com',
    )!;

    expect(o.projectId, 'tsr-dev');
    expect(o.apiKey, 'dev-key');
    expect(o.appId, '1:1:android:dev');
    expect(o.messagingSenderId, '1');
    expect(o.storageBucket, 'tsr-dev.appspot.com');
  });

  test('the storage bucket is optional', () {
    final o = firebaseOverride(
      release: false,
      android: true,
      apiKey: dev.apiKey,
      appId: dev.appId,
      senderId: dev.senderId,
      projectId: dev.projectId,
    )!;

    expect(o.storageBucket, isNull);
  });

  test('an override in a release build refuses to start', () {
    expect(
      () => firebaseOverride(
        release: true,
        android: true,
        apiKey: dev.apiKey,
        appId: dev.appId,
        senderId: dev.senderId,
        projectId: dev.projectId,
      ),
      throwsStateError,
    );
  });

  test('a partial override refuses to start, naming what is needed', () {
    expect(
      () => firebaseOverride(release: false, android: true, apiKey: 'k'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('PROJECT_ID'),
        ),
      ),
    );
  });

  test('an override off Android refuses to start', () {
    expect(
      () => firebaseOverride(
        release: false,
        android: false,
        apiKey: dev.apiKey,
        appId: dev.appId,
        senderId: dev.senderId,
        projectId: dev.projectId,
      ),
      throwsStateError,
    );
  });
}
