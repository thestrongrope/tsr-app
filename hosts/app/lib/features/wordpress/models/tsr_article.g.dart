// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tsr_article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TsrArticle _$TsrArticleFromJson(Map<String, dynamic> json) => _TsrArticle(
  id: (json['id'] as num?)?.toInt() ?? 0,
  slug: json['slug'] as String,
  title: decodeHtmlEntities(json['title'] as String),
  content: json['content'] as String? ?? '',
  excerpt: json['excerpt'] as String? ?? '',
  publishedDate: json['publishedDate'] as String?,
  modifiedDate: json['modifiedDate'] as String?,
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  author: json['author'] as String?,
  language: json['language'] as String?,
  readingTime: (json['readingTime'] as num?)?.toInt() ?? 1,
  featured: json['featured'] as bool? ?? false,
);

Map<String, dynamic> _$TsrArticleToJson(_TsrArticle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'content': instance.content,
      'excerpt': instance.excerpt,
      'publishedDate': instance.publishedDate,
      'modifiedDate': instance.modifiedDate,
      'categories': instance.categories,
      'tags': instance.tags,
      'author': instance.author,
      'language': instance.language,
      'readingTime': instance.readingTime,
      'featured': instance.featured,
    };

_TsrCategory _$TsrCategoryFromJson(Map<String, dynamic> json) => _TsrCategory(
  slug: json['slug'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  articleCount: (json['articleCount'] as num?)?.toInt() ?? 0,
  subcategories:
      (json['subcategories'] as List<dynamic>?)
          ?.map((e) => TsrCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$TsrCategoryToJson(_TsrCategory instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'title': instance.title,
      'description': instance.description,
      'articleCount': instance.articleCount,
      'subcategories': instance.subcategories,
    };

_TsrTag _$TsrTagFromJson(Map<String, dynamic> json) => _TsrTag(
  name: json['name'] as String,
  slug: json['slug'] as String,
  articleCount: (json['articleCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TsrTagToJson(_TsrTag instance) => <String, dynamic>{
  'name': instance.name,
  'slug': instance.slug,
  'articleCount': instance.articleCount,
};

_TsrYouTubeVideo _$TsrYouTubeVideoFromJson(Map<String, dynamic> json) =>
    _TsrYouTubeVideo(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      title: decodeHtmlEntities(json['title'] as String),
      youtubeLink: json['youtubeLink'] as String,
      publishedDate: json['publishedDate'] as String?,
      publishedDateFormatted: json['publishedDateFormatted'] as String?,
      views: (json['views'] as num?)?.toInt(),
      intro: json['intro'] as String?,
      description: json['description'] as String?,
      thumbnail: json['thumbnail'] == null
          ? null
          : TsrThumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TsrYouTubeVideoToJson(_TsrYouTubeVideo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'videoId': instance.videoId,
      'title': instance.title,
      'youtubeLink': instance.youtubeLink,
      'publishedDate': instance.publishedDate,
      'publishedDateFormatted': instance.publishedDateFormatted,
      'views': instance.views,
      'intro': instance.intro,
      'description': instance.description,
      'thumbnail': instance.thumbnail,
    };

_TsrThumbnail _$TsrThumbnailFromJson(Map<String, dynamic> json) =>
    _TsrThumbnail(
      url: json['url'] as String,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TsrThumbnailToJson(_TsrThumbnail instance) =>
    <String, dynamic>{
      'url': instance.url,
      'width': instance.width,
      'height': instance.height,
    };

_TsrYouTubeMeta _$TsrYouTubeMetaFromJson(Map<String, dynamic> json) =>
    _TsrYouTubeMeta(
      total: (json['total'] as num?)?.toInt(),
      channelId: json['channelId'] as String?,
      channelName: json['channelName'] as String?,
      channelUrl: json['channelUrl'] as String?,
      lastUpdated: json['lastUpdated'] as String?,
      cacheHit: json['cacheHit'] as bool? ?? false,
    );

Map<String, dynamic> _$TsrYouTubeMetaToJson(_TsrYouTubeMeta instance) =>
    <String, dynamic>{
      'total': instance.total,
      'channelId': instance.channelId,
      'channelName': instance.channelName,
      'channelUrl': instance.channelUrl,
      'lastUpdated': instance.lastUpdated,
      'cacheHit': instance.cacheHit,
    };

_TsrPagination _$TsrPaginationFromJson(Map<String, dynamic> json) =>
    _TsrPagination(
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );

Map<String, dynamic> _$TsrPaginationToJson(_TsrPagination instance) =>
    <String, dynamic>{
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
      'hasMore': instance.hasMore,
    };

_TsrApiError _$TsrApiErrorFromJson(Map<String, dynamic> json) => _TsrApiError(
  code: json['code'] as String?,
  message: json['message'] as String?,
);

Map<String, dynamic> _$TsrApiErrorToJson(_TsrApiError instance) =>
    <String, dynamic>{'code': instance.code, 'message': instance.message};

_TsrSearchResult _$TsrSearchResultFromJson(Map<String, dynamic> json) =>
    _TsrSearchResult(
      results: (json['results'] as List<dynamic>)
          .map((e) => TsrArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
      query: json['query'] as String,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TsrSearchResultToJson(_TsrSearchResult instance) =>
    <String, dynamic>{
      'results': instance.results,
      'query': instance.query,
      'total': instance.total,
    };
