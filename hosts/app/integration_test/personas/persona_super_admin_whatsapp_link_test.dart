import 'package:flutter/material.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: the super admin on the WhatsApp link (#693).
///
/// Opens the reminders screen from the Manage tab, then the link screen from its
/// card, and looks for the link's state and the Re-link and Logout controls.
/// Reads only: it never taps Re-link or Logout and never confirms, because either
/// drops the one session every scheduled reminder is sent through. It asserts no
/// QR code, which is a live credential.
void main() {
  patrolAppTest('super admin sees the WhatsApp link and its controls', (
    $,
  ) async {
    await signInAs($, Persona.superAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.whatsappRemindersCard.scrollTo();
    await admin.whatsappRemindersCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The reminders screen's card says whether WhatsApp is linked.
    await admin.whatsappLinkCard.waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    await admin.whatsappLinkCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await admin.whatsappLinkTitle.waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    await admin.whatsappLinkState.waitUntilVisible(
      timeout: const Duration(seconds: 20),
    );
    // Below the fold when a code is showing; looked for, never tapped.
    await admin.whatsappRelinkButton.scrollTo();
    await admin.whatsappRelinkButton.waitUntilVisible(
      timeout: const Duration(seconds: 5),
    );
    await admin.whatsappLogoutButton.scrollTo();
    await admin.whatsappLogoutButton.waitUntilVisible(
      timeout: const Duration(seconds: 5),
    );

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  });
}
