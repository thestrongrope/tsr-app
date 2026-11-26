import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/publications_screen.dart';

/// A tab shows where it was last left, across a refresh of Home (#561).
///
/// Pull-to-refresh on Home reloads the member's profile and permissions. Each
/// of those used to build a new router, which started again from the splash
/// screen and put every tab back at its start.
///
/// See docs/specs/mobile-tabs/plan.md
void main() {
  patrolAppTest('a tab keeps its place across a Home refresh', ($) async {
    await signInAsReviewer($);
    final pubs = PublicationsScreenObject($);

    await pubs.libraryTab.tap();
    await pubs.libraryItem.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await pubs.title.waitUntilVisible();

    await $(GlassBottomNavBar).$('Home').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await $.tester.fling(
      find.byType(RefreshIndicator).first,
      const Offset(0, 400),
      1000,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await pubs.libraryTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(
      pubs.title,
      findsOneWidget,
      reason: 'Library is still on Publications after the refresh',
    );
  });
}
