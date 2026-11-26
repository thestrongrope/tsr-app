import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a gents admin (roleid 3) on the registrations screen (#614).
///
/// Sees the gents registrants and no ladies one, is offered the gents classes to
/// place them in, and cannot reject. Writes nothing: it opens the class picker
/// and cancels. (The picker holds every real gents class, so AYD1 is scrolled to
/// and the absence of a ladies class is the host-side probe's and the server
/// tests' to prove, not a scroll's.)
void main() {
  patrolAppTest('gents admin sees gents registrants and cannot reject', (
    $,
  ) async {
    await signInAs($, Persona.gentsAdmin);
    await refreshHome($);
    await openPersonaRegistrations($);

    await $('Persona Reg Gents Place').waitUntilVisible();
    expect($('Persona Reg Gents Reject'), findsOneWidget);
    expect(
      $('Persona Reg Ladies Place'),
      findsNothing,
      reason: 'a gents admin must never see a ladies registrant',
    );
    expect(
      $('Ladies'),
      findsNothing,
      reason: 'the gender is not theirs to pick',
    );
    expect($('Reject'), findsNothing);

    await registrantButton($, 'Persona Reg Gents Reject', 'Place').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Place Persona Reg Gents Reject').waitUntilVisible();
    await $(BottomSheet)
        .$(RegExp('^AYD1 '))
        .scrollTo(
          view: $(BottomSheet).$(Scrollable),
          step: 600,
          maxScrolls: 80,
        );
    await $(BottomSheet).$('Cancel').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    expect(
      $('Persona Reg Gents Reject'),
      findsOneWidget,
      reason: 'cancelling the picker changes nothing',
    );
  });
}
