import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';

/// A member can send feedback from the Me tab and sees it confirmed (#882, #883).
///
/// Happy path only; the offline queue is covered by the unit tests. The message
/// is a row in the local database, which is a copy of production and never
/// reaches it.
///
/// See docs/specs/send-feedback/tasks.md
void main() {
  patrolAppTest('feedback sent from the Me tab is confirmed', ($) async {
    await signInAsReviewer($);

    await $(GlassBottomNavBar).$('Me').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $('Send feedback').scrollTo();
    await $('Send feedback').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));

    await $(TextField).enterText('Patrol test feedback');
    await $('Send').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    expect(
      find.text('Received. Thank you.'),
      findsOneWidget,
      reason: 'the screen confirms the message was received',
    );
  });
}
