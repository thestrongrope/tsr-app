import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// Delivers an app link to the running app by the custom scheme, the way a tap
/// on the https link would. A debug build on the emulator cannot verify the
/// https links (no assetlinks match for the debug key), so the journeys use
/// `thestrongrope://app/<path>`, which the manifest declares for development.
/// The router sees the same `/<path>` either way.
Future<void> openAppLink(PatrolIntegrationTester $, String path) async {
  await $.platform.mobile.openUrl('thestrongrope://app$path');
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// A published article the website lists right now, read the way the Library
/// does (a public GET). Journeys cannot hardcode one: articles come and go.
Future<TsrArticle> aPublishedArticle() async {
  final response = await TsrWebService().getArticles(limit: 1);
  if (response.articles.isEmpty) {
    throw StateError('the website lists no articles to open');
  }
  return response.articles.first;
}

/// The words the article screen shows for an article that was removed.
const articleGoneMessage = 'This article is no longer available.';

/// A slug no article has.
const missingArticleSlug = 'patrol-no-such-article';
