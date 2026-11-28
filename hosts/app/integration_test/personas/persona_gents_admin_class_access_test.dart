import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/admin_surface_screen.dart';
import '../screens/class_access_screen.dart';

/// Persona journey: a gents admin (roleid 3, holding class-access:manage:gender)
/// chooses the classes a member coordinates (#1034).
///
/// Persona Member (gents, in AYD1, roleid 0) starts managing nothing. The admin
/// adds access for the AMMAR level in Pune, sees the preview reach AYD1 and
/// confirms with a reason, then finds the rule and AYD1 under it. The gender wall
/// holds: the add sheet offers Gents only, and a search for a ladies member finds
/// nobody. Finally removes the access with a reason and sees Persona Member manage
/// nothing again. Writes only to the invented Persona Member; the teardown removes
/// their rules.
void main() {
  patrolAppTest('a gents admin adds and removes class access for a member', (
    $,
  ) async {
    await signInAs($, Persona.gentsAdmin);
    await refreshHome($);
    final admin = AdminSurfaceScreenObject($);
    final access = ClassAccessScreenObject($);

    await admin.manageTab.waitUntilVisible();
    await admin.manageTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    // The card shows once /me/permissions has loaded: wait for it, then scroll.
    await access.card.waitUntilExists(timeout: const Duration(seconds: 60));
    await access.card.scrollTo();
    await access.card.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await access.title.waitUntilVisible();

    // The gender wall on search: a ladies member is not found.
    await access.searchField.enterText('Persona Teach Ladies');
    await access.searchButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await access.noMemberFound.waitUntilVisible();
    expect(
      access.result('Persona Teach Ladies'),
      findsNothing,
      reason: 'a gents admin must never find a ladies member',
    );

    // A gents member is, and manages no class yet.
    await access.searchField.enterText('Persona Member');
    await access.searchButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await access.result('Persona Member').waitUntilVisible();
    await access.result('Persona Member').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await access.managesNothing.waitUntilVisible();

    // Add: AMMAR in Pune. The sheet offers the one gender, Gents.
    await access.addButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await access.sheet.$('Gents').waitUntilVisible();
    expect(
      access.sheet.$('Ladies'),
      findsNothing,
      reason: 'the gender is not theirs to pick',
    );
    await access.sheet.$('AMMAR').tap();
    await access.sheet.$('Pune').scrollTo(view: access.sheetScrollable);
    await access.sheet.$('Pune').tap();
    await access.previewButton.scrollTo(view: access.sheetScrollable);
    await access.previewButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    // The preview is a network call: wait for it, then scroll it into view.
    await access.reaches.waitUntilExists(timeout: const Duration(seconds: 60));
    await access.reaches.scrollTo(view: access.sheetScrollable);
    await access.sheet
        .$('AYD1')
        .scrollTo(view: access.sheetScrollable, step: 600, maxScrolls: 80);

    // The reason is required: Add access stays off until there is one.
    await access.reasonField.scrollTo(view: access.sheetScrollable);
    expect(
      $.tester.widget<FilledButton>(access.addAccessButton.finder).onPressed,
      isNull,
    );
    await access.reasonField.enterText('Patrol journey');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await access.addAccessButton.tap();
    await $(
      'Access added.',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    // The rule is in the member view, and expands to AYD1.
    await access.rule.waitUntilVisible();
    expect(access.managesNothing, findsNothing);
    await access.rule.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('AYD1').scrollTo();
    await $('AYD1').waitUntilVisible();

    // Remove: a reason is required, then the member manages nothing again.
    await access.removeButton.scrollTo();
    await access.removeButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $('Remove this access?').waitUntilVisible();
    expect(
      $.tester
          .widget<FilledButton>(access.confirmRemoveButton.finder)
          .onPressed,
      isNull,
    );
    await access.removeReasonField.enterText('Patrol journey');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await access.confirmRemoveButton.tap();
    await $(
      'Access removed.',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await access.managesNothing.waitUntilVisible();
    expect(access.rule, findsNothing);
  });
}
