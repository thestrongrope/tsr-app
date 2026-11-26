import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../../../core/services/saved_copy.dart';
import '../models/publication.dart';
import '../models/tsr_article.dart';
import '../services/tsr_web_service.dart';
import '../services/content_cache_service.dart';

/// Provider for the TSR Web Service
final tsrWebServiceProvider = Provider<TsrWebService>((ref) {
  return TsrWebService();
});

/// Provider for the Content Cache Service
final contentCacheServiceProvider = Provider<ContentCacheService>((ref) {
  return ContentCacheService();
});

/// State providers for filtering
final selectedTsrCategoryProvider = StateProvider<String?>((ref) => null);
final tsrSearchQueryProvider = StateProvider<String>((ref) => '');

/// Categories provider - cached for 24 hours
final tsrCategoriesProvider = FutureProvider<List<TsrCategory>>((ref) async {
  final cacheService = ref.read(contentCacheServiceProvider);
  final service = ref.read(tsrWebServiceProvider);

  // Try to get from cache first
  final cached = await cacheService.getCachedCategories();
  if (cached != null) {
    return cached;
  }

  // Fetch from API and cache
  final categories = await service.getCategories();
  await cacheService.cacheCategories(categories);
  return categories;
});

/// Tags provider - cached for 24 hours
final tsrTagsProvider = FutureProvider<List<TsrTag>>((ref) async {
  final cacheService = ref.read(contentCacheServiceProvider);
  final service = ref.read(tsrWebServiceProvider);

  // Try to get from cache first
  final cached = await cacheService.getCachedTags();
  if (cached != null) {
    return cached;
  }

  // Fetch from API and cache
  final tags = await service.getTags();
  await cacheService.cacheTags(tags);
  return tags;
});

/// Articles provider with pagination support
/// Uses cache service for 1-hour caching and keepAlive to prevent disposal on navigation
final tsrArticlesProvider = FutureProvider.autoDispose
    .family<
      TsrArticlesResponse,
      ({int limit, int offset, String? category, String? search})
    >((ref, args) async {
      // Keep provider alive to prevent disposal on navigation
      ref.keepAlive();

      final cacheService = ref.read(contentCacheServiceProvider);
      final service = ref.read(tsrWebServiceProvider);

      final isHomeLatest =
          args.limit == 5 &&
          args.offset == 0 &&
          args.category == null &&
          args.search == null;

      // Try to get from cache first (only for home screen initial load)
      if (isHomeLatest) {
        final cached = await cacheService.getCachedArticles('home_latest');
        if (cached != null && cached.isNotEmpty) {
          return TsrArticlesResponse(articles: cached);
        }
      }

      // Fetch from API; when the server cannot be reached the Home screen
      // falls back to a copy under [savedCopyMaxAge] old
      final TsrArticlesResponse response;
      try {
        response = await service.getArticles(
          limit: args.limit,
          offset: args.offset,
          category: args.category,
          search: args.search,
        );
      } catch (e) {
        if (!isUnreachable(e) || !isHomeLatest) rethrow;
        final saved = await cacheService.getCachedArticles(
          'home_latest',
          maxAge: savedCopyMaxAge,
        );
        if (saved == null || saved.isEmpty) rethrow;
        return TsrArticlesResponse(articles: saved);
      }

      // Cache only home screen initial load
      if (isHomeLatest) {
        await cacheService.cacheArticles('home_latest', response.articles);
      }

      // Lazy-cache top article details for offline reading (first page only)
      if (args.offset == 0 && args.category == null && args.search == null) {
        unawaited(
          cacheService.prefetchArticleDetails(
            response.articles,
            fetchDetail: service.getArticle,
          ),
        );
      }

      return response;
    });

/// Article detail provider by slug
/// Cache-first: serves cached article for offline access, refreshes from API
///
/// No automatic retry: Riverpod's default keeps the screen loading for about
/// 40 seconds before a failure shows (#1121). A failure is shown at once, with
/// a Retry button.
final tsrArticleDetailProvider = FutureProvider.family<TsrArticle, String>((
  ref,
  slug,
) async {
  final cacheService = ref.read(contentCacheServiceProvider);
  final service = ref.read(tsrWebServiceProvider);

  // Try cache first for offline access
  final cached = await cacheService.getCachedArticle(slug);
  if (cached != null) {
    return cached;
  }

  // Fetch from API and cache for offline access
  final article = await service.getArticle(slug);
  await cacheService.cacheArticle(article);
  return article;
}, retry: (retryCount, error) => null);

/// Search provider
final tsrSearchProvider = FutureProvider.autoDispose
    .family<
      TsrSearchResult,
      ({String query, int limit, int offset, String? category})
    >((ref, args) async {
      final service = ref.read(tsrWebServiceProvider);
      return service.searchArticles(
        query: args.query,
        limit: args.limit,
        offset: args.offset,
        category: args.category,
      );
    });

/// YouTube videos provider
/// Uses cache service for 1-hour caching and keepAlive to prevent disposal on navigation
final tsrYouTubeProvider = FutureProvider.autoDispose
    .family<TsrYouTubeResponse, ({int limit, int offset})>((ref, args) async {
      // Keep provider alive to prevent disposal on navigation
      ref.keepAlive();

      final cacheService = ref.read(contentCacheServiceProvider);
      final service = ref.read(tsrWebServiceProvider);

      final isHome = args.limit == 5 && args.offset == 0;

      // Try to get from cache first (only for home screen initial load)
      if (isHome) {
        final cached = await cacheService.getCachedVideos();
        if (cached != null && cached.isNotEmpty) {
          return TsrYouTubeResponse(videos: cached);
        }
      }

      // Fetch from API; when the server cannot be reached the Home screen
      // falls back to a copy under [savedCopyMaxAge] old
      final TsrYouTubeResponse response;
      try {
        response = await service.getYouTubeVideos(
          limit: args.limit,
          offset: args.offset,
        );
      } catch (e) {
        if (!isUnreachable(e) || !isHome) rethrow;
        final saved = await cacheService.getCachedVideos(
          maxAge: savedCopyMaxAge,
        );
        if (saved == null || saved.isEmpty) rethrow;
        return TsrYouTubeResponse(videos: saved);
      }

      // Cache only home screen initial load
      if (isHome) {
        await cacheService.cacheVideos(response.videos);
      }

      return response;
    });

/// Every publication the website lists. Disposed when the screen closes, so
/// each visit follows wherever the website now points. The list is saved on
/// every successful fetch; when the server cannot be reached the saved copy
/// (under [savedCopyMaxAge] old) is shown instead.
///
/// No automatic retry: Riverpod's default keeps the screen loading through
/// ten retries (about 40 seconds) before an error shows. A failure is shown
/// at once, with a Retry button.
final tsrPublicationsProvider = FutureProvider.autoDispose<List<Publication>>((
  ref,
) async {
  final cacheService = ref.read(contentCacheServiceProvider);
  try {
    final publications = await ref
        .read(tsrWebServiceProvider)
        .getPublications();
    await cacheService.cachePublications(publications);
    return publications;
  } catch (e) {
    if (!isUnreachable(e)) rethrow;
    final saved = cacheService.getCachedPublications(maxAge: savedCopyMaxAge);
    if (saved == null || saved.isEmpty) rethrow;
    return saved;
  }
}, retry: (retryCount, error) => null);
