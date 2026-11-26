import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/saved_copy.dart';
import '../models/publication.dart';
import '../models/tsr_article.dart';

/// Cache service for WordPress/TSR content
/// Uses Hive for persistent local storage
class ContentCacheService {
  /// [clock] is for tests that move time.
  ContentCacheService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const _categoriesKey = 'tsr_categories';
  static const _tagsKey = 'tsr_tags';
  static const _articlesKey = 'tsr_articles';
  static const _articleDetailKey = 'tsr_article_detail';
  static const _videosKey = 'tsr_videos';
  static const _allVideosKey = 'tsr_all_videos';
  static const _publicationsKey = 'tsr_publications';

  // Cache TTL - 24 hours for categories/tags, 1 hour for content
  static const _taxonomyTtlMillis = 24 * 60 * 60 * 1000; // 24 hours
  static const _contentTtlMillis = 60 * 60 * 1000; // 1 hour
  static const _contentTtl = Duration(milliseconds: _contentTtlMillis);

  Box get _box => Hive.box(AppConstants.cacheBoxKey);

  // ===== Categories =====

  Future<List<TsrCategory>?> getCachedCategories() async {
    try {
      final data = _box.get(_categoriesKey);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final updatedAt = map['updatedAt'] as int?;
        if (updatedAt != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - updatedAt <= _taxonomyTtlMillis) {
            final payload = map['payload'] as List<dynamic>;
            return payload
                .map(_deepNormalize)
                .whereType<Map<String, dynamic>>()
                .map(TsrCategory.fromJson)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 ContentCacheService.getCachedCategories error: $e');
    }
    return null;
  }

  Future<void> cacheCategories(List<TsrCategory> categories) async {
    try {
      await _box.put(_categoriesKey, {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'payload': categories.map(_categoryToJson).toList(),
      });
    } catch (e) {
      debugPrint('🔴 ContentCacheService.cacheCategories error: $e');
    }
  }

  // ===== Tags =====

  Future<List<TsrTag>?> getCachedTags() async {
    try {
      final data = _box.get(_tagsKey);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final updatedAt = map['updatedAt'] as int?;
        if (updatedAt != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - updatedAt <= _taxonomyTtlMillis) {
            final payload = map['payload'] as List<dynamic>;
            return payload
                .map(_deepNormalize)
                .whereType<Map<String, dynamic>>()
                .map(TsrTag.fromJson)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 ContentCacheService.getCachedTags error: $e');
    }
    return null;
  }

  Future<void> cacheTags(List<TsrTag> tags) async {
    try {
      await _box.put(_tagsKey, {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'payload': tags.map((t) => t.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('🔴 ContentCacheService.cacheTags error: $e');
    }
  }

  // ===== Articles =====

  /// Get cached articles list
  /// [key] - unique key for the specific query (e.g., "all" or "category:slug")
  ///
  /// [maxAge] defaults to the 1-hour freshness window. The Home screen asks
  /// again with [savedCopyMaxAge] when the network fails, to show the saved copy.
  Future<List<TsrArticle>?> getCachedArticles(
    String key, {
    Duration? maxAge,
  }) async {
    final maxAgeMillis = (maxAge ?? _contentTtl).inMilliseconds;
    try {
      final data = _box.get('${_articlesKey}_$key');
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final updatedAt = map['updatedAt'] as int?;
        if (updatedAt != null) {
          final now = _clock().millisecondsSinceEpoch;
          if (now - updatedAt <= maxAgeMillis) {
            final payload = map['payload'] as List<dynamic>;
            return payload
                .map(_deepNormalize)
                .whereType<Map<String, dynamic>>()
                .map(TsrArticle.fromJson)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 ContentCacheService.getCachedArticles error: $e');
    }
    return null;
  }

  Future<void> cacheArticles(String key, List<TsrArticle> articles) async {
    try {
      await _box.put('${_articlesKey}_$key', {
        'updatedAt': _clock().millisecondsSinceEpoch,
        'payload': articles.map((a) => a.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('🔴 ContentCacheService.cacheArticles error: $e');
    }
  }

  // ===== Article Detail =====

  /// Get cached article detail by slug (for offline reading)
  Future<TsrArticle?> getCachedArticle(String slug) async {
    try {
      final data = _box.get('${_articleDetailKey}_$slug');
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final updatedAt = map['updatedAt'] as int?;
        if (updatedAt != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - updatedAt <= _contentTtlMillis) {
            final payload = map['payload'];
            if (payload is Map) {
              final normalized = _deepNormalize(payload);
              if (normalized is Map<String, dynamic>) {
                return TsrArticle.fromJson(normalized);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 ContentCacheService.getCachedArticle error: $e');
    }
    return null;
  }

  Future<void> cacheArticle(TsrArticle article) async {
    try {
      await _box.put('${_articleDetailKey}_${article.slug}', {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'payload': article.toJson(),
      });
    } catch (e) {
      debugPrint('🔴 ContentCacheService.cacheArticle error: $e');
    }
  }

  /// Lazily cache the details of the top [limit] articles so they are readable
  /// offline. Fire-and-forget: never throws and skips already-cached articles.
  Future<void> prefetchArticleDetails(
    List<TsrArticle> articles, {
    required Future<TsrArticle> Function(String slug) fetchDetail,
    int limit = 10,
  }) async {
    final top = articles.take(limit).toList();
    for (final article in top) {
      try {
        final cached = await getCachedArticle(article.slug);
        if (cached != null) continue;
        final detail = await fetchDetail(article.slug);
        await cacheArticle(detail);
      } catch (e) {
        debugPrint('🔴 ContentCacheService.prefetchArticleDetails error: $e');
      }
    }
  }

  // ===== Videos =====

  /// [maxAge] defaults to the 1-hour freshness window. The Home screen asks
  /// again with [savedCopyMaxAge] when the network fails, to show the saved copy.
  Future<List<TsrYouTubeVideo>?> getCachedVideos({Duration? maxAge}) async {
    return _readVideos(_videosKey, maxAge: maxAge);
  }

  Future<void> cacheVideos(List<TsrYouTubeVideo> videos) async {
    await _writeVideos(_videosKey, videos);
  }

  /// The list behind the Videos page, kept apart from the five-video Home
  /// cache so neither page mistakes the other's list for its own.
  Future<List<TsrYouTubeVideo>?> getCachedAllVideos({Duration? maxAge}) async {
    return _readVideos(_allVideosKey, maxAge: maxAge);
  }

  Future<void> cacheAllVideos(List<TsrYouTubeVideo> videos) async {
    await _writeVideos(_allVideosKey, videos);
  }

  Future<List<TsrYouTubeVideo>?> _readVideos(
    String key, {
    Duration? maxAge,
  }) async {
    final maxAgeMillis = (maxAge ?? _contentTtl).inMilliseconds;
    try {
      final data = _box.get(key);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final updatedAt = map['updatedAt'] as int?;
        if (updatedAt != null) {
          final now = _clock().millisecondsSinceEpoch;
          if (now - updatedAt <= maxAgeMillis) {
            final payload = map['payload'] as List<dynamic>;
            return payload
                .map(_deepNormalize)
                .whereType<Map<String, dynamic>>()
                .map(TsrYouTubeVideo.fromJson)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 ContentCacheService.getCachedVideos error: $e');
    }
    return null;
  }

  Future<void> _writeVideos(String key, List<TsrYouTubeVideo> videos) async {
    try {
      await _box.put(key, {
        'updatedAt': _clock().millisecondsSinceEpoch,
        'payload': videos.map(_videoToJson).toList(),
      });
    } catch (e) {
      debugPrint('🔴 ContentCacheService.cacheVideos error: $e');
    }
  }

  // ===== Publications =====

  /// The last publication list saved, or null when there is none, it is
  /// [maxAge] old or older, or it cannot be read. Public website content, so
  /// it is not tied to a member; sign-out and account deletion clear it with
  /// the rest of the content caches.
  List<Publication>? getCachedPublications({required Duration maxAge}) {
    try {
      final data = _box.get(_publicationsKey);
      if (data is! Map) return null;
      final updatedAt = data['updatedAt'] as int?;
      if (updatedAt == null) return null;
      final age = _clock().millisecondsSinceEpoch - updatedAt;
      if (age >= maxAge.inMilliseconds) return null;
      final payload = _deepNormalize(data['payload']) as List<dynamic>;
      return payload
          .map((e) => Publication.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('🔴 ContentCacheService.getCachedPublications error: $e');
      return null;
    }
  }

  Future<void> cachePublications(List<Publication> publications) async {
    try {
      await _box.put(_publicationsKey, {
        'updatedAt': _clock().millisecondsSinceEpoch,
        'payload': publications.map((p) => p.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('🔴 ContentCacheService.cachePublications error: $e');
    }
  }

  // ===== Clear Cache =====

  Future<void> clearAllCache() async {
    try {
      await _box.delete(_categoriesKey);
      await _box.delete(_tagsKey);
      // Delete all article caches
      final keys = _box.keys.where(
        (k) => k.toString().startsWith(_articlesKey),
      );
      for (final key in keys) {
        await _box.delete(key);
      }
      // Delete all article detail caches
      final detailKeys = _box.keys.where(
        (k) => k.toString().startsWith(_articleDetailKey),
      );
      for (final key in detailKeys) {
        await _box.delete(key);
      }
      await _box.delete(_videosKey);
      await _box.delete(_allVideosKey);
      await _box.delete(_publicationsKey);
    } catch (e) {
      debugPrint('🔴 ContentCacheService.clearAllCache error: $e');
    }
  }
}

dynamic _deepNormalize(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry(key.toString(), _deepNormalize(val)),
    );
  }
  if (value is List) {
    return value.map(_deepNormalize).toList();
  }
  return value;
}

Map<String, dynamic> _categoryToJson(TsrCategory category) {
  return {
    'slug': category.slug,
    'title': category.title,
    'description': category.description,
    'articleCount': category.articleCount,
    'subcategories': category.subcategories.map(_categoryToJson).toList(),
  };
}

Map<String, dynamic> _videoToJson(TsrYouTubeVideo video) {
  return {
    'id': video.id,
    'videoId': video.videoId,
    'title': video.title,
    'youtubeLink': video.youtubeLink,
    'publishedDate': video.publishedDate,
    'publishedDateFormatted': video.publishedDateFormatted,
    'views': video.views,
    'intro': video.intro,
    'description': video.description,
    'thumbnail': _thumbnailToJson(video.thumbnail),
  };
}

Map<String, dynamic>? _thumbnailToJson(TsrThumbnail? thumbnail) {
  if (thumbnail == null) return null;
  return {
    'url': thumbnail.url,
    'width': thumbnail.width,
    'height': thumbnail.height,
  };
}
