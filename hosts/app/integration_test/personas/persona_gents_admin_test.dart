import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/class_list_screen.dart';

/// Persona journey: gents admin (roleid 3, gender 1).
///
/// Expected: manages every gents class (AYD1, AYD2) and no ladies class (AYP1),
/// with only the Reports entry in the admin area. The device walk covers the whole list; the
/// host-side probe in scripts/patrol-personas.sh checks the same from the API.
void main() {
  patrolAppTest('gents admin manages gents classes only', ($) async {
    await signInAs($, Persona.gentsAdmin);
    final classes = ClassListScreenObject($);
    final admin = AdminSurfaceScreenObject($);

    await refreshHome($);

    await expectReportsOnlyAdmin(
      $,
      mustNotSee: ['AYP1'],
      shareFile: true,
      leaderboard: true,
      registrations: true,
      teachers: true,
    );
    expect(classes.demoClassCard, findsNothing);

    await openTab($, 'Me');
    expect(admin.manageTab.exists, isTrue);
    await openMyClasses($);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.managingHeader.waitUntilVisible();
    final seen = await walkClassList($, demoCodes);
    expect(seen, containsAll(['AYD1', 'AYD2']));
    expect(
      seen,
      isNot(contains('AYP1')),
      reason: 'a gents admin must never see a ladies class',
    );

    // A manager sees each managed class's student count and the totals for
    // its level; narrowing to one class recounts them (#690).
    await searchClassList($, 'AYD1');
    expect(
      textMatching(RegExp(r'^\d+ students?$')),
      findsOneWidget,
      reason: 'the managed class shows its student count',
    );
    expect(
      textMatching(RegExp(r'^AMMAR: 1 class, \d+ students?$')),
      findsOneWidget,
      reason: 'the level total is recounted from the classes that match',
    );
    await searchClassList($, '');

    await openClassFromList($, 'AYD1');
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
