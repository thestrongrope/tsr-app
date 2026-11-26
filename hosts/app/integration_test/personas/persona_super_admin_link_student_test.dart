import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/manage_class_screen.dart';

/// The token of the invented member "Persona Link Member": registered, gents, in
/// no class, with a real-looking email. Tokens sit above the database's current
/// maximum, so scripts/patrol-personas.sh reads it after seeding and passes it in.
const _memberToken = String.fromEnvironment('TSR_PERSONA_LINK_MEMBER_TOKEN');

const _extraName = 'Persona Extra Student';
const _memberName = 'Persona Link Member';
const _realMemberName = 'Persona Member';
const _linkButton = 'Link to an existing member';

/// Persona journey: the super admin links an extra student to the member they
/// really are (#1135).
///
/// On AYD1's Students tab, Edit student on a real member (Persona Member) does
/// not offer the link. On the invented extra student it does. Find the invented
/// member by token, see their card and the extra student's classes, Confirm (no
/// conflict: the member is in no class), and the extra student is gone from the
/// roster while the member, now in AYD1, shows.
///
/// Writes only to the invented extra student and member; the teardown removes
/// their rows. Sends nothing.
void main() {
  patrolAppTest('super admin links an extra student to a member', ($) async {
    if (_memberToken.isEmpty) {
      throw StateError(
        'TSR_PERSONA_LINK_MEMBER_TOKEN is empty. Run the journey via '
        'scripts/patrol-personas.sh, which reads it from the seeded database.',
      );
    }
    await signInAs($, Persona.superAdmin);
    final manage = ManageClassScreenObject($);

    await refreshHome($);
    await openMyClasses($);
    await openClassFromList($, 'AYD1');
    await manage.classStudentsTile.scrollTo();
    await manage.classStudentsTile.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await manage.activeSegment.waitUntilVisible();

    Future<void> openEdit(String name) async {
      final row = $(ListTile).containing(name);
      await row.scrollTo(view: $(ListView).$(Scrollable));
      await row.$(PopupMenuButton<String>).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await manage.editItem.tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $('Edit student').waitUntilVisible();
    }

    // A real member in the same roster: no link button.
    await openEdit(_realMemberName);
    expect(
      $(_linkButton),
      findsNothing,
      reason: 'a member who signed in is not an extra student',
    );
    await $('Cancel').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    // The extra student: the button, then the dialog.
    await openEdit(_extraName);
    await $(_linkButton).waitUntilVisible();
    await $(_linkButton).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    final findButton = $(const Key('link-find'));
    final confirm = $(const Key('link-confirm'));
    await $(const Key('link-token-field')).enterText(_memberToken);
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await findButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The member card, and the extra student's classes.
    await confirm.waitUntilExists(timeout: const Duration(seconds: 60));
    expect($(_memberName), findsOneWidget);
    expect($('persona-link.member@demo.invalid'), findsOneWidget);
    expect(
      $(RegExp(r'^Persona Extra Student \(token \d+\) is in:$')),
      findsOneWidget,
    );
    expect($(RegExp(r'^AYD1: ')), findsOneWidget);
    expect(
      $.tester.widget<FilledButton>(confirm.finder).onPressed,
      isNotNull,
      reason: 'no conflict, so there is nothing to choose before Confirm',
    );

    await confirm.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $(
      '$_extraName linked to the member',
    ).waitUntilExists(timeout: const Duration(seconds: 30));

    // The roster reloads: the extra student is gone, the member is in AYD1.
    await $(_memberName).waitUntilExists(timeout: const Duration(seconds: 30));
    expect(
      $(ListTile).containing(_extraName),
      findsNothing,
      reason: 'the extra student was removed by the link',
    );
    expect($(ListTile).containing(_memberName), findsOneWidget);
  });
}
