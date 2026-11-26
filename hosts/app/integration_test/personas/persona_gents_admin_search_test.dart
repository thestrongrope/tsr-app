import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/global_search_screen.dart';

/// Persona journey: gents admin (roleid 3, gender 1) uses global search (#557).
///
/// Expected: finds a gents class and a student of it; finds no ladies class;
/// subscribers (registered, in no class) are for the super admin only. The
/// fixtures put Persona Member in AYD1 (gents) and AYP1 is a ladies class.
void main() {
  patrolAppTest('a gents admin finds gents classes and students only', (
    $,
  ) async {
    await signInAs($, Persona.gentsAdmin);
    final search = GlobalSearchScreenObject($);

    await refreshHome($);
    await search.homeSearchButton.waitUntilVisible();
    await search.homeSearchButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await search.field.enterText('AYD1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Classes').waitUntilVisible();

    await search.field.enterText('Persona Member');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Students').waitUntilVisible();

    await search.field.enterText('AYP1');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      search.group('Classes'),
      findsNothing,
      reason: 'a gents admin must never find a ladies class',
    );

    await search.field.enterText('Persona Reg');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      search.group('Subscribers'),
      findsNothing,
      reason: 'subscribers are for the super admin only',
    );
  });
}
