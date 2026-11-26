// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClassSchedule _$ClassScheduleFromJson(Map<String, dynamic> json) =>
    _ClassSchedule(
      day: (json['day'] as num).toInt(),
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      timezone: json['timezone'] as String?,
    );

Map<String, dynamic> _$ClassScheduleToJson(_ClassSchedule instance) =>
    <String, dynamic>{
      'day': instance.day,
      'hour': instance.hour,
      'minute': instance.minute,
      'timezone': instance.timezone,
    };
