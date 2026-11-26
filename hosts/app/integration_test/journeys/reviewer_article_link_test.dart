import '../harness/app_links.dart';
import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';

/// A shared article link opens the article in the app for a signed-in member
/// (#1121, AC2), and says so when the article no longer exists (AC5).
///
/// See guest_article_link_test.dart for the signed-out half and for why the
/// link is delivered by the custom scheme and the checks are waits.
void main() {
  patrolAppTest('a signed-in member opens an article from its link', ($) async {
    final article = await aPublishedArticle();
    await signInAsReviewer($);

    await openAppLink($, '/articles/${article.slug}');
    await $(
      article.title,
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    await openAppLink($, '/articles/$missingArticleSlug');
    await $(
      articleGoneMessage,
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $('See all articles').waitUntilVisible();
  });
}
