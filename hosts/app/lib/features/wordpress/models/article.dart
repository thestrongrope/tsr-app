import 'package:freezed_annotation/freezed_annotation.dart';

part 'article.freezed.dart';
part 'article.g.dart';

@freezed
sealed class Article with _$Article {
  const factory Article({
    required int id,
    required DateTime date,
    required String title, // plain text title
    required String content, // full html content
    required String excerpt, // html excerpt
    required String link,
    required int author,
    required int featuredMedia,
    required List<int> categories,
    required List<int> tags,
    String? featuredImageUrl,
  }) = _Article;

  factory Article.fromJson(Map<String, dynamic> json) =>
      _$ArticleFromJson(json);
}

// Helpers to map WP JSON structure to our flattened model
Article mapWpPostToArticle(Map<String, dynamic> json) {
  String rendered(Map? v) => (v?['rendered'] as String?)?.trim() ?? '';
  String? featuredUrl;
  // Try to read from embedded media if available
  final embedded = json['_embedded'];
  if (embedded is Map<String, dynamic>) {
    final mediaList = embedded['wp:featuredmedia'];
    if (mediaList is List && mediaList.isNotEmpty) {
      final m = mediaList.first as Map<String, dynamic>;
      featuredUrl = (m['source_url'] as String?)?.trim();
    }
  }
  return Article(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    title: rendered(json['title'] as Map<String, dynamic>?),
    content: rendered(json['content'] as Map<String, dynamic>?),
    excerpt: rendered(json['excerpt'] as Map<String, dynamic>?),
    link: json['link'] as String,
    author: (json['author'] as num).toInt(),
    featuredMedia: (json['featured_media'] as num?)?.toInt() ?? 0,
    categories: (json['categories'] as List<dynamic>? ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
    featuredImageUrl: featuredUrl,
  );
}
