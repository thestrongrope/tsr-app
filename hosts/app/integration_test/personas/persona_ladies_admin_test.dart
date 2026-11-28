import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/class_list_screen.dart';
import '../screens/manage_class_screen.dart';
import '../screens/teacher_surface_screen.dart';

/// Persona journey: ladies admin (roleid 4, gender 2).
///
/// Expected: manages the ladies class AYP1 and neither demo gents class, with only
/// the conduction report in the admin area. This is the gender-segregation check on a device.
void main() {
  patrolAppTest('ladies admin manages ladies classes only', ($) async {
    await signInAs($, Persona.ladiesAdmin);
    final classes = ClassListScreenObject($);
    final admin = AdminSurfaceScreenObject($);

    await refreshHome($);

    await expectReportsOnlyAdmin(
      $,
      mustNotSee: ['AYD1', 'AYD2'],
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
    expect(seen, contains('AYP1'));
    expect(seen, isNot(contains('AYD1')),
        reason: 'a ladies admin must never see a gents class');
    expect(seen, isNot(contains('AYD2')),
        reason: 'a ladies admin must never see a gents class');

    // Manage Class (#402): classes:update on a ladies class, offered to the
    // ladies admin. The syllabus tile is shown to every role, so it is waited
    // for first: the absence below only means something once the dashboard has
    // rendered.
    await openClassFromList($, 'AYP1');
    await TeacherSurfaceScreenObject($).syllabusTile.waitUntilExists();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(ManageClassScreenObject($).manageClassTile, findsWidgets,
        reason: 'a ladies admin holds classes:update on a ladies class');
    expect(ManageClassScreenObject($).classStudentsTile, findsWidgets,
        reason: 'an admin gets a direct way to the students as well');
  });
}
