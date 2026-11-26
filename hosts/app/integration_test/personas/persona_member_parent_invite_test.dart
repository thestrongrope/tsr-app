import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/app_links.dart';
import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';
import '../screens/login_screen.dart';

/// Persona journey: a parent accepts an invite link in the app (#1122).
///
/// The persona fixture (scripts/persona-cohort.sql, section 8) has an invented
/// child, "Patrolchild", with two invites an admin made: one open and one past
/// its expiry. The journey, as the persona member:
///   - signed out, taps the open invite: is asked to sign in, signs in, and is
///     shown the same invite naming the child (AC4, AC6);
///   - accepts it as Mother: lands on My children with the child listed (AC5);
///   - taps the open invite again, now used: is told it cannot be used and
///     nothing changes (AC7);
///   - taps the expired invite: the same refusal (AC7).
///
/// Needs the persona fixture; run it through scripts/patrol-personas.sh.
///
/// Assertions are Patrol waits or a thrown `StateError`, never `expect`: a
/// failing `expect` inside a Patrol test hangs until the watchdog without
/// reporting its reason.
const _openCode = 'patrol-open-invite';
const _expiredCode = 'patrol-expired-invite';
const _child = 'Patrolchild';
const _refusal =
    'This invite has expired, has already been used or was cancelled. '
    'Ask for a new one.';

void main() {
  patrolAppTest(
    'a parent signs in, accepts an invite, and is refused a used one',
    ($) async {
      final login = LoginScreenObject($);
      await login.inviteButton.waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );

      // Signed out: the link asks for sign-in, then shows the same invite.
      await openAppLink($, '/link/$_openCode');
      await login.signInButton.waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      await signInOnLoginScreen($, Persona.member);
      await $(AppBar)
          .$('Parent invite')
          .waitUntilVisible(timeout: const Duration(seconds: 60));
      await $(
        'You have been invited to become a parent or guardian of $_child.',
      ).waitUntilVisible();

      // Accept needs a relationship first.
      await $('Mother').tap();
      await $('Accept').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));
      await $(
        AppBar,
      ).$('My Children').waitUntilVisible(timeout: const Duration(seconds: 30));
      await $(find.textContaining(_child)).waitUntilVisible();

      // The invite is used now: refused, and nothing changes.
      await openAppLink($, '/link/$_openCode');
      await $(_refusal).waitUntilVisible(timeout: const Duration(seconds: 30));
      if ($('Accept').exists) {
        throw StateError('a used invite still offers to accept');
      }

      // An expired invite: the same refusal.
      await openAppLink($, '/link/$_expiredCode');
      await $(_refusal).waitUntilVisible(timeout: const Duration(seconds: 30));
      if ($('Accept').exists) {
        throw StateError('an expired invite still offers to accept');
      }
    },
  );
}
