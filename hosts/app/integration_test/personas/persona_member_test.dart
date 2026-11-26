import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/class_list_screen.dart';

/// Persona journey: a member enrolled in AYD1, no role.
///
/// Expected (docs: persona design table): own class on the home screen, a
/// student dashboard (Take Quiz, Performance Overview, Syllabus) and nothing
/// staff or admin. Needs scripts/persona-cohort.sql; run it through
/// scripts/patrol-personas.sh.
void main() {
  patrolAppTest('member sees their own class and no staff or admin surface',
      ($) async {
    await signInAs($, Persona.member);
    final classes = ClassListScreenObject($);
    final admin = AdminSurfaceScreenObject($);

    await refreshHome($);

    // Positive first: the My Classes widget lists AYD1 on the home screen.
    await classes.demoClassCard.waitUntilVisible();
    expect(admin.manageTab, findsNothing);

    await pushRoute($, '/admin');
    expect(admin.title, findsNothing,
        reason: '/admin must redirect a member back home');

    await openTab($, 'Me');
    expect(admin.manageTab, findsNothing);

    // The Me header shows the member's token number, one tap from the tab, and
    // a tap copies it (#1147). The number is the fixture's, so match its shape.
    final token = $(RegExp(r'^Token \d+$'));
    await token.waitUntilVisible();
    await token.tap();
    await $('Token number copied').waitUntilVisible();
    await openMyClasses($);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // One class, so the screen goes straight to its dashboard.
    await classes.demoClassCard.waitUntilVisible();
    expect(classes.managingHeader, findsNothing);
    expect(classes.miqdadClassCard, findsNothing);
    expect($('AYP1'), findsNothing);

    await expectDashboardTiles(
      $,
      conduction: false,
      mcq: false,
      notification: false,
      shareJoinLink: false,
      takeQuiz: true,
      performance: true,
      syllabus: true,
      manageClass: false,
      classStudents: false,
    );
  });
}
