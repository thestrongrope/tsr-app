import 'package:patrol/patrol.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/mcq_offline_screen.dart';
import '../screens/teacher_surface_screen.dart';

/// Journey for recording offline MCQ answers (#409): a teacher opens a
/// published MCQ's Offline action, chooses a student, and reaches the first
/// question with its correct answer shown and a checkbox for who got it right.
///
/// The demo students have `@demo.invalid` emails, so none counts as "without a
/// phone": the picker opens empty, and the journey turns on "Show all students"
/// first, which is itself part of what it proves.
///
/// **Writes nothing.** It stops before saving: recording only touches the
/// device, and submitting is covered by the PHP and widget tests. It never taps
/// the question-sheet action, which opens the system share sheet.
///
/// Assertions are Patrol waits or a thrown `StateError`, never `expect`: a
/// failing `expect` inside a Patrol test hangs until the watchdog without
/// reporting its reason.
void main() {
  patrolAppTest('reviewer reaches the first offline question for a student', (
    $,
  ) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final teacher = TeacherSurfaceScreenObject($);
    final offline = McqOfflineScreenObject($);

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await teacher.mcqManageTile.scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await teacher.mcqManageTitle.waitUntilVisible();

    await offline.offlineAction.scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // No student has an internal email, so everyone is hidden until asked for.
    await offline.showAllSwitch.waitUntilVisible();
    await offline.showAllSwitch.tap();
    await $.pumpAndSettle();

    await offline.firstStudent.waitUntilVisible();
    await offline.firstStudent.tap();
    await $.pumpAndSettle();
    await offline.recordButton.waitUntilVisible();
    await offline.recordButton.tap();
    await $.pumpAndSettle();

    await offline.firstQuestionTitle.waitUntilVisible();
    await offline.whoAnswered.waitUntilVisible();
  });
}
