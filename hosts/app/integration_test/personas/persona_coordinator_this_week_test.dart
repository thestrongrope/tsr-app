import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: a class coordinator (roleid 5) whose rule matches AYD1 only
/// (gents, Pune, AMMAR) opens the weekly review (#615).
///
/// Expected: Home shows the "This week" card, the Manage tab lists a This week
/// row first, and the screen opens. AYD1 is the demo class, which every report
/// leaves out, so the coordinator's one class is not listed and the screen reads
/// "All clear this week"; no class of another gender or outside the rule shows
/// either. A class row with its stage is covered by the widget tests.
void main() {
  patrolAppTest(
    'a coordinator reaches the weekly review from Home and Manage',
    ($) async {
      await signInAs($, Persona.coordinator);
      final admin = AdminSurfaceScreenObject($);

      await refreshHome($);
      await admin.thisWeekHomeCard.waitUntilVisible();

      await admin.manageTab.waitUntilVisible();
      await admin.manageTab.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));
      await admin.thisWeekRow.waitUntilVisible();
      await admin.thisWeekRow.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      await admin.thisWeekTitle.waitUntilVisible();
      await $('All clear this week').waitUntilVisible();
      for (final code in ['AYD1', 'AYD2', 'AYP1']) {
        expect(
          $(code),
          findsNothing,
          reason: '$code is the demo class or outside the coordinator\'s rule',
        );
      }
    },
  );
}
