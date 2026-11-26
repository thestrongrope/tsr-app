import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/conduction_screen.dart';

/// The control for `reviewer_conduction_defaults_test.dart`: the conduction add
/// form on an AMMAR class starts with no subject ticked. A default that leaked
/// to every level would pass the MIQDAD half alone and fail here.
///
/// Nothing here saves.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('AMMAR starts with every subject clear', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final conduction = ConductionScreenObject($);

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.classConductionAction.waitUntilVisible();
    await classes.classConductionAction.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await conduction.addRecordButton.waitUntilVisible();
    await conduction.addRecordButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await conduction.addFormTitle.waitUntilVisible();

    await conduction.arabicToggle.scrollTo();
    expect(
      conduction.tickedSubjectCount,
      0,
      reason: 'only MIQDAD defaults its compulsory subjects on',
    );
  });
}
