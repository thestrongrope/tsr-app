import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: past notifications open what they were about (#899, #800).
///
/// The persona member has five past notifications (scripts/persona-cohort.sql,
/// section 7), one per outcome of tapping one in the history list:
///   - a class they attend: the class opens;
///   - a quiz in that class: the quiz opens (the journey never answers it);
///   - a class that does not exist: "This is no longer available." above the
///     full text;
///   - a class they are not in (AYP1, ladies): "You do not have access to this."
///     above the full text, and nothing opens;
///   - no link: the full text.
/// Every tapped notification must then stop showing under Unread.
///
/// Needs the persona fixture; run it through scripts/patrol-personas.sh.
///
/// Assertions are Patrol waits or a thrown `StateError`, never `expect`: a
/// failing `expect` inside a Patrol test hangs until the watchdog without
/// reporting its reason.
const _classTitle = 'Demo notice: class link';
const _quizTitle = 'Demo notice: quiz link';
const _goneTitle = 'Demo notice: gone link';
const _deniedTitle = 'Demo notice: denied link';
const _noLinkTitle = 'Demo notice: no link';

const _goneBody = 'Fixture text for the gone link notice.';
const _deniedBody = 'Fixture text for the denied link notice.';
const _noLinkBody = 'Fixture text for the notice with no link.';

void main() {
  patrolAppTest('a past notification opens what it was about', ($) async {
    await signInAs($, Persona.member);
    await refreshHome($);

    Future<void> openHistory() async {
      await pushRoute($, '/notifications');
      await $(_classTitle).waitUntilVisible();
    }

    Future<void> requireAbsent(String text) async {
      if ($(text).exists) {
        throw StateError('"$text" is on screen but should not be');
      }
    }

    // The full text is in the list tile and again in the open sheet.
    Future<void> requireFullText(String body) async {
      await $(body).waitUntilVisible();
      if ($(body).evaluate().length < 2) {
        throw StateError('the full text of "$body" is not shown in the sheet');
      }
    }

    Future<void> closeSheet() async {
      await $.platform.android.pressBack();
      await $.pumpAndSettle();
    }

    await openHistory();
    for (final title in [
      _classTitle,
      _quizTitle,
      _goneTitle,
      _deniedTitle,
      _noLinkTitle,
    ]) {
      await $(title).waitUntilVisible();
    }

    // Nothing has been tapped yet, so the Unread filter holds the class one.
    await $('Unread').tap();
    await $(_classTitle).waitUntilVisible();
    await $('All').tap();

    // A class they attend: its dashboard opens.
    await $(_classTitle).tap();
    await $('Performance Overview').waitUntilExists();

    // A quiz in that class: its first question opens over the history list.
    await openHistory();
    await $(_quizTitle).tap();
    await $(
      'Question 1',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    GoRouter.of($.tester.element(find.byType(Scaffold).first)).pop();
    await $.pumpAndSettle();

    // A class that no longer exists: told so, text readable, nothing opened.
    await $(_goneTitle).waitUntilVisible();
    await $(_goneTitle).tap();
    await $('This is no longer available.').waitUntilVisible();
    await requireFullText(_goneBody);
    await closeSheet();

    // A class they cannot reach: told so, text readable, nothing opened.
    await $(_deniedTitle).tap();
    await $('You do not have access to this.').waitUntilVisible();
    await requireFullText(_deniedBody);
    await closeSheet();

    // No link: the full text, with no reason above it.
    await $(_noLinkTitle).tap();
    await requireFullText(_noLinkBody);
    await requireAbsent('This is no longer available.');
    await requireAbsent('You do not have access to this.');
    await closeSheet();

    // Every tapped notification is now read.
    await $('Unread').tap();
    await $.pumpAndSettle();
    for (final title in [
      _classTitle,
      _quizTitle,
      _goneTitle,
      _deniedTitle,
      _noLinkTitle,
    ]) {
      await requireAbsent(title);
    }
  });
}
