import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../models/article.dart';
import '../models/category.dart';

class WordPressService {
  WordPressService({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;
  static const String _base = 'https://thestrongrope.com/wp-json/wp/v2';

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
    // Optional: simple logging in debug
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

  Future<List<Article>> getArticles({
    int page = 1,
    int perPage = 10,
    List<int>? categories,
    String? search,
  }) async {
    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (categories != null && categories.isNotEmpty)
        'categories': categories.join(','),
      if (search != null && search.isNotEmpty) 'search': search,
      '_embed': 'wp:featuredmedia,author', // Only embed what we need
      '_fields':
          'id,date,title,excerpt,author,featured_media,categories,tags,link,_embedded',
    };

    final res = await _dio.get<List<dynamic>>('/posts', queryParameters: qp);
    final list = res.data ?? const [];
    return list
        .map((e) => mapWpPostToArticle(e as Map<String, dynamic>))
        .toList();
  }

  Future<Article> getArticle(int id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/posts/$id',
      queryParameters: {
        '_embed': '1',
        '_fields':
            'id,date,title,content,excerpt,author,featured_media,categories,tags,link,_embedded',
      },
    );
    return mapWpPostToArticle(res.data!);
  }

  Future<List<Category>> getCategories() async {
    final res = await _dio.get<List<dynamic>>(
      '/categories',
      queryParameters: {
        'per_page': 100,
        'orderby': 'count',
        'order': 'desc',
        '_fields': 'id,name,slug,count,description,link',
      },
    );
    final list = res.data ?? const [];
    return list
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
