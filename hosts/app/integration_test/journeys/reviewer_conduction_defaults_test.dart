import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/conduction_screen.dart';

/// The conduction add form: its duration buttons, and which subjects start
/// ticked.
///
/// **Duration.** Hours (0-4) and Minutes (0, 15, 30, 45) are two rows of
/// buttons, as on the web form, and they add up: 2 hours then 30 minutes is
/// `150 min`. Changing the hours keeps the minutes.
///
/// **Subjects.** A MIQDAD class starts with its four compulsory subjects
/// (Arabic, Aqaed, Ahkam, Akhlaq) ticked. Any other level starts with none, so
/// the same form on the AMMAR class is the control: a default that leaked to
/// every level would pass the MIQDAD half alone.
///
/// Nothing here saves. The form is read and tapped, and the test ends.
///
/// The control, the same form on the AMMAR class with nothing ticked, is
/// `reviewer_conduction_ammar_defaults_test.dart`: Patrol completes one test per
/// file, so it cannot share this one.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('MIQDAD starts with its four compulsory subjects ticked and '
      'the duration buttons add up', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final conduction = ConductionScreenObject($);

    await classes.miqdadClassCard.waitUntilVisible();
    await classes.miqdadClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.classConductionAction.waitUntilVisible();
    await classes.classConductionAction.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await conduction.addRecordButton.waitUntilVisible();
    await conduction.addRecordButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await conduction.addFormTitle.waitUntilVisible();

    // Duration. Each step waits for the total rather than reading it at once.
    // A failed `expect` inside a Patrol test hangs the run instead of
    // reporting its reason, so the steps that matter are waits.
    await conduction.durationTotal(60).waitUntilExists();

    await conduction.durationHour(2).scrollTo();
    await conduction.durationHour(2).tap();
    await conduction.durationTotal(120).waitUntilExists();

    await conduction.durationMinute(30).scrollTo();
    await conduction.durationMinute(30).tap();
    await conduction.durationTotal(150).waitUntilExists();

    await conduction.durationHour(4).scrollTo();
    await conduction.durationHour(4).tap();
    await conduction.durationTotal(270).waitUntilExists();

    // Subjects: scroll to the last one so the whole group is built.
    await conduction.arabicToggle.scrollTo();
    expect(
      conduction.tickedSubjectCount,
      4,
      reason: 'MIQDAD starts with Arabic, Aqaed, Ahkam and Akhlaq ticked',
    );
  });
}
