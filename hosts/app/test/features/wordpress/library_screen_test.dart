import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/core/theme/app_theme.dart';
import 'package:the_strong_rope/features/wordpress/models/publication.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/screens/library_screen.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

const _videos = TsrYouTubeResponse(
  videos: [
    TsrYouTubeVideo(
      id: 'v1',
      videoId: 'abc123',
      title: 'The Rope of Faith',
      youtubeLink: 'https://www.youtube.com/watch?v=abc123',
      publishedDateFormatted: 'Oct 20, 2026',
      views: 12500,
    ),
  ],
);

const _articles = TsrArticlesResponse(
  articles: [
    TsrArticle(
      slug: 'understanding-wilayat',
      title: 'Understanding Wilayat',
      publishedDate: '2026-10-18T09:00:00',
      categories: ['Wilayat'],
      readingTime: 5,
    ),
    TsrArticle(
      slug: 'snippets-for-the-seeker',
      title: 'Snippets for the Seeker',
      readingTime: 3,
    ),
    TsrArticle(
      slug: 'a-question-of-faith',
      title: 'A Question of Faith',
      readingTime: 4,
    ),
    TsrArticle(
      slug: 'an-unseen-fourth-article',
      title: 'An Unseen Fourth Article',
      readingTime: 6,
    ),
  ],
);

const _publications = [
  Publication(
    title: 'A Gift for the Youth',
    type: 'PDF',
    language: 'English',
    readOnlineUrl: 'https://thestrongrope.com/a-gift-for-the-youth',
  ),
  Publication(
    title: 'Quraane Karim',
    type: 'PDF',
    language: 'Hindi',
    file: 'https://thestrongrope.com/downloads/hindi.pdf',
  ),
  Publication(
    title: 'Dua Faakshif',
    language: 'Multilingual',
    readOnlineUrl: 'https://thestrongrope.com/duas/dua-faakshif.html',
  ),
  Publication(
    title: 'A Fourth Publication',
    language: 'English',
    file: 'https://thestrongrope.com/downloads/fourth.pdf',
  ),
];

Widget _wrap({
  Future<TsrYouTubeResponse> Function()? videos,
  Future<TsrArticlesResponse> Function()? articles,
  Future<List<Publication>> Function()? publications,
}) {
  return ProviderScope(
    key: UniqueKey(),
    // A failure is the answer under test; no automatic retries.
    retry: (retryCount, error) => null,
    overrides: [
      tsrYouTubeProvider.overrideWith(
        (ref, args) => (videos ?? () async => _videos)(),
      ),
      tsrArticlesProvider.overrideWith(
        (ref, args) => (articles ?? () async => _articles)(),
      ),
      tsrPublicationsProvider.overrideWith(
        (ref) => (publications ?? () async => _publications)(),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: LibraryScreen()),
          ),
          GoRoute(
            path: AppRoutes.articles,
            builder: (_, _) => const Scaffold(body: Text('articles screen')),
          ),
          GoRoute(
            path: AppRoutes.videos,
            builder: (_, _) => const Scaffold(body: Text('videos screen')),
            routes: [
              GoRoute(
                path: ':videoId',
                builder: (_, state) => Scaffold(
                  body: Text('video ${state.pathParameters['videoId']}'),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.publications,
            builder: (_, _) =>
                const Scaffold(body: Text('publications screen')),
          ),
          GoRoute(
            path: AppRoutes.articleDetail,
            builder: (_, state) =>
                Scaffold(body: Text('article ${state.pathParameters['slug']}')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('shows the latest articles, a featured video and publications', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Latest Articles'), findsOneWidget);
    expect(find.text('Featured Video'), findsOneWidget);
    expect(find.text('Understanding Wilayat'), findsOneWidget);
    expect(find.text('Snippets for the Seeker'), findsOneWidget);
    expect(find.text('A Question of Faith'), findsOneWidget);
    expect(
      find.text('An Unseen Fourth Article'),
      findsNothing,
      reason: 'the Library shows only the three newest articles',
    );
    expect(find.text('The Rope of Faith'), findsOneWidget);
    expect(find.textContaining('12.5K views'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('A Gift for the Youth'), findsOneWidget);
    expect(find.text('Dua Faakshif'), findsOneWidget);
    expect(find.text('A Fourth Publication'), findsNothing);
  });

  testWidgets('fits a narrow phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Understanding Wilayat'), findsOneWidget);
  });

  testWidgets('tapping the featured video opens its page', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('The Rope of Faith'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('The Rope of Faith'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Rope of Faith'));
    await tester.pumpAndSettle();

    expect(find.text('video abc123'), findsOneWidget);
  });

  testWidgets('the shortcuts open the full lists', (tester) async {
    for (final (key, screen) in [
      ('libraryShortcut:articles', 'articles screen'),
      ('libraryShortcut:videos', 'videos screen'),
      ('libraryShortcut:publications', 'publications screen'),
    ]) {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();

      expect(find.text(screen), findsOneWidget, reason: 'for $key');
    }
  });

  testWidgets('tapping an article opens its detail page', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Understanding Wilayat'));
    await tester.pumpAndSettle();

    expect(find.text('article understanding-wilayat'), findsOneWidget);
  });

  testWidgets('a publication without a cover shows the placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    // The website sends no cover images, so every shelf book is a placeholder.
    expect(
      find.byKey(const ValueKey('publicationCoverPlaceholder')),
      findsNWidgets(3),
    );
  });

  testWidgets('an empty section says so without hiding the others', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        videos: () async => const TsrYouTubeResponse(videos: []),
        articles: () async => const TsrArticlesResponse(articles: []),
        publications: () async => const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No articles yet'), findsOneWidget);
    expect(find.text('No videos yet'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('No publications yet'), findsOneWidget);
  });

  testWidgets('a failed section leaves the rest visible and retries alone', (
    tester,
  ) async {
    var videoCalls = 0;
    await tester.pumpWidget(
      _wrap(
        videos: () async {
          videoCalls++;
          if (videoCalls == 1) throw Exception('offline');
          return _videos;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.genericErrorMessage), findsOneWidget);
    expect(find.text('Understanding Wilayat'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Retry'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(videoCalls, 2);
    expect(find.text('The Rope of Faith'), findsOneWidget);
  });
}
