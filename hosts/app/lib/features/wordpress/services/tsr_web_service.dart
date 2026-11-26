import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/publication.dart';
import '../models/tsr_article.dart';
import '../models/tsr_lecture.dart';

/// Service for fetching content from TSR Web API (thestrongrope.com)
/// This replaces the WordPress API with the new docs-based API
class TsrWebService {
  TsrWebService({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;
  static const String _base = 'https://thestrongrope.com';

  // Build a dedicated Dio without app auth/device interceptors
  static Dio _buildDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: _base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );
    // Optional: simple logging in debug mode
    if (kDebugMode) {
      d.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      );
    }
    return d;
  }

  /// Get paginated list of articles
  ///
  /// [limit] - Number of items to return (1-100, default 20)
  /// [offset] - Pagination offset (default 0)
  /// [sort] - Sort order: publishedDate:asc, publishedDate:desc, title:asc, title:desc
  /// [search] - Search query
  /// [category] - Filter by category slug
  /// [tag] - Filter by tag
  /// [locale] - Filter by locale
  Future<TsrArticlesResponse> getArticles({
    int limit = 20,
    int offset = 0,
    String sort = 'publishedDate:desc',
    String? search,
    String? category,
    String? tag,
    String? locale,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort': sort,
      if (search != null && search.isNotEmpty) 'q': search,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
    };

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/articles',
        queryParameters: qp,
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Failed to fetch articles');
      }

      final data = responseData['data'] as List<dynamic>? ?? [];
      final pagination = responseData['pagination'] as Map<String, dynamic>?;

      final articles = data
          .map((e) => TsrArticle.fromJson(e as Map<String, dynamic>))
          .toList();

      return TsrArticlesResponse(
        articles: articles,
        pagination: pagination != null
            ? TsrPagination.fromJson(pagination)
            : const TsrPagination(),
      );
    } catch (e) {
      debugPrint('🔴 TsrWebService.getArticles error: $e');
      rethrow;
    }
  }

  /// Get a single article by slug.
  ///
  /// A slug the site does not know answers HTTP 404 with error code
  /// `NOT_FOUND`; both that and a `NOT_FOUND` body throw
  /// `ApiException(404)`, so a caller can tell a missing article from a
  /// network fault (#866).
  Future<TsrArticle> getArticle(String slug) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/articles/$slug',
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        final message = error?['message'] ?? 'Article not found';
        if (error?['code'] == 'NOT_FOUND') throw ApiException(message, 404);
        throw Exception(message);
      }

      final data = responseData['data'] as Map<String, dynamic>;
      return TsrArticle.fromJson(data);
    } on DioException catch (e) {
      debugPrint('🔴 TsrWebService.getArticle error: $e');
      if (e.response?.statusCode == 404) {
        throw ApiException('Article not found', 404);
      }
      rethrow;
    } catch (e) {
      debugPrint('🔴 TsrWebService.getArticle error: $e');
      rethrow;
    }
  }

  /// Search articles
  ///
  /// [query] - Search query string (required)
  /// [limit] - Number of items to return
  /// [offset] - Pagination offset
  /// [category] - Filter by category slug
  /// [fields] - Comma-separated list of fields to search
  Future<TsrSearchResult> searchArticles({
    required String query,
    int limit = 20,
    int offset = 0,
    String? category,
    String? fields,
  }) async {
    final qp = <String, dynamic>{
      'q': query,
      'limit': limit,
      'offset': offset,
      if (category != null && category.isNotEmpty) 'category': category,
      if (fields != null && fields.isNotEmpty) 'fields': fields,
    };

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/search',
        queryParameters: qp,
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Search failed');
      }

      final data = responseData['data'] as Map<String, dynamic>;
      return TsrSearchResult.fromJson(data);
    } catch (e) {
      debugPrint('🔴 TsrWebService.searchArticles error: $e');
      rethrow;
    }
  }

  /// Search the TSR YouTube lectures (#557) on the website's own index.
  ///
  /// [query] - Search query string
  /// [limit] - Number of lectures to return
  Future<TsrLectureSearch> searchLectures({
    required String query,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/lectures/search',
        queryParameters: {'q': query, 'limit': limit},
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Lectures search failed');
      }

      return TsrLectureSearch.fromJson(responseData['data']);
    } catch (e) {
      debugPrint('🔴 TsrWebService.searchLectures error: $e');
      rethrow;
    }
  }

  /// Get all categories
  ///
  /// [hierarchical] - Return hierarchical structure (default true)
  /// [includeArticleCounts] - Include article counts (default true)
  Future<List<TsrCategory>> getCategories({
    bool hierarchical = true,
    bool includeArticleCounts = true,
  }) async {
    final qp = <String, dynamic>{
      'hierarchical': hierarchical,
      'includeArticleCounts': includeArticleCounts,
    };

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/taxonomies/categories',
        queryParameters: qp,
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Failed to fetch categories');
      }

      final data = responseData['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => TsrCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('🔴 TsrWebService.getCategories error: $e');
      rethrow;
    }
  }

  /// Get articles by category slug
  Future<TsrCategoryArticlesResponse> getArticlesByCategory(
    String categorySlug, {
    int limit = 20,
    int offset = 0,
    String sort = 'publishedDate:desc',
    String? search,
    String? tag,
    String? locale,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort': sort,
      if (search != null && search.isNotEmpty) 'q': search,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
    };

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/taxonomies/categories/$categorySlug/articles',
        queryParameters: qp,
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(
          error?['message'] ?? 'Failed to fetch category articles',
        );
      }

      final data = responseData['data'] as Map<String, dynamic>;
      final categoryData = data['category'] as Map<String, dynamic>?;
      final articlesData = data['articles'] as List<dynamic>? ?? [];

      return TsrCategoryArticlesResponse(
        category: categoryData != null
            ? TsrCategory.fromJson(categoryData)
            : null,
        articles: articlesData
            .map((e) => TsrArticle.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      debugPrint('🔴 TsrWebService.getArticlesByCategory error: $e');
      rethrow;
    }
  }

  /// Get all tags
  Future<List<TsrTag>> getTags() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/taxonomies/tags',
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Failed to fetch tags');
      }

      final data = responseData['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => TsrTag.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('🔴 TsrWebService.getTags error: $e');
      rethrow;
    }
  }

  /// Get YouTube channel videos
  ///
  /// [limit] - Number of videos to return (1-50, default 10)
  /// [offset] - Pagination offset
  Future<TsrYouTubeResponse> getYouTubeVideos({
    int limit = 10,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{'limit': limit, 'offset': offset};

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/youtube',
        queryParameters: qp,
      );

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Failed to fetch YouTube videos');
      }

      final data = responseData['data'] as Map<String, dynamic>;
      final videosData = data['videos'] as List<dynamic>? ?? [];
      final metaData = data['meta'] as Map<String, dynamic>?;

      return TsrYouTubeResponse(
        videos: videosData
            .map((e) => TsrYouTubeVideo.fromJson(e as Map<String, dynamic>))
            .toList(),
        meta: metaData != null ? TsrYouTubeMeta.fromJson(metaData) : null,
      );
    } catch (e) {
      debugPrint('🔴 TsrWebService.getYouTubeVideos error: $e');
      rethrow;
    }
  }

  /// Get every publication the website's publications page lists.
  ///
  /// The website sends links site-relative; they are resolved here so the
  /// rest of the app only sees full URLs. Not cached: the website may move a
  /// publication's reading page, and the app must follow it.
  Future<List<Publication>> getPublications() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/publications');

      final responseData = res.data!;
      final success = responseData['success'] as bool? ?? false;

      if (!success) {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Failed to fetch publications');
      }

      final site = Uri.parse(_base);
      String? resolve(String? path) =>
          path == null ? null : site.resolve(path).toString();

      final data = responseData['data'] as List<dynamic>? ?? [];
      return data.map((e) {
        final p = Publication.fromJson(e as Map<String, dynamic>);
        return p.copyWith(
          file: resolve(p.file),
          readOnlineUrl: resolve(p.readOnlineUrl),
        );
      }).toList();
    } catch (e) {
      debugPrint('🔴 TsrWebService.getPublications error: $e');
      rethrow;
    }
  }
}

/// Response wrapper for articles list
class TsrArticlesResponse {
  final List<TsrArticle> articles;
  final TsrPagination pagination;

  const TsrArticlesResponse({
    required this.articles,
    this.pagination = const TsrPagination(),
  });
}

/// Response wrapper for category articles
class TsrCategoryArticlesResponse {
  final TsrCategory? category;
  final List<TsrArticle> articles;

  const TsrCategoryArticlesResponse({this.category, required this.articles});
}

/// Response wrapper for YouTube videos
class TsrYouTubeResponse {
  final List<TsrYouTubeVideo> videos;
  final TsrYouTubeMeta? meta;

  const TsrYouTubeResponse({required this.videos, this.meta});
}
