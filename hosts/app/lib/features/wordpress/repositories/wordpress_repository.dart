import 'dart:convert';
import 'package:hive_ce/hive.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../services/wordpress_service.dart';
import '../../../core/constants/app_constants.dart';

class WordPressRepository {
  WordPressRepository(this._service, this._cacheBox);

  final WordPressService _service;
  final Box _cacheBox;

  static const _articlesKey = 'wp_articles_cache_v1';
  static const _categoriesKey = 'wp_categories_cache_v1';
  static const _offlineArticlesKey = 'wp_offline_articles_v1';

  // Fetch articles with cache-first strategy
  Future<List<Article>> getArticles({
    int page = 1,
    int perPage = 10,
    int? categoryId,
    String? q,
    bool forceRefresh = false,
  }) async {
    final cacheId =
        '$_articlesKey|p=$page|s=$perPage|c=${categoryId ?? ''}|q=${q ?? ''}';
    final now = DateTime.now();

    if (!forceRefresh) {
      final cached = _cacheBox.get(cacheId) as Map?;
      if (cached != null) {
        final ts = DateTime.tryParse(cached['ts'] as String? ?? '') ?? now;
        if (now.difference(ts) < AppConstants.shortCacheExpiration) {
          final list = (cached['data'] as List)
              .map((e) => Article.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return list;
        }
      }
    }

    final articles = await _service.getArticles(
      page: page,
      perPage: perPage,
      categories: categoryId != null ? [categoryId] : null,
      search: q,
    );

    _cacheBox.put(cacheId, {
      'ts': now.toIso8601String(),
      'data': articles.map((a) => a.toJson()).toList(),
    });

    return articles;
  }

  Future<Article> getArticle(int id, {bool preferCache = true}) async {
    // Check offline saved first
    final offline = _getOfflineMap();
    final saved = offline['$id'];
    if (preferCache && saved is Map) {
      return Article.fromJson(Map<String, dynamic>.from(saved));
    }

    // Then check cached detail
    final cacheId = 'wp_article_detail_$id';
    final now = DateTime.now();
    final cached = _cacheBox.get(cacheId) as Map?;
    if (preferCache && cached != null) {
      final ts = DateTime.tryParse(cached['ts'] as String? ?? '') ?? now;
      if (now.difference(ts) < AppConstants.cacheExpiration) {
        return Article.fromJson(Map<String, dynamic>.from(cached['data']));
      }
    }

    final a = await _service.getArticle(id);
    _cacheBox.put(cacheId, {'ts': now.toIso8601String(), 'data': a.toJson()});
    return a;
  }

  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _cacheBox.get(_categoriesKey) as Map?;
    if (!forceRefresh && cached != null) {
      final ts = DateTime.tryParse(cached['ts'] as String? ?? '') ?? now;
      if (now.difference(ts) < AppConstants.categoryCacheDuration) {
        final list = (cached['data'] as List)
            .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return list;
      }
    }
    final cats = await _service.getCategories();
    _cacheBox.put(_categoriesKey, {
      'ts': now.toIso8601String(),
      'data': cats.map((c) => c.toJson()).toList(),
    });
    return cats;
  }

  // Offline management
  Map<String, dynamic> _getOfflineMap() {
    final raw = _cacheBox.get(_offlineArticlesKey);
    if (raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<void> saveOffline(Article a) async {
    final map = _getOfflineMap();
    map['${a.id}'] = a.toJson();
    await _cacheBox.put(_offlineArticlesKey, jsonEncode(map));
  }

  Future<void> removeOffline(int id) async {
    final map = _getOfflineMap();
    map.remove('$id');
    await _cacheBox.put(_offlineArticlesKey, jsonEncode(map));
  }

  Future<bool> isOfflineSaved(int id) async {
    final map = _getOfflineMap();
    return map.containsKey('$id');
  }

  Future<List<Article>> getOfflineArticles() async {
    final map = _getOfflineMap();
    return map.values
        .map(
          (v) => Article.fromJson(
            Map<String, dynamic>.from(
              v is String ? jsonDecode(v) as Map<String, dynamic> : v as Map,
            ),
          ),
        )
        .toList();
  }
}
