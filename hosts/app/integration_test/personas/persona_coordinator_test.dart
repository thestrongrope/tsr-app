import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/class_list_screen.dart';

/// Persona journey: a class coordinator (roleid 5) whose rule matches AYD1 only
/// (gents, Pune, AMMAR). Not a teacher, not enrolled.
///
/// Expected: only the conduction report in the admin area, the managed class on Home, and with a
/// single managed class the screen opens its dashboard directly, with the
/// conduction and notification tiles but not MCQ Management.
void main() {
  patrolAppTest('coordinator manages exactly one class and reaches only the reports',
      ($) async {
    await signInAs($, Persona.coordinator);
    final classes = ClassListScreenObject($);
    final admin = AdminSurfaceScreenObject($);

    await refreshHome($);

    // A manager who does not attend still sees the class on Home (#801).
    await classes.demoClassCard.waitUntilVisible();

    await expectReportsOnlyAdmin($, mustNotSee: ['AYP1', 'AYD2']);

    await openTab($, 'Me');
    expect(admin.manageTab.exists, isTrue);
    await openMyClasses($);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.demoClassCard.waitUntilVisible();
    expect(classes.managingHeader, findsNothing,
        reason: 'a single class goes straight to its dashboard');
    expect(classes.miqdadClassCard, findsNothing);
    expect($('AYP1'), findsNothing);

    await expectDashboardTiles(
      $,
      conduction: true,
      mcq: false,
      notification: true,
      shareJoinLink: true,
      takeQuiz: false,
      performance: false,
      syllabus: true,
      manageClass: true,
      classStudents: true,
    );
  });
}
