import 'package:patrol/patrol.dart';

import '../screens/login_screen.dart';

/// The reviewer demo account. Invented person, invented class, invented
/// students — see `tsr-account/migrations/2026_09_06_reviewer_demo_cohort.sql`
/// and docs/backend/reviewer-demo-account.md.
const reviewerEmail = 'appreview@demo.invalid';

/// Supplied by scripts/patrol-android.sh from .secrets/reviewer-credentials.env.
/// Never committed, never written into a test file.
const _reviewerPassword = String.fromEnvironment('TSR_REVIEWER_PASSWORD');

/// Signs in as the reviewer demo account.
///
/// The empty-password check is deliberate and is the EARS unwanted-behaviour
/// criterion made real: a missing precondition must announce itself, not
/// surface twenty seconds later as an ordinary wrong-password failure that
/// sends someone debugging the app instead of their setup.
Future<void> signInAsReviewer(PatrolIntegrationTester $) async {
  if (_reviewerPassword.isEmpty) {
    throw StateError(
      'TSR_REVIEWER_PASSWORD is empty. The Firebase user for '
      '$reviewerEmail may not exist yet — see '
      'docs/specs/patrol-integration-testing/plan.md task 3. '
      'Run the suite via scripts/patrol-android.sh, which passes the '
      'password as a --dart-define.',
    );
  }

  final login = LoginScreenObject($);

  // The app opens on Home as a guest (#555); sign-in is one tap away. The
  // wait covers the splash screen on a cold start.
  await login.inviteButton.waitUntilVisible(
    timeout: const Duration(seconds: 30),
  );
  await login.inviteButton.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));

  await login.emailField.enterText(reviewerEmail);
  await login.passwordField.enterText(_reviewerPassword);

  // scrollTo() before tap() is load-bearing. The Sign In button sits below the
  // fold on this form -- a screenshot taken at the moment of failure showed the
  // page scrolled to the logo with only the top edge of the button visible --
  // so a bare tap() times out at Patrol's 10s selector timeout.
  //
  // Two wrong turns worth recording, because both fail quietly:
  //   - The first failure looked like the soft keyboard covering the button.
  //     It was not; the screenshot showed no keyboard at all.
  //   - Submitting via `testTextInput.receiveAction(TextInputAction.done)`
  //     looked like a tidy alternative, since the password field wires
  //     `onFieldSubmitted` to the same handler. On a real device it does
  //     nothing at all: the platform owns the input connection, not the test
  //     framework, so the call completes and no sign-in is attempted. The
  //     giveaway was an empty gap in the log where the Firebase auth lines
  //     should be, not an error.
  await login.signInButton.scrollTo().tap();

  // Android 13+ asks for POST_NOTIFICATIONS with a native dialog the moment
  // sign-in succeeds, because _finishFirebaseSignIn registers the device for
  // push. Nothing in the Flutter tree can dismiss it -- this is the case Patrol
  // exists for. Left alone it does not fail loudly: the app waits, logs
  // "Failed to register device: FCM permission request timed out", and carries
  // on with the dialog still covering the screen, so every later finder fails
  // for a reason that has nothing to do with what is being tested.
  if (await $.platformAutomator.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 10),
  )) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }

  // Sign-in is Firebase plus the backend's /auth/link round-trip, then a
  // classes fetch. Slower than a normal settle allows for.
  await $.pumpAndSettle(timeout: const Duration(seconds: 60));
}
