// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QuizResponseResult _$QuizResponseResultFromJson(Map<String, dynamic> json) =>
    _QuizResponseResult(
      questionId: (json['questionId'] as num).toInt(),
      selected: (json['selected'] as num).toInt(),
      isCorrect: (json['isCorrect'] as num).toInt(),
      questionText: json['questionText'] as String?,
      selectedText: json['selectedText'] as String?,
      correctText: json['correctText'] as String?,
    );

Map<String, dynamic> _$QuizResponseResultToJson(_QuizResponseResult instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'selected': instance.selected,
      'isCorrect': instance.isCorrect,
      'questionText': instance.questionText,
      'selectedText': instance.selectedText,
      'correctText': instance.correctText,
    };
