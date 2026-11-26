import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: a gents admin on the Copy MCQ picker (#676).
///
/// A gender admin holds mcqs:copy but not mcqs:manage, so this is their only way
/// to copy a quiz. Opens the picker from the Manage tab and checks the controls:
/// the From class list holds the gents demo classes and no ladies class, and the
/// later steps are not offered until a class is chosen. Never chooses a quiz or
/// presses Copy Quiz: a copy writes a quiz for real.
void main() {
  patrolAppTest('gents admin opens the Copy MCQ picker', ($) async {
    await signInAs($, Persona.gentsAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    const short = Duration(seconds: 15);
    await admin.manageTab.waitUntilVisible(timeout: short);
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Copy MCQ').scrollTo();
    await $('Copy MCQ').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await $('From class').waitUntilVisible(timeout: short);
    expect($('Topic'), findsNothing, reason: 'no class chosen yet');
    expect($('Copy Quiz'), findsNothing, reason: 'no quiz chosen yet');

    await $('From class').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // The gents list is long (150+ classes), so the menu is a lazy list and
    // only builds what is on screen; the order is by level then id, so a demo
    // class may be above or below the others.
    for (final code in ['AYD1', 'AYD2']) {
      expect(
        await revealInOpenMenu($, code),
        isTrue,
        reason: 'the demo class $code must be offered',
      );
    }
    // Only the built rows can be checked, so this catches a ladies class
    // sorted next to the demo classes, not one at the far end of the list.
    expect(
      $(RegExp('^AYP1')),
      findsNothing,
      reason: 'a gents admin must never be offered a ladies class',
    );
  });
}
