import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/manage_class_screen.dart';

/// Persona journey: a class coordinator (roleid 5) managing the one class their
/// rule reaches, AYD1 (#402). The permission boundary, on a device.
///
/// A coordinator holds `classes:update` and `students:enrol` for an assigned
/// class, so they can edit it and remove or restore students. They do **not**
/// hold `class-students:update` (the MCQ-admin flag is the class's teacher's, or
/// the super admin's) or `students:transfer` (super admin only), so those two
/// actions must not be offered at all. The server refuses them regardless; this
/// asserts the app does not even show them.
///
/// Writes nothing: it opens a student's menu and looks, then closes it.
void main() {
  patrolAppTest('coordinator can edit their class but not flag or transfer', (
    $,
  ) async {
    await signInAs($, Persona.coordinator);
    final manage = ManageClassScreenObject($);

    await refreshHome($);
    await openMyClasses($);

    // A single managed class opens its dashboard directly.
    await manage.manageClassTile.waitUntilVisible();
    expect(manage.classStudentsTile, findsWidgets);
    await manage.manageClassTile.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await manage.studentsTab.waitUntilVisible();
    await manage.studentsTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await manage.activeSegment.waitUntilVisible();
    expect(manage.countOf(manage.activeSegment), greaterThan(0));

    expect(
      manage.transfersSegment,
      findsNothing,
      reason: 'transfer history is for the super admin',
    );

    // Add several (#691): offered with students:enrol. Open the dialog and
    // cancel it: this journey adds nobody.
    expect(
      manage.bulkAddButton,
      findsOneWidget,
      reason: 'students:enrol on an assigned class',
    );
    await manage.bulkAddButton.tap();
    await manage.bulkAddField.waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    await $('Cancel').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(manage.bulkAddField, findsNothing);

    await manage.studentMenus.first.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(
      manage.editItem,
      findsOneWidget,
      reason: 'classes:update on an assigned class',
    );
    expect(
      manage.removeItem,
      findsOneWidget,
      reason: 'students:enrol on an assigned class',
    );
    expect(
      manage.makeMcqAdminItem,
      findsNothing,
      reason:
          'the MCQ-admin flag is class-students:update, which a '
          'coordinator does not hold',
    );
    expect(manage.removeMcqAdminItem, findsNothing);
    expect(
      manage.transferItem,
      findsNothing,
      reason: 'students:transfer is the super admin only',
    );
    await $.tester.tapAt(const Offset(5, 5)); // closes the menu, taps nothing
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(find.byType(PopupMenuItem<String>), findsNothing);
  });
}
