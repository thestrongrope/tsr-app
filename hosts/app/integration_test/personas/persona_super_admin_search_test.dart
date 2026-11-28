import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/global_search_screen.dart';

/// Persona journey: super admin (roleid 1) uses global search (#557).
///
/// Expected: finds classes of both genders, a student, and the subscribers (the
/// invented registrants who are in no class), and a subscriber result opens
/// its card.
void main() {
  patrolAppTest('a super admin finds classes, students and subscribers', (
    $,
  ) async {
    await signInAs($, Persona.superAdmin);
    final search = GlobalSearchScreenObject($);

    await refreshHome($);
    await search.homeSearchButton.waitUntilVisible();
    await search.homeSearchButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await search.field.enterText('AYP1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Classes').waitUntilVisible();

    await search.field.enterText('AYD1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Classes').waitUntilVisible();

    await search.field.enterText('Persona Member');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Students').waitUntilVisible();

    await search.field.enterText('Persona Reg Ladies Place');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Subscribers').waitUntilVisible();
    await $('Persona Reg Ladies Place').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      search.field,
      findsNothing,
      reason:
          'the result opened the subscriber card, so the search field is gone',
    );
  });
}
