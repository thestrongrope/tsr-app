import 'package:flutter/material.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: the super admin on the deletion requests queue (#416).
///
/// Opens the queue from the Manage tab and filters it. Reads only: no request
/// is raised, held, confirmed or completed, because completing deletes a real
/// sign-in. Asserts no member's name, so no member's details reach the log.
void main() {
  patrolAppTest('super admin opens the deletion requests queue', ($) async {
    await signInAs($, Persona.superAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    // Last card of a long, lazily built list: scroll to it before tapping.
    await admin.deletionRequestsCard.scrollTo();
    await admin.deletionRequestsCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await admin.deletionRequestsTitle.waitUntilVisible();
    await $(RegExp(r'^All \(\d+\)$')).waitUntilVisible();
    await $(RegExp(r'^Pending \(\d+\)$')).waitUntilVisible();

    await $(RegExp(r'^Cancelled \(\d+\)$')).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.deletionRequestsTitle.waitUntilVisible();

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.title.waitUntilVisible();
  });
}
