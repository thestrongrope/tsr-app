import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';

/// The vertical slice.
///
/// Chosen to cross every seam at once: Patrol launch, the Android native
/// runner, emulator-to-host networking over `adb reverse`, the fixture reset,
/// and the `/auth/link` round-trip for a password-provider token — which
/// docs/release-handover.md records as never having been exercised at all.
///
/// **Triage a failure here as a backend question first.** If sign-in fails,
/// capture the `/auth/link` request and response before touching the harness.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer signs in and sees the demo class roster', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);

    // The class is found by name, and located by code rather than id
    // everywhere it matters: the reset drops and rebuilds it, so its
    // autoincrement id changes between runs while the code does not.
    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The class dashboard, not the roster. Tapping the class card opens a
    // dashboard showing the code, name, teacher and schedule; the ten students
    // sit a level deeper behind "Class Conduction". Asserting student names
    // here was this suite's first wrong assumption about the app, and the test
    // now asserts what this screen actually proves: that the teacher UI renders
    // from the seeded cohort rather than from anything the test invented.
    expect(classes.classCodeChip, findsOneWidget,
        reason: 'the class code AYD1 comes from the seeded cohort');
    expect(classes.teacherName, findsOneWidget,
        reason: 'the teacher name is the reviewer account from the migration');
    expect(classes.classConductionAction, findsOneWidget,
        reason: 'teacher-only action, so this also proves the teacher role '
            'resolved from roleid and the conducting enrolment');
  });
}
