import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/services/saved_copy.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/services/content_cache_service.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// A website that either answers with [videos] or fails with [failure].
class _ScriptedWeb extends TsrWebService {
  List<TsrYouTubeVideo> videos = const [];
  Object? failure;

  @override
  Future<TsrYouTubeResponse> getYouTubeVideos({
    int limit = 10,
    int offset = 0,
  }) async {
    final f = failure;
    if (f != null) throw f;
    return TsrYouTubeResponse(videos: videos);
  }
}

TsrYouTubeVideo _video(String title) => TsrYouTubeVideo(
  id: '1',
  videoId: 'abc',
  title: title,
  youtubeLink: 'https://example.test/v',
);

DioException _dio(DioExceptionType type, {int? status}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: request, statusCode: status),
  );
}

void main() {
  late Directory dir;
  late _ScriptedWeb web;
  var now = DateTime.utc(2026, 10, 1, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('home_saved_copy');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.cacheBoxKey);
    now = DateTime.utc(2026, 10, 1, 12);
    web = _ScriptedWeb();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<TsrYouTubeResponse> homeVideos() {
    // No automatic retry: a failure is the answer under test.
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        tsrWebServiceProvider.overrideWithValue(web),
        contentCacheServiceProvider.overrideWithValue(
          ContentCacheService(clock: () => now),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(tsrYouTubeProvider((limit: 5, offset: 0)).future);
  }

  Future<void> saveOnce() async {
    web.videos = [_video('Saved lecture')];
    await homeVideos();
  }

  test('offline: videos saved under 7 days ago are shown', () async {
    await saveOnce();

    now = now.add(savedCopyMaxAge - const Duration(minutes: 1));
    web.failure = _dio(DioExceptionType.connectionError);
    expect((await homeVideos()).videos.single.title, 'Saved lecture');
  });

  test('offline: videos saved over 7 days ago are not shown', () async {
    await saveOnce();

    now = now.add(savedCopyMaxAge + const Duration(minutes: 1));
    web.failure = _dio(DioExceptionType.connectionError);
    await expectLater(homeVideos(), throwsA(isA<DioException>()));
  });

  test('a refusal does not show the saved videos', () async {
    await saveOnce();

    now = now.add(const Duration(hours: 2));
    web.failure = _dio(DioExceptionType.badResponse, status: 403);
    await expectLater(homeVideos(), throwsA(isA<DioException>()));
  });

  test('a working network past the hour shows fresh videos', () async {
    await saveOnce();

    now = now.add(const Duration(hours: 2));
    web.videos = [_video('Fresh lecture')];
    expect((await homeVideos()).videos.single.title, 'Fresh lecture');
  });
}
