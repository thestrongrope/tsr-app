import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a ladies admin (roleid 4) on the teachers screen (#622).
///
/// Sees the ladies teachers and no gents one, whatever the screen asks for, and is
/// not offered the gender. Writes nothing.
void main() {
  patrolAppTest('ladies admin sees ladies teachers only', ($) async {
    await signInAs($, Persona.ladiesAdmin);
    await refreshHome($);
    await openPersonaTeachers($);

    await $('Persona Teach Ladies').waitUntilVisible();
    expect(
      $('Persona Teach Gents'),
      findsNothing,
      reason: 'a ladies admin must never see a gents teacher',
    );
    expect(
      $('Gents'),
      findsNothing,
      reason: 'the gender is not theirs to pick',
    );
    expect(
      $('Ladies'),
      findsNothing,
      reason: 'the gender is not theirs to pick',
    );
  });
}
