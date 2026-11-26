import 'package:flutter/material.dart';

import '../harness/app_links.dart';
import '../harness/patrol_app.dart';
import '../screens/login_screen.dart';

/// A shared article link opens the article in the app, signed out (#1121, AC4),
/// and says so when the article no longer exists (AC5).
///
/// The widget tests prove the router and the screen; this is the check that the
/// intent reaches them on a device. The article is whichever one the website
/// lists first, read with the same public GET the Library uses.
///
/// Assertions are Patrol waits or a thrown `StateError`, never `expect`: a
/// failing `expect` inside a Patrol test hangs until the watchdog without
/// reporting its reason.
void main() {
  patrolAppTest('a signed-out person opens an article from its link', (
    $,
  ) async {
    final article = await aPublishedArticle();
    final login = LoginScreenObject($);
    await login.inviteButton.waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    await openAppLink($, '/articles/${article.slug}');
    await $(
      article.title,
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    await openAppLink($, '/articles/$missingArticleSlug');
    await $(
      articleGoneMessage,
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $('See all articles').waitUntilVisible();
    if ($(Icons.share_outlined).exists) {
      throw StateError('a missing article offers to share');
    }
  });
}
