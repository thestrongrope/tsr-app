import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/global_search_screen.dart';

/// Persona journey: a class coordinator (roleid 5) whose rule matches AYD1 only
/// (gents, Pune, AMMAR) uses global search (#557).
///
/// Expected: the class they coordinate is found and opens; people who
/// registered but are in no class (Persona Reg ...) are subscribers, which only
/// the super admin may find, so no Subscribers group appears for them.
void main() {
  patrolAppTest('a coordinator finds their class and no subscribers', (
    $,
  ) async {
    await signInAs($, Persona.coordinator);
    final search = GlobalSearchScreenObject($);

    await refreshHome($);
    await search.homeSearchButton.waitUntilVisible();
    await search.homeSearchButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await search.field.enterText(ClassListScreenObject.demoClassCode);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await search.group('Classes').waitUntilVisible();
    await $(ClassListScreenObject.demoClassCode).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      search.field,
      findsNothing,
      reason: 'the result opened the class, so the search field is gone',
    );

    await pushRoute($, '/search');
    await search.field.enterText('Persona Reg');
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    expect(
      search.group('Subscribers'),
      findsNothing,
      reason: 'subscribers are for the super admin only',
    );
  });
}
