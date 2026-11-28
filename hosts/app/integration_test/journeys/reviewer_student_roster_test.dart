import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/conduction_screen.dart';

/// Journey 2 of the verification checklist: **every visible name, number and
/// record belongs to an invented person**.
///
/// The slice stops at the class dashboard and only asserts that the Class
/// Conduction tile exists. This journey is the first thing to tap it, so the
/// conduction list, its provider and the add form's form-data endpoint are all
/// first contact. Per design.md, **triage a failure here as a backend question
/// first** — capture the request and response before touching a finder.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer sees the ten invented students', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final conduction = ConductionScreenObject($);

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.classConductionAction.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // Arrival, and the tap target for the roster.
    await conduction.addRecordButton.waitUntilVisible();
    await conduction.addRecordButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // These are Patrol waits rather than bare `expect`s, and deliberately so.
    // A failing `expect` inside a Patrol test does not report its `reason:` —
    // it surfaces only as `_pendingExceptionDetails != null` in logcat and
    // then hangs the runner, so the one thing a red run must tell you, which
    // assertion failed, is exactly what is lost. A failing wait is logged as a
    // named step carrying its own finder text. See plan.md task 12.
    await conduction.rosterCountChip.waitUntilVisible();

    for (final name in ConductionScreenObject.demoStudentNames) {
      await conduction.studentNamed(name).waitUntilExists();
    }

    // The eleventh row. The reviewer is enrolled in their own class, so they
    // appear in their own attendance list — which is why the chip above reads
    // eleven and not ten, and is what a store reviewer will see too.
    //
    // Two widgets, not one: the add form prints the teacher's name in its
    // class card as well as in the roster below it.
    expect(conduction.studentNamed(ClassListScreenObject.demoTeacherName),
        findsNWidgets(2),
        reason: 'the reviewer teaches this class and is enrolled in it, so '
            'the name appears in the class card and again as a roster row');

    // The waits above are satisfied off-screen, because the attendance sheet
    // is a Column and not a lazy list. Scrolling to the last name is what
    // proves the rows actually render rather than merely existing.
    await conduction
        .studentNamed(ConductionScreenObject.demoStudentNames.last)
        .scrollTo();
  });
}
