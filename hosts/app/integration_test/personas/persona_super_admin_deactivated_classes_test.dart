import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: the super admin deactivating a class (#618).
///
/// Chooses the disposable invented class AYX1 (scripts/persona-cohort.sql: a gents
/// class in Mumbai with one student), cancels the confirmation once and sees
/// nothing change, then confirms. The class must appear at the top of the
/// deactivated list and in the activity log. Only AYX1 is touched, never a real
/// class.
void main() {
  patrolAppTest('super admin deactivates the disposable class', ($) async {
    await signInAs($, Persona.superAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.deactivatedClassesCard.scrollTo();
    await admin.deactivatedClassesCard.waitUntilVisible();
    await admin.deactivatedClassesCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Deactivate a class').waitUntilVisible();
    // The list itself loaded, from the real data: its count line is there and
    // its error is not (the button above it shows either way).
    await $(RegExp(r'^\d+ deactivated$')).waitUntilVisible();
    expect($('The deactivated classes could not be loaded.'), findsNothing);
    expect($('AYX1 · Completed'), findsNothing, reason: 'not yet deactivated');

    await $('Deactivate a class').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(AppBar).$('Deactivate a class').waitUntilVisible();
    await $(TextField).at(0).waitUntilVisible();
    await $(TextField).at(0).enterText('AYX1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    // The typed text also reads 'AYX1': choose the class card, not the field.
    await $(Card).$('AYX1').waitUntilVisible();
    await $(Card).$('AYX1').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Change').waitUntilVisible();

    await $(TextField).enterText('Patrol journey');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Deactivate class').tap();
    await $('Deactivate this class?').waitUntilVisible();
    await $('1 student will be removed from it.').waitUntilVisible();
    await $('This cannot be undone from the app.').waitUntilVisible();

    // Cancel changes nothing: the form is still there with the class chosen.
    await $('Cancel').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Change').waitUntilVisible();

    await $('Deactivate class').tap();
    await $('Deactivate this class?').waitUntilVisible();
    await $(AlertDialog).$('Deactivate').tap();

    await $(
      'AYX1 deactivated.',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $(
      'AYX1 · Completed',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $('Patrol journey').waitUntilVisible();

    await $('Activity').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('AYX1 · Completed').waitUntilVisible();
  });
}
