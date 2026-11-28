import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: the super admin on the Update MCQs screen (#669).
///
/// Opens the screen from the Manage tab and checks the controls: the choices
/// are listed and Update is disabled until a language and a level are ticked.
/// Never presses Update: it replaces the Standard MCQs from the live source
/// sheet, which a journey must not write.
void main() {
  patrolAppTest('super admin opens the Update MCQs screen', ($) async {
    await signInAs($, Persona.superAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    // A long, lazily built list: scroll to the card before tapping.
    await admin.updateMcqsCard.scrollTo();
    await admin.updateMcqsCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await admin.updateMcqsTitle.waitUntilVisible();
    await $('English').waitUntilVisible();
    await $('Abuzar').waitUntilVisible();

    final update = find.byKey(const Key('update-standard-mcqs'));
    expect(
      $.tester.widget<FilledButton>(update).enabled,
      isFalse,
      reason: 'nothing is chosen yet',
    );

    await $('English').tap();
    await $('Abuzar').tap();
    expect(
      $.tester.widget<FilledButton>(update).enabled,
      isTrue,
      reason: 'a language and a level are chosen',
    );

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.title.waitUntilVisible();
  });
}
