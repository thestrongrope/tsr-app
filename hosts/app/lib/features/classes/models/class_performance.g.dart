// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_performance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClassPerformance _$ClassPerformanceFromJson(Map<String, dynamic> json) =>
    _ClassPerformance(
      totalSessions: (json['totalSessions'] as num).toInt(),
      attendedSessions: (json['attendedSessions'] as num).toInt(),
      attendancePercent: (json['attendancePercent'] as num).toDouble(),
      totalRecitation: (json['totalRecitation'] as num).toInt(),
      averageRecitation: (json['averageRecitation'] as num).toDouble(),
      quizzesAttempted: (json['quizzesAttempted'] as num).toInt(),
      quizAverageScore: (json['quizAverageScore'] as num).toDouble(),
    );

Map<String, dynamic> _$ClassPerformanceToJson(_ClassPerformance instance) =>
    <String, dynamic>{
      'totalSessions': instance.totalSessions,
      'attendedSessions': instance.attendedSessions,
      'attendancePercent': instance.attendancePercent,
      'totalRecitation': instance.totalRecitation,
      'averageRecitation': instance.averageRecitation,
      'quizzesAttempted': instance.quizzesAttempted,
      'quizAverageScore': instance.quizAverageScore,
    };
