import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a class coordinator is not offered "New class" on the
/// registrations screen (#636). classes:create is held by the gender admins and
/// the super admin, not by a coordinator. Writes nothing.
void main() {
  patrolAppTest('a coordinator is not offered New class', ($) async {
    await signInAs($, Persona.coordinator);
    await refreshHome($);
    await openPersonaRegistrations($);

    await $('Persona Reg Gents Place').waitUntilVisible();
    expect(
      find.byTooltip('New class'),
      findsNothing,
      reason: 'classes:create is held by the gender admins and the super admin',
    );
  });
}
