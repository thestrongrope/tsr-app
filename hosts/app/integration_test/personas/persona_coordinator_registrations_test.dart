import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a class coordinator (roleid 5) placing a registrant (#614).
///
/// A coordinator reads the registrations of their gender and may place someone
/// only into a class they are assigned to, here AYD1; they may not reject, so
/// the app must not offer it. Places the invented "Persona Reg Gents Place"
/// (scripts/persona-cohort.sql) and checks they leave the waiting list.
void main() {
  patrolAppTest('coordinator places a registrant into their class only', (
    $,
  ) async {
    await signInAs($, Persona.coordinator);
    await refreshHome($);
    await openPersonaRegistrations($);

    await $('Persona Reg Gents Place').waitUntilVisible();
    expect($('Persona Reg Gents Reject'), findsOneWidget);
    expect(
      $('Persona Reg Ladies Place'),
      findsNothing,
      reason: 'a gents coordinator must never see a ladies registrant',
    );
    expect(
      $('Reject'),
      findsNothing,
      reason: 'registrations:reject is the super admin only',
    );

    await registrantButton($, 'Persona Reg Gents Place', 'Place').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Place Persona Reg Gents Place').waitUntilVisible();
    expect(
      $(BottomSheet).$(ListTile),
      findsOneWidget,
      reason: 'a coordinator can enrol into their one assigned class only',
    );
    await $(BottomSheet).$(RegExp('^AYD1 ')).tap();
    await $.pumpAndSettle();
    await $(BottomSheet).$(FilledButton).$('Place').tap();

    // The list reloads from the server: a placed registrant is no longer in it.
    await $('Persona Reg Gents Place placed in AYD1.').waitUntilVisible();
    await waitUntilGone($, 'Persona Reg Gents Place');
    expect($('Persona Reg Gents Reject'), findsOneWidget);
  });
}
