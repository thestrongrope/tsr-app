import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/screens/tsr_article_detail_screen.dart';

/// An article opened from a shared link (#1121): what the screen says when the
/// article is gone or the device is offline, and how the back arrow behaves
/// when the link was the only screen.
void main() {
  const slug = 'on-patience';

  Future<GoRouter> pumpLink(
    WidgetTester tester,
    Future<TsrArticle> Function(String) load,
  ) async {
    final router = GoRouter(
      initialLocation: '/articles/$slug',
      routes: [
        GoRoute(
          path: AppRoutes.articleDetail,
          builder: (_, state) => TsrArticleDetailScreen(
            articleSlug: state.pathParameters['slug']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.articles,
          builder: (_, _) => const Text('Article list'),
        ),
        GoRoute(
          path: AppRoutes.library,
          builder: (_, _) => const Text('Library page'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [tsrArticleDetailProvider.overrideWith((ref, s) => load(s))],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a deleted article is named as gone and offers the list', (
    tester,
  ) async {
    await pumpLink(tester, (_) async => throw ApiException('Not found', 404));

    expect(find.text('This article is no longer available.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.text('See all articles'));
    await tester.pumpAndSettle();
    expect(find.text('Article list'), findsOneWidget);
  });

  testWidgets('offline: says so and Retry loads the article again', (
    tester,
  ) async {
    var calls = 0;
    await pumpLink(tester, (_) async {
      calls++;
      if (calls == 1) throw ApiException(AppConstants.networkErrorMessage, 0);
      return const TsrArticle(slug: slug, title: 'On Patience');
    });

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('On Patience'), findsOneWidget);
  });

  testWidgets('a dropped connection reads as offline, not as a raw error', (
    tester,
  ) async {
    await pumpLink(
      tester,
      (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('back from a link that was the only screen goes to Library', (
    tester,
  ) async {
    await pumpLink(
      tester,
      (_) async => const TsrArticle(slug: slug, title: 'On Patience'),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Library page'), findsOneWidget);
  });
}
