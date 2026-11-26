import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a gents admin is offered "New class" on the registrations screen
/// (#636), and the form does not ask for a gender (they may create gents classes
/// only). Writes nothing: the form is opened and left, never submitted, so no
/// class is created in the local database. Creating one for real is the server
/// tests' to prove, and a journey that did would leave a class behind.
void main() {
  patrolAppTest('gents admin is offered New class and is not asked a gender', (
    $,
  ) async {
    await signInAs($, Persona.gentsAdmin);
    await refreshHome($);
    await openPersonaRegistrations($);

    await $(find.byTooltip('New class')).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await $('Level').waitUntilVisible();
    expect(
      $('Ladies'),
      findsNothing,
      reason:
          'a gents admin may not create a ladies class, so is not offered it',
    );
    await $('Create class').scrollTo();
    final create = $.tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create class'),
    );
    expect(
      create.onPressed,
      isNull,
      reason: 'nothing is filled in, so Create must not be possible',
    );

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect($('Persona Reg Gents Place'), findsOneWidget);
  });
}
