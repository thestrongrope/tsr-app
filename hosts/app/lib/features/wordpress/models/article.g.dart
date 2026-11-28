// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Article _$ArticleFromJson(Map<String, dynamic> json) => _Article(
  id: (json['id'] as num).toInt(),
  date: DateTime.parse(json['date'] as String),
  title: json['title'] as String,
  content: json['content'] as String,
  excerpt: json['excerpt'] as String,
  link: json['link'] as String,
  author: (json['author'] as num).toInt(),
  featuredMedia: (json['featuredMedia'] as num).toInt(),
  categories: (json['categories'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  tags: (json['tags'] as List<dynamic>).map((e) => (e as num).toInt()).toList(),
  featuredImageUrl: json['featuredImageUrl'] as String?,
);

Map<String, dynamic> _$ArticleToJson(_Article instance) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date.toIso8601String(),
  'title': instance.title,
  'content': instance.content,
  'excerpt': instance.excerpt,
  'link': instance.link,
  'author': instance.author,
  'featuredMedia': instance.featuredMedia,
  'categories': instance.categories,
  'tags': instance.tags,
  'featuredImageUrl': instance.featuredImageUrl,
};
