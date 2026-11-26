import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/class_list_screen.dart';
import '../screens/teacher_surface_screen.dart';

/// Persona journey: super admin (roleid 1).
///
/// Expected: a persona with the Manage tab,
/// the Notifications and Syllabus Management modules behind it, and every demo
/// class in the Managing list. On AYD1 it gets MCQ Management too.
///
/// Stops before anything is sent: this account holds the broadcast permission
/// and the local stack has FCM credentials. Never tap Send Now or Confirm Send.
void main() {
  patrolAppTest('super admin sees the admin dashboard and every class', (
    $,
  ) async {
    await signInAs($, Persona.superAdmin);
    final classes = ClassListScreenObject($);
    final admin = AdminSurfaceScreenObject($);

    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    expect(classes.demoClassCard, findsNothing);

    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.title.waitUntilVisible();
    await admin.notificationsCard.waitUntilVisible();
    // Reports sits in the Monitoring group, above Syllabus Management: look
    // for it before scrolling the hub down to the lower groups.
    await admin.reportsCard.waitUntilVisible();
    await admin.syllabusManagementCard.scrollTo();
    await admin.syllabusManagementCard.waitUntilVisible();

    await openTab($, 'Me');
    expect(admin.manageTab.exists, isTrue);
    await openMyClasses($);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.managingHeader.waitUntilVisible();
    final seen = await walkClassList($, demoCodes);
    expect(seen, containsAll(['AYD1', 'AYD2', 'AYP1']));

    await openClassFromList($, 'AYD1');
    await expectDashboardTiles(
      $,
      conduction: true,
      mcq: true,
      notification: true,
      shareJoinLink: true,
      takeQuiz: false,
      performance: false,
      syllabus: true,
      manageClass: true,
      classStudents: true,
    );

    // Student Performance (#692): opens on AYD1 with its three views, reads
    // only, and goes back.
    final teacher = TeacherSurfaceScreenObject($);
    // Below the fold on the dashboard, so scroll it into view first.
    await teacher.studentPerformanceTile.scrollTo();
    await teacher.studentPerformanceTile.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    for (final view in ['Attendance', 'MCQ', 'Recitation']) {
      final viewTab = $(Tab).containing(view);
      await viewTab.waitUntilVisible(timeout: const Duration(seconds: 15));
    }
    await popRoute($);
    await teacher.studentPerformanceTile.waitUntilExists(
      timeout: const Duration(seconds: 15),
    );
  });
}
