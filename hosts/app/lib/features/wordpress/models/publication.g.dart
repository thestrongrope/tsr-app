// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Publication _$PublicationFromJson(Map<String, dynamic> json) => _Publication(
  title: json['title'] as String,
  summary: json['summary'] as String?,
  type: json['type'] as String?,
  size: json['size'] as String?,
  updated: json['updated'] as String?,
  language: json['language'] as String?,
  file: json['file'] as String?,
  readOnlineUrl: json['readOnlineUrl'] as String?,
);

Map<String, dynamic> _$PublicationToJson(_Publication instance) =>
    <String, dynamic>{
      'title': instance.title,
      'summary': instance.summary,
      'type': instance.type,
      'size': instance.size,
      'updated': instance.updated,
      'language': instance.language,
      'file': instance.file,
      'readOnlineUrl': instance.readOnlineUrl,
    };
