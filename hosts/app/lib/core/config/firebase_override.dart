import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase options for a developer's own project (debug builds only), from
/// `--dart-define-from-file=.env.firebase-dev`. The committed
/// `DefaultFirebaseOptions` stay production; this only replaces them when the
/// `TSR_FIREBASE_*` values are given, and refuses to in a release build, so a
/// dev project can never ship. The Android side also needs the project's
/// `google-services.json` in `android/app/src/debug/` (see docs/dev/mobile.md).
///
/// Returns null when no override is given. Throws [StateError] for a partial
/// override, for any override in a release build, and for any other platform than
/// Android (iOS has no override yet).
FirebaseOptions? firebaseOverride({
  required bool release,
  required bool android,
  String apiKey = const String.fromEnvironment('TSR_FIREBASE_API_KEY'),
  String appId = const String.fromEnvironment('TSR_FIREBASE_APP_ID'),
  String senderId = const String.fromEnvironment('TSR_FIREBASE_SENDER_ID'),
  String projectId = const String.fromEnvironment('TSR_FIREBASE_PROJECT_ID'),
  String storageBucket = const String.fromEnvironment(
    'TSR_FIREBASE_STORAGE_BUCKET',
  ),
}) {
  final given = [apiKey, appId, senderId, projectId, storageBucket];
  if (given.every((v) => v.isEmpty)) return null;

  if (release) {
    throw StateError('A Firebase override is set in a release build.');
  }
  if (!android) {
    throw StateError('The Firebase override supports Android only.');
  }
  if ([apiKey, appId, senderId, projectId].any((v) => v.isEmpty)) {
    throw StateError(
      'The Firebase override needs TSR_FIREBASE_API_KEY, _APP_ID, _SENDER_ID '
      'and _PROJECT_ID.',
    );
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}
