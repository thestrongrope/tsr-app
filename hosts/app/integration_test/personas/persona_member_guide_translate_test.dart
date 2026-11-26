import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/class_list_screen.dart';

/// Persona journey: a member reads the level guide and opens its translation (#694).
///
/// Opens the guide from the class dashboard, looks for the Translate action, opens
/// the translate screen and goes back. A web view is a platform view Patrol cannot
/// inspect, so the page, the language choice and the links are not checked here
/// (the widget tests cover the rest). It writes nothing. Needs the member's level
/// to have a guide in the local database.
void main() {
  patrolAppTest('member opens the guide translation and comes back', ($) async {
    await signInAs($, Persona.member);
    final classes = ClassListScreenObject($);

    await refreshHome($);
    await openTab($, 'Me');
    await openMyClasses($);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // One class, so the screen goes straight to its dashboard.
    await classes.demoClassCard.waitUntilVisible();
    await $('Read the level guide').scrollTo();
    await $('Read the level guide').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    final translate = find.byTooltip('Translate');
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));
    expect(translate, findsOneWidget);
    await $.tester.tap(translate);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await $(AppBar)
        .$('Translate guide')
        .waitUntilVisible(timeout: const Duration(seconds: 10));

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(find.byTooltip('Translate'), findsOneWidget);
  });
}
