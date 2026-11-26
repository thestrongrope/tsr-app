// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClassJoinResponse _$ClassJoinResponseFromJson(Map<String, dynamic> json) =>
    _ClassJoinResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      classId: (json['classId'] as num?)?.toInt(),
      className: json['className'] as String?,
    );

Map<String, dynamic> _$ClassJoinResponseToJson(_ClassJoinResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'classId': instance.classId,
      'className': instance.className,
    };
