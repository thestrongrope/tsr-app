import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/manage_class_screen.dart';

/// Persona journey: the super admin (roleid 1) manages a class from the app
/// (#402, #403), the mobile counterpart of the web's edit-class page.
///
/// Walks the three tabs on AYD1: edit a detail and save it, add a weekly slot
/// and save it, then on the Students tab remove a student and restore them from
/// the Removed list (which only works since #525), and make a student an MCQ
/// admin. It also asserts the actions only the super admin has (Transfer).
///
/// **Writes only to the invented demo cohort**, and the runner rebuilds the
/// cohort before every journey (`scripts/patrol-personas.sh`), so nothing here
/// needs undoing. Stops short of a transfer: the dialog is asserted present but
/// not completed, so no student moves between demo classes.
///
/// **A failure in Quiz takers depends on the cohort.** That view only exists when
/// someone who took AYD1's quizzes is not enrolled; the journey adds one when it
/// is offered and says so in the log when it is not.
void main() {
  patrolAppTest('super admin edits a class, its schedule and its students', (
    $,
  ) async {
    await signInAs($, Persona.superAdmin);
    final manage = ManageClassScreenObject($);

    await refreshHome($);
    await openMyClasses($);
    await openClassFromList($, 'AYD1');

    // The dashboard offers Manage Class, and Class Students straight to the
    // manage screen's Students tab, not the teacher's read-only roster.
    await manage.manageClassTile.waitUntilVisible();
    // Below the fold since the class events card was added to the dashboard.
    await manage.classStudentsTile.scrollTo();
    await manage.classStudentsTile.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await manage.activeSegment.waitUntilVisible();
    expect(
      manage.studentMenus,
      findsWidgets,
      reason: 'an admin lands on the editable Students tab, not the roster',
    );
    await popRoute($);
    await manage.manageClassTile.waitUntilVisible();
    await manage.manageClassTile.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // --- Details: edit and save, then reopen to see it stored ---------------
    const newCity = 'Patrol Test City';
    await manage.detailsTab.waitUntilVisible();
    await manage.cityField.scrollTo();
    await manage.cityField.enterText(newCity);
    await manage.saveButton.waitUntilVisible();
    await manage.saveButton.tap();
    await manage.savedMessage.waitUntilVisible();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      manage.saveButton,
      findsNothing,
      reason: 'nothing is unsaved after a successful save',
    );

    await popRoute($);
    await manage.manageClassTile.waitUntilVisible();
    await manage.manageClassTile.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await manage.detailsTab.waitUntilVisible();
    expect(
      $(newCity),
      findsWidgets,
      reason: 'the city is read back from the server, not kept locally',
    );

    // --- Schedule: add a weekly slot and save it ----------------------------
    await manage.scheduleTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    final slotsBefore = manage.removeDayButtons.evaluate().length;
    await manage.addDayButton.scrollTo();
    await manage.addDayButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(manage.removeDayButtons.evaluate().length, slotsBefore + 1);
    await manage.saveButton.waitUntilVisible();
    await manage.saveButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(manage.saveButton, findsNothing);
    expect(
      manage.removeDayButtons.evaluate().length,
      slotsBefore + 1,
      reason: 'the new slot survives the reload that follows a save',
    );

    // --- Students: remove, then restore from the Removed list ---------------
    await manage.studentsTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await manage.activeSegment.waitUntilVisible();
    final activeBefore = manage.countOf(manage.activeSegment);
    final removedBefore = manage.countOf(manage.removedSegment);
    expect(activeBefore, greaterThan(0), reason: 'the demo class has students');

    // Add several (#691): offered with students:enrol. Open the dialog and
    // cancel it: this journey adds nobody.
    expect(
      manage.bulkAddButton,
      findsOneWidget,
      reason: 'students:enrol on an any class',
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
    await manage.removeItem.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await manage.reasonField.enterText('Patrol journey removal');
    await manage.confirmRemoveButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // pumpAndSettle returns when the UI stops animating, not when the request
    // finishes, so wait for the reloaded counts instead of reading them at once.
    await $(
      'Active (${activeBefore - 1})',
    ).waitUntilExists(timeout: const Duration(seconds: 20));
    await $(
      'Removed (${removedBefore + 1})',
    ).waitUntilExists(timeout: const Duration(seconds: 20));
    expect(manage.countOf(manage.activeSegment), activeBefore - 1);
    expect(
      manage.countOf(manage.removedSegment),
      removedBefore + 1,
      reason: 'a student removed today is on the Removed list (#525)',
    );

    await manage.removedSegment.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await manage.restoreButton.first.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(
      'Active ($activeBefore)',
    ).waitUntilExists(timeout: const Duration(seconds: 20));
    await $(
      'Removed ($removedBefore)',
    ).waitUntilExists(timeout: const Duration(seconds: 20));
    expect(manage.countOf(manage.activeSegment), activeBefore);
    expect(manage.countOf(manage.removedSegment), removedBefore);

    // --- MCQ admin flag, and the actions only the super admin has -----------
    await manage.activeSegment.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await manage.studentMenus.first.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await manage.makeMcqAdminItem.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await manage.mcqAdminBadge.waitUntilExists(
      timeout: const Duration(seconds: 20),
    );

    await manage.studentMenus.first.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(
      manage.removeMcqAdminItem,
      findsOneWidget,
      reason: 'the flag is on now, so the menu offers to take it off',
    );
    expect(
      manage.transferItem,
      findsOneWidget,
      reason: 'only the super admin holds students:transfer',
    );
    expect(manage.editItem, findsOneWidget);
    await $.tester.tapAt(const Offset(5, 5)); // closes the menu, taps nothing
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(manage.transfersSegment, findsOneWidget);

    // --- Quiz takers: add one when the cohort offers it ---------------------
    if (manage.quizTakersSegment.exists) {
      await manage.quizTakersSegment.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await manage.addButton.first.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));
      await $(
        'Active (${activeBefore + 1})',
      ).waitUntilExists(timeout: const Duration(seconds: 20));
      expect(
        manage.countOf(manage.activeSegment),
        activeBefore + 1,
        reason: 'adding a quiz taker enrols them (#403)',
      );
    } else {
      // ignore: avoid_print
      print('no quiz takers outside the roster: add-a-student not exercised');
    }
  });
}
