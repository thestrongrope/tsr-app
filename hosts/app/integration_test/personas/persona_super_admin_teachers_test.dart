import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: the super admin on the teachers screen (#622).
///
/// Chooses between the genders: gents first, then ladies, each showing only its own
/// invented teacher from scripts/persona-cohort.sql. Writes nothing.
void main() {
  patrolAppTest('super admin chooses whose teachers to see', ($) async {
    await signInAs($, Persona.superAdmin);
    await refreshHome($);
    await openPersonaTeachers($);

    await $('Persona Teach Gents').waitUntilVisible();
    expect($('Persona Teach Ladies'), findsNothing);

    await $('Ladies').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Persona Teach Ladies').waitUntilVisible();
    expect($('Persona Teach Gents'), findsNothing);

    await $('Gents').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Persona Teach Gents').waitUntilVisible();
    expect($('Persona Teach Ladies'), findsNothing);
  });
}
