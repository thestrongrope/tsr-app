import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: the super admin on the Quiz admin screen (#673).
///
/// The persona is granted `quiz:admin` (and not `quiz:reset`) by
/// scripts/persona-cohort.sql. Opens the screen from the Manage tab and checks
/// the controls exist: settings with Refresh, Download, the draw actions, and
/// no delete-all.
///
/// Taps nothing on the screen. Refresh, Download, Generate, Regenerate,
/// Publish, Reset and every confirmation write state or call Google Sheets, and
/// a journey must do neither.
void main() {
  patrolAppTest('super admin opens the Quiz admin screen', ($) async {
    await signInAs($, Persona.superAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    // A long, lazily built list: scroll to the card before tapping.
    await admin.quizAdminCard.scrollTo();
    await admin.quizAdminCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await admin.quizAdminTitle.waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    // The screen is one plain scroll view, so absent means absent. Each control
    // is scrolled to before it is asserted, and none is tapped.
    for (final label in ['Refresh settings', 'Download submissions']) {
      await $(label).scrollTo();
      await $(label).waitUntilVisible(timeout: const Duration(seconds: 10));
    }

    // Mega draws the daily winners and Grand draws its own, whichever the
    // local settings hold.
    final draw = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data == 'Generate daily winners' ||
              w.data == 'Generate Grand winners'),
    );
    expect(draw, findsOneWidget, reason: 'the quiz kind has a draw action');

    expect(
      find.text('Delete all quiz data'),
      findsNothing,
      reason: 'this persona holds quiz:admin and not quiz:reset',
    );

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.title.waitUntilVisible();
  });
}
