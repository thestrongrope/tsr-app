import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/global_search_screen.dart';

/// Persona journey: ladies admin (roleid 4, gender 2) uses global search (#557).
///
/// Expected: finds the ladies class AYP1; finds no gents class (AYD1) and not
/// the gents student Persona Member; no Subscribers group. Gender segregation
/// holds for every private kind.
void main() {
  patrolAppTest('a ladies admin finds ladies classes and no gents ones', (
    $,
  ) async {
    await signInAs($, Persona.ladiesAdmin);
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
    expect(
      search.group('Classes'),
      findsNothing,
      reason: 'a ladies admin must never find a gents class',
    );

    await search.field.enterText('Persona Member');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      search.group('Students'),
      findsNothing,
      reason: 'a gents student is outside a ladies admin\'s reach',
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
