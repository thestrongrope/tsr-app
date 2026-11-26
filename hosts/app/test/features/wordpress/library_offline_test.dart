import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/core/services/saved_copy.dart';
import 'package:the_strong_rope/core/theme/app_theme.dart';
import 'package:the_strong_rope/core/widgets/offline_banner.dart';
import 'package:the_strong_rope/features/wordpress/models/publication.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/screens/library_screen.dart';
import 'package:the_strong_rope/features/wordpress/services/content_cache_service.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// A website that answers, or fails like a device with no network.
class _ScriptedWeb extends TsrWebService {
  bool offline = false;

  DioException get _noNetwork => DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: DioExceptionType.connectionError,
  );

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
    if (offline) throw _noNetwork;
    return const TsrArticlesResponse(
      articles: [TsrArticle(slug: 'a', title: 'Saved Article')],
    );
  }

  @override
  Future<TsrYouTubeResponse> getYouTubeVideos({
    int limit = 10,
    int offset = 0,
  }) async {
    if (offline) throw _noNetwork;
    return const TsrYouTubeResponse(
      videos: [
        TsrYouTubeVideo(
          id: '1',
          videoId: 'abc123',
          title: 'Saved Video',
          youtubeLink: 'https://www.youtube.com/watch?v=abc123',
        ),
      ],
    );
  }

  @override
  Future<List<Publication>> getPublications() async {
    if (offline) throw _noNetwork;
    return const [
      Publication(
        title: 'Saved Publication',
        readOnlineUrl: 'https://x.test/p',
      ),
    ];
  }
}

class _Offline extends OfflineNotifier {
  @override
  bool build() => true;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library_offline');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.cacheBoxKey);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  /// What the Library saves on a successful visit, written the way the
  /// providers write it (real file I/O, so outside the test's fake clock).
  Future<void> saveOnline(WidgetTester tester, DateTime at) =>
      tester.runAsync(() async {
        final web = _ScriptedWeb();
        final cache = ContentCacheService(clock: () => at);
        await cache.cacheArticles(
          'home_latest',
          (await web.getArticles()).articles,
        );
        await cache.cacheVideos((await web.getYouTubeVideos()).videos);
        await cache.cachePublications(await web.getPublications());
      });

  Widget library(_ScriptedWeb web, DateTime now, {bool offline = false}) {
    return ProviderScope(
      key: UniqueKey(),
      retry: (retryCount, error) => null,
      overrides: [
        if (offline) isOfflineProvider.overrideWith(_Offline.new),
        tsrWebServiceProvider.overrideWithValue(web),
        contentCacheServiceProvider.overrideWithValue(
          ContentCacheService(clock: () => now),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => OfflineBanner(child: child!),
        home: const Scaffold(body: LibraryScreen()),
      ),
    );
  }

  testWidgets(
    'offline, the Library shows the saved articles, video and publications '
    'with the offline notice',
    (tester) async {
      final web = _ScriptedWeb();
      final start = DateTime.utc(2026, 10, 1, 12);

      await saveOnline(tester, start);

      // Two days later, with no network.
      web.offline = true;
      await tester.pumpWidget(
        library(web, start.add(const Duration(days: 2)), offline: true),
      );
      await tester.pumpAndSettle();

      expect(find.text(OfflineBanner.message), findsOneWidget);
      expect(find.text('Saved Article'), findsOneWidget);
      expect(find.text('Saved Video'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('Saved Publication'), findsOneWidget);
    },
  );

  testWidgets('a publications copy older than 7 days is not shown', (
    tester,
  ) async {
    final web = _ScriptedWeb();
    final start = DateTime.utc(2026, 10, 1, 12);

    await saveOnline(tester, start);

    web.offline = true;
    await tester.pumpWidget(
      library(web, start.add(savedCopyMaxAge + const Duration(hours: 1))),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('Saved Publication'), findsNothing);
  });
}
