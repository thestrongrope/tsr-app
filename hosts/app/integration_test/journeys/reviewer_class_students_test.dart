import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/manage_class_screen.dart';

/// A class teacher looks at their roster, and only looks (#402).
///
/// The reviewer teaches AYD1. A teacher holds `class-students:read` but not
/// `classes:update`, so the dashboard offers **Class Students** (a read-only
/// roster) and an **Edit class** that sets the schedule only. The roster shows names and tokens only:
/// email and mobile are for whoever can edit the class, so a teacher (or an
/// MCQ-admin student) must never be sent them.
///
/// Reads only.
void main() {
  patrolAppTest(
    'the teacher sees a names-only roster and edits only the schedule',
    ($) async {
      await signInAsReviewer($);
      final classes = ClassListScreenObject($);
      final manage = ManageClassScreenObject($);

      await classes.demoClassCard.waitUntilVisible();
      await classes.demoClassCard.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      // The positive comes first: an absence only means something once the tile
      // that should be there is known to have rendered.
      // scrollTo, not waitUntilVisible: the tile is the last quick action and
      // sits below the fold since Class events joined the list (#975).
      await manage.classStudentsTile.scrollTo();
      // A teacher's Edit class opens the schedule only; the editor's tile also
      // offers the details and the students.
      expect(
        $('Details, schedule and students'),
        findsNothing,
        reason: 'a class teacher may look at the roster, not edit the class',
      );

      await manage.classStudentsTile.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      await $(AppBar).$('Class students').waitUntilVisible();
      expect(
        $(RegExp(r'^Token \d+$')),
        findsWidgets,
        reason: 'the demo class has students, listed by name and token',
      );

      // The demo members' addresses end @demo.invalid and their mobiles are in
      // the 07700 range: neither may reach a teacher's roster.
      expect(
        find.textContaining('@'),
        findsNothing,
        reason: 'no email address on a teacher\'s roster',
      );
      expect(
        find.textContaining('07700'),
        findsNothing,
        reason: 'no mobile number on a teacher\'s roster',
      );
    },
  );
}
