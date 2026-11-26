import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/main.dart' as app;

/// Launches the real app and waits for it to settle, then runs [body].
///
/// Every journey goes through here rather than calling `patrolTest` directly,
/// so that launch behaviour is defined once. `main()` is synchronous — it does
/// the binding setup and `runApp` — while the heavy work (Firebase, Hive,
/// notifications) happens behind `appInitializationProvider`, so the first
/// frame arrives before initialisation finishes and the settle below is what
/// waits for it.
///
/// See docs/specs/patrol-integration-testing/design.md
void patrolAppTest(
  String description,
  Future<void> Function(PatrolIntegrationTester $) body,
) {
  patrolTest(description, ($) async {
    // The app's initialisation points FlutterError.onError and
    // PlatformDispatcher.onError at Crashlytics. In a test that swallows every
    // failed expect(): flutter_test reports "A test overrode
    // FlutterError.onError", the failure never reaches Patrol, and the run
    // waits out its time limit with no message (#943). Keep the test
    // framework's handler and put it back once the app has installed its own.
    final testErrorHandler = FlutterError.onError;

    app.main();

    // Generous: a cold start does Firebase init, Hive box opening and a first
    // API call over the adb-reversed port. The default settle timeout is not
    // enough on a freshly booted emulator.
    await $.pumpAndSettle(timeout: const Duration(seconds: 60));

    // Initialisation runs behind the first frame, so the settle may return
    // before the app has installed its handlers. Wait for that (bounded), then
    // restore. Crashlytics is never called after this point.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (identical(FlutterError.onError, testErrorHandler) &&
        DateTime.now().isBefore(deadline)) {
      await $.tester.pump(const Duration(milliseconds: 200));
    }
    FlutterError.onError = testErrorHandler;
    PlatformDispatcher.instance.onError = null;

    await body($);
  });
}
