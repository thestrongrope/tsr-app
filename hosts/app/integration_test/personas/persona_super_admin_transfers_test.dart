import 'package:flutter/material.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: the super admin on Transfers & Promotions (#420).
///
/// Opens the screen from the Manage tab, picks a demo class as the source and
/// sees its students listed with select all, then opens History. Reads only:
/// nobody is chosen and nothing is moved, because a move rewrites class
/// enrolments. Asserts no member's name, so no member's details reach the log.
void main() {
  patrolAppTest('super admin opens Transfers & Promotions', ($) async {
    await signInAs($, Persona.superAdmin);
    final admin = AdminSurfaceScreenObject($);
    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.transfersCard.scrollTo();
    await admin.transfersCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.transfersTitle.waitUntilVisible();

    // Pick the demo class as the source: its roster appears with select all.
    await $(InkWell).containing('From class').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(
      TextField,
    ).containing('From class: code, teacher, city, country').enterText('AYD1');
    await $.pumpAndSettle();
    await $(RegExp(r'^AYD1 — ')).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(RegExp(r'^Select all \(\d+\)$')).waitUntilVisible();

    // The log, however long it is, has its search.
    await $('History').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(
      TextField,
    ).containing('Search student, class, reason or admin').waitUntilVisible();

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.title.waitUntilVisible();
  });
}
