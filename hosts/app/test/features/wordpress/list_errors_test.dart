import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/theme/app_theme.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/screens/all_articles_screen.dart';
import 'package:the_strong_rope/features/wordpress/screens/all_videos_screen.dart';
import 'package:the_strong_rope/features/wordpress/services/content_cache_service.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

const _technical = 'SqlException: SELECT secret FROM members #stack-trace';

/// A website that fails with a technical message until [failing] is false.
class _FailingWeb extends TsrWebService {
  bool failing = true;
  int videoCalls = 0;
  int articleCalls = 0;

  @override
  Future<List<TsrCategory>> getCategories({
    bool hierarchical = true,
    bool includeArticleCounts = true,
  }) async => const [];

  @override
  Future<List<TsrTag>> getTags() async => const [];

  @override
  Future<TsrArticlesResponse> getArticles({
    int limit = 20,
    int offset = 0,
    String sort = 'publishedDate:desc',
    String? search,
    String? category,
    String? tag,
    String? locale,
  }) async {
    articleCalls++;
    if (failing) throw Exception(_technical);
    return const TsrArticlesResponse(articles: []);
  }

  @override
  Future<TsrYouTubeResponse> getYouTubeVideos({
    int limit = 10,
    int offset = 0,
  }) async {
    videoCalls++;
    if (failing) throw Exception(_technical);
    return const TsrYouTubeResponse(videos: []);
  }
}

/// Reads the real box but writes nothing, so a successful load does not wait
/// on file I/O outside the test's fake clock.
class _ReadOnlyCache extends ContentCacheService {
  _ReadOnlyCache(DateTime now) : super(clock: () => now);

  @override
  Future<void> cacheAllVideos(List<TsrYouTubeVideo> videos) async {}

  @override
  Future<void> cacheCategories(List<TsrCategory> categories) async {}

  @override
  Future<void> cacheTags(List<TsrTag> tags) async {}

  @override
  Future<void> cacheArticles(String key, List<TsrArticle> articles) async {}
}

void main() {
  late Directory dir;
  final saved = DateTime.utc(2026, 10, 1, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('list_errors');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.cacheBoxKey);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Widget app(_FailingWeb web, Widget screen) {
    return ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tsrWebServiceProvider.overrideWithValue(web),
        contentCacheServiceProvider.overrideWithValue(_ReadOnlyCache(saved)),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
    );
  }

  void expectNothingTechnical(WidgetTester tester) {
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('SELECT'), findsNothing);
    expect(find.textContaining('stack'), findsNothing);
  }

  final screens = <String, Widget Function()>{
    'videos': AllVideosScreen.new,
    'articles': AllArticlesScreen.new,
  };

  for (final entry in screens.entries) {
    final name = entry.key;

    testWidgets('$name: a failed load shows a plain message with Retry', (
      tester,
    ) async {
      await tester.pumpWidget(app(_FailingWeb(), entry.value()));
      await tester.pumpAndSettle();

      expect(find.text(AppConstants.genericErrorMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expectNothingTechnical(tester);
    });

    testWidgets('$name: Retry loads the list again', (tester) async {
      final web = _FailingWeb();
      await tester.pumpWidget(app(web, entry.value()));
      await tester.pumpAndSettle();

      web.failing = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(find.text(AppConstants.genericErrorMessage), findsNothing);
      expect(name == 'videos' ? web.videoCalls : web.articleCalls, 2);
    });

    testWidgets('$name: when Retry fails again the message and Retry stay', (
      tester,
    ) async {
      final web = _FailingWeb();
      await tester.pumpWidget(app(web, entry.value()));
      await tester.pumpAndSettle();
      final calls = name == 'videos' ? web.videoCalls : web.articleCalls;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      final after = name == 'videos' ? web.videoCalls : web.articleCalls;
      expect(after, greaterThan(calls));
      expect(find.text(AppConstants.genericErrorMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expectNothingTechnical(tester);
    });

    testWidgets('$name: a saved copy shows above the message', (tester) async {
      final cache = ContentCacheService(clock: () => saved);
      if (name == 'videos') {
        await tester.runAsync(
          () => cache.cacheAllVideos(const [
            TsrYouTubeVideo(
              id: '1',
              videoId: 'abc123',
              title: 'Saved Video',
              youtubeLink: 'https://www.youtube.com/watch?v=abc123',
            ),
          ]),
        );
      } else {
        await tester.runAsync(
          () => cache.cacheArticles('all', const [
            TsrArticle(slug: 's', title: 'Saved Article'),
          ]),
        );
      }

      // The saved copy shows on opening; a pull to refresh then fails.
      final web = _FailingWeb();
      await tester.pumpWidget(app(web, entry.value()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      if (name == 'videos') {
        await container
            .read(allVideosProvider.notifier)
            .loadVideos(refresh: true);
      } else {
        await container
            .read(allArticlesProvider.notifier)
            .loadArticles(refresh: true);
      }
      await tester.pumpAndSettle();
      final title = name == 'videos' ? 'Saved Video' : 'Saved Article';

      expect(find.text(title), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text(title)).dy,
        lessThan(tester.getTopLeft(find.text('Retry')).dy),
      );
      expectNothingTechnical(tester);
    });
  }
}
