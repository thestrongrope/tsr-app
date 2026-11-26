import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: the super admin (roleid 1) rejecting and placing (#614).
///
/// Reaches both genders, so chooses between them; is the only one offered
/// Reject. Rejects the invented "Persona Reg Gents Reject" with a reason, then
/// switches to ladies and places "Persona Reg Ladies Place" in AYP1. Both must
/// leave the waiting list. Only the invented registrants are touched.
void main() {
  patrolAppTest(
    'super admin rejects a gents registrant and places a ladies one',
    ($) async {
      await signInAs($, Persona.superAdmin);
      await refreshHome($);
      await openPersonaRegistrations($);

      await $('Persona Reg Gents Reject').waitUntilVisible();
      expect($('Ladies'), findsOneWidget, reason: 'they choose the gender');

      await registrantButton($, 'Persona Reg Gents Reject', 'Reject').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));
      await $('Reject Persona Reg Gents Reject').waitUntilVisible();
      await $(AlertDialog).$(TextField).enterText('Patrol journey');
      await $.pumpAndSettle();
      await $(AlertDialog).$(FilledButton).$('Reject').tap();
      await $('Persona Reg Gents Reject rejected.').waitUntilVisible();
      await waitUntilGone($, 'Persona Reg Gents Reject');
      expect($('Persona Reg Gents Place'), findsOneWidget);

      await $('Ladies').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));
      await $('Persona Reg Ladies Place').waitUntilVisible();
      expect($('Persona Reg Gents Place'), findsNothing);

      await registrantButton($, 'Persona Reg Ladies Place', 'Place').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));
      await $('Place Persona Reg Ladies Place').waitUntilVisible();
      await $(BottomSheet)
          .$(RegExp('^AYP1 '))
          .scrollTo(
            view: $(BottomSheet).$(Scrollable),
            step: 600,
            maxScrolls: 80,
          );
      await $(BottomSheet).$(RegExp('^AYP1 ')).tap();
      await $.pumpAndSettle();
      await $(BottomSheet).$(FilledButton).$('Place').tap();

      await $('Persona Reg Ladies Place placed in AYP1.').waitUntilVisible();
      await waitUntilGone($, 'Persona Reg Ladies Place');
    },
  );
}
