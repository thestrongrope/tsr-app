import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/global_search_screen.dart';

/// Persona journey: an ordinary member, who holds no admin permission, finds
/// the Me tab's screens in global search.
///
/// Expected: "feedback" finds Send feedback, which opens with Me behind it, so
/// back returns to Me and not to nothing; "contribution" finds Donate. Donate
/// is not tapped: it opens the website in the browser, outside the app.
void main() {
  patrolAppTest('a member finds Send feedback and Donate in search', ($) async {
    await signInAs($, Persona.member);
    final search = GlobalSearchScreenObject($);

    await refreshHome($);
    await search.homeSearchButton.waitUntilVisible();
    await search.homeSearchButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await search.field.enterText('feedback');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Screens and reports').waitUntilVisible();
    await $('Send feedback').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The feedback screen has a text field of its own, so the screen is told
    // by its title, not by the search field having gone.
    await $(AppBar).$('Send feedback').waitUntilVisible();

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(AppBar).$('Me').waitUntilVisible();
    await $('Donate').scrollTo();
    expect($('Donate'), findsOneWidget, reason: 'back returned to the Me tab');

    await pushRoute($, '/search');
    await search.field.enterText('contribution');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Screens and reports').waitUntilVisible();
    expect($('Donate'), findsOneWidget);
  });
}
