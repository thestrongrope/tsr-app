import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';

/// Persona journey: finance (roleid 7).
///
/// On a device finance is a member with no classes, so has no Classes tab, and
/// holds one admin module,
/// the donors list (#421): Manage shows that card and no other, and the list
/// opens with its search box. Reads only, and asserts no donor's name, so no
/// member's details reach the test log.
void main() {
  patrolAppTest('finance sees the donors list and nothing else', ($) async {
    await signInAs($, Persona.finance);
    final admin = AdminSurfaceScreenObject($);

    await refreshHome($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.donorsCard.waitUntilVisible();
    expect(
      admin.notificationsCard,
      findsNothing,
      reason: 'finance holds donors:read only',
    );
    expect(admin.reportsCard, findsNothing);
    expect(admin.teachersCard, findsNothing);
    expect(admin.deactivatedClassesCard, findsNothing);

    await admin.donorsCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.donorsTitle.waitUntilVisible();
    await $(TextField).waitUntilVisible();

    await $(BackButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // Finance has no class to attend, conduct or manage, so there is no Classes
    // tab at all (#643): Home, Library, Manage and Me.
    expect($(GlassBottomNavBar).$('Classes'), findsNothing);
    await $(GlassBottomNavBar).$('Home').waitUntilVisible();
    await $(GlassBottomNavBar).$('Library').waitUntilVisible();
    await $(GlassBottomNavBar).$('Me').waitUntilVisible();
  });
}
