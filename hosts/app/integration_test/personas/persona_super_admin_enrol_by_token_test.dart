import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/enrol_by_token_screen.dart';

/// The token of the invented registrant "Persona Reg Gents Place": registered,
/// gents, in no class. Tokens sit above the database's current maximum, so
/// scripts/patrol-personas.sh reads it after seeding and passes it in.
const _fixtureToken = String.fromEnvironment('TSR_PERSONA_ENROL_TOKEN');

/// A token no member has.
const _unknownToken = '999999999';

/// Persona journey: the super admin enrols a member in a class by token (#1050).
///
/// Looks up a token nobody has and sees only the one sentence. Looks up the
/// registrant, sees every detail and that they are in no class. The chooser
/// offers the gents class AYD1 and not the ladies class AYP1. Enrols them in
/// AYD1 and sees the success message, then looks them up again: AYD1 is among
/// their classes and cannot be chosen. Writes only to the invented registrant;
/// the teardown removes their rows.
void main() {
  patrolAppTest('super admin enrols a registered member by token', ($) async {
    if (_fixtureToken.isEmpty) {
      throw StateError(
        'TSR_PERSONA_ENROL_TOKEN is empty. Run the journey via '
        'scripts/patrol-personas.sh, which reads it from the seeded database.',
      );
    }
    await signInAs($, Persona.superAdmin);
    await refreshHome($);
    final admin = AdminSurfaceScreenObject($);
    final enrol = EnrolByTokenScreenObject($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    // Manage is a lazy list and the card sits in its last section, so it does
    // not exist until scrolled to. Wait for a card at the top first (the screen
    // and /me/permissions have loaded), then scroll a long way.
    await $('This week').waitUntilVisible(timeout: const Duration(seconds: 60));
    await enrol.card.scrollTo(maxScrolls: 60, step: 300);
    await enrol.card.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await enrol.title.waitUntilVisible();

    // A token nobody has: the one sentence, and no member card.
    await enrol.tokenField.enterText(_unknownToken);
    await enrol.lookUpButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await enrol.notFound.waitUntilExists(timeout: const Duration(seconds: 60));
    expect(enrol.details, findsNothing);

    // The registrant: every detail, and in no class.
    await enrol.tokenField.enterText(_fixtureToken);
    await enrol.lookUpButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await enrol.details.waitUntilExists(timeout: const Duration(seconds: 60));
    expect(enrol.notFound, findsNothing);
    expect(enrol.details.$('Persona Reg Gents Place'), findsOneWidget);
    expect(enrol.details.$(_fixtureToken), findsOneWidget);
    expect(enrol.details.$('Gents'), findsOneWidget);
    expect(
      enrol.details.$('persona-reg.gentsplace@demo.invalid'),
      findsOneWidget,
    );
    expect(enrol.details.$('447700900208'), findsOneWidget);
    expect(enrol.details.$('Pune'), findsOneWidget);
    expect(enrol.details.$('India'), findsOneWidget);
    expect(enrol.details.$('Registered'), findsOneWidget);
    expect(enrol.notInAnyClass, findsOneWidget);

    // The chooser loads the class list over the network: wait, then scroll.
    await enrol.chooserSearch.waitUntilExists(
      timeout: const Duration(seconds: 60),
    );
    await enrol.chooserSearch.scrollTo();

    // The gender wall: the ladies class AYP1 is not offered.
    await enrol.chooserSearch.enterText('AYP1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await enrol.noClassToChoose.waitUntilExists();
    expect(
      enrol.classRow('AYP1'),
      findsNothing,
      reason: 'a gents member must never be offered a ladies class',
    );

    // The gents class AYD1 is, and is the one to choose.
    await enrol.chooserSearch.enterText('AYD1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await enrol.classRow('AYD1').waitUntilExists();
    expect(
      $.tester.widget<ListTile>(enrol.classRow('AYD1').finder).enabled,
      isTrue,
    );
    expect(
      $.tester.widget<FilledButton>(enrol.confirmButton.finder).onPressed,
      isNull,
      reason: 'Confirm stays off until a class is chosen',
    );
    await enrol.classRow('AYD1').scrollTo();
    await enrol.classRow('AYD1').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await enrol.chosenMark.waitUntilExists();
    await enrol.confirmButton.scrollTo();
    await enrol.confirmButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await enrol.enrolButton.waitUntilVisible();
    await enrol.enrolButton.tap();
    await $(
      'Persona Reg Gents Place added to AYD1',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    // Again: AYD1 is among their classes and cannot be chosen.
    await enrol.tokenField.scrollTo();
    await enrol.tokenField.enterText(_fixtureToken);
    await enrol.lookUpButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await enrol.details.waitUntilExists(timeout: const Duration(seconds: 60));
    expect(enrol.details.$('AYD1'), findsOneWidget);
    expect(enrol.notInAnyClass, findsNothing);
    await enrol.chooserSearch.waitUntilExists(
      timeout: const Duration(seconds: 60),
    );
    await enrol.chooserSearch.scrollTo();
    await enrol.chooserSearch.enterText('AYD1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await enrol.alreadyInClass.waitUntilExists();
    await enrol.alreadyInClass.scrollTo();
    expect(
      $.tester.widget<ListTile>(enrol.classRow('AYD1').finder).enabled,
      isFalse,
    );
  });
}
