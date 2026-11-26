// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'syllabus_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SyllabusItem _$SyllabusItemFromJson(Map<String, dynamic> json) =>
    _SyllabusItem(
      id: (json['id'] as num).toInt(),
      levelId: (json['level_id'] as num).toInt(),
      subjectName: json['subject_name'] as String,
      description: json['description'] as String?,
      linkType:
          $enumDecodeNullable(_$SyllabusLinkTypeEnumMap, json['link_type']) ??
          SyllabusLinkType.pdf,
      url: json['url'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$SyllabusItemToJson(_SyllabusItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'level_id': instance.levelId,
      'subject_name': instance.subjectName,
      'description': instance.description,
      'link_type': _$SyllabusLinkTypeEnumMap[instance.linkType]!,
      'url': instance.url,
      'sort_order': instance.sortOrder,
      'is_active': instance.isActive,
    };

const _$SyllabusLinkTypeEnumMap = {
  SyllabusLinkType.pdf: 'pdf',
  SyllabusLinkType.external: 'external',
};

_SyllabusLevel _$SyllabusLevelFromJson(Map<String, dynamic> json) =>
    _SyllabusLevel(
      levelId: (json['level_id'] as num).toInt(),
      levelName: json['level_name'] as String,
      levelCode: json['level_code'] as String,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => SyllabusItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SyllabusLevelToJson(_SyllabusLevel instance) =>
    <String, dynamic>{
      'level_id': instance.levelId,
      'level_name': instance.levelName,
      'level_code': instance.levelCode,
      'items': instance.items,
    };

_ClassLevel _$ClassLevelFromJson(Map<String, dynamic> json) => _ClassLevel(
  id: (json['id'] as num).toInt(),
  code: json['code'] as String,
  name: json['name'] as String,
  sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ClassLevelToJson(_ClassLevel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'name': instance.name,
      'sort_order': instance.sortOrder,
    };
