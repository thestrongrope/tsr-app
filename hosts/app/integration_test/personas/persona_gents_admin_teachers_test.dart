import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a gents admin (roleid 3) on the teachers screen (#622).
///
/// Sees the gents teachers and no ladies one, and is not offered the gender. Edits
/// only the invented "Persona Teach Gents" (scripts/persona-cohort.sql): switches
/// Ammar on, checks the Changed list, saves with a comment, and finds the change in
/// the teacher's detail and history. Opens the Import dialog and cancels: never
/// imports, which would add rows for real teachers.
void main() {
  patrolAppTest('gents admin edits an invented teacher and reads the history', (
    $,
  ) async {
    await signInAs($, Persona.gentsAdmin);
    await refreshHome($);
    await openPersonaTeachers($);

    await $('Persona Teach Gents').waitUntilVisible();
    expect(
      $('Persona Teach Ladies'),
      findsNothing,
      reason: 'a gents admin must never see a ladies teacher',
    );
    expect(
      $('Ladies'),
      findsNothing,
      reason: 'the gender is not theirs to pick',
    );
    await $(
      'SM Salman · AG Abuzar · MK Miqdad · AY Ammar · BL Bilal',
    ).waitUntilVisible();

    // The Import dialog explains itself and cancelling runs nothing.
    await $(PopupMenuButton<String>).tap();
    await $('Import active teachers').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $(
      RegExp('^Adds every teacher of an active class'),
    ).waitUntilVisible();
    await $(AlertDialog).$('Cancel').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $('Edit').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Changed: 0').waitUntilVisible();
    // The search left the one invented teacher, so the one Ammar chip is theirs.
    await $(const ValueKey('flag-ammar')).waitUntilVisible();
    await $(const ValueKey('flag-ammar')).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Changed: 1').waitUntilVisible();

    await $('Changed: 1').tap();
    await $('Persona Teach Gents: +AY').waitUntilVisible();
    await $('Close').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $(FilledButton).$('Save').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    // A comment is required: Save in the dialog is off until there is one.
    expect(
      $.tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save').last)
          .onPressed,
      isNull,
    );
    await $(AlertDialog).$(TextField).enterText('Patrol journey');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $(AlertDialog).$('Save').tap();
    await $(
      '1 teacher updated.',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $('Edit').waitUntilVisible();

    // The detail: contact details, the flag now on, and the history entry.
    await $('Persona Teach Gents').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('persona-teach.gents@demo.invalid').waitUntilVisible();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flag-ammar')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
      reason: 'Ammar was switched on and saved',
    );
    // The history is the last section, below the fold of a lazy list.
    await $(RegExp('^UPDATE: Patrol journey')).scrollTo();
    await $(RegExp('^UPDATE: Patrol journey')).waitUntilVisible();
  });
}
