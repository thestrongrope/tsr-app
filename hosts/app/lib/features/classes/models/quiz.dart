import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/utils/api_datetime.dart';

part 'quiz.freezed.dart';
part 'quiz.g.dart';

@freezed
sealed class Quiz with _$Quiz {
  const Quiz._();

  const factory Quiz({
    required int id,
    required String code,
    required String name,
    String? topic,
    required int classId,
    DateTime? publishedAt,
    @Default(0) int questionCount,
    @Default(false) bool attempted,
    int? score,
    int? total,
    double? percent,
  }) = _Quiz;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Untitled Quiz',
      topic: json['topic'] as String?,
      classId: json['classId'] as int,
      publishedAt: json['publishedAt'] != null
          ? parseApiLocalDateTime(json['publishedAt'].toString())
          : null,
      questionCount: json['questionCount'] as int? ?? 0,
      attempted: json['attempted'] == true,
      score: json['score'] as int?,
      total: json['total'] as int?,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }

  /// Get quiz status for display
  QuizStatus get status {
    if (attempted) return QuizStatus.completed;
    return QuizStatus.available;
  }

  /// Formatted score string
  String get scoreFormatted {
    if (!attempted || score == null || total == null) return 'Not attempted';
    return '$score / $total (${percent?.toStringAsFixed(0)}%)';
  }

  /// Get topic display name
  String get topicDisplay => topic ?? 'General';
}

enum QuizStatus { available, completed, locked }

extension QuizStatusExtension on QuizStatus {
  String get displayName {
    switch (this) {
      case QuizStatus.available:
        return 'Available';
      case QuizStatus.completed:
        return 'Completed';
      case QuizStatus.locked:
        return 'Locked';
    }
  }
}

@freezed
sealed class QuizQuestion with _$QuizQuestion {
  const factory QuizQuestion({
    required int id,
    required String text,
    required List<String> options,
    @Default(false) bool isArabic,
  }) = _QuizQuestion;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    // Safely parse options, filtering out any null values and empty strings
    final rawOptions = json['options'] as List? ?? [];
    final options = rawOptions
        .where((o) => o != null && o.toString().trim().isNotEmpty)
        .map((o) => o.toString())
        .toList();

    return QuizQuestion(
      id: json['id'] as int,
      text: (json['text'] as String?) ?? '',
      options: options.isNotEmpty ? options : ['No options available'],
      isArabic: json['isArabic'] == true || json['isArabic'] == 1,
    );
  }
}

@freezed
sealed class QuizListResponse with _$QuizListResponse {
  const factory QuizListResponse({
    required int total,
    required int page,
    required int pageSize,
    required bool hasNext,
    required List<Quiz> items,
  }) = _QuizListResponse;

  factory QuizListResponse.fromJson(Map<String, dynamic> json) {
    return QuizListResponse(
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      hasNext: json['hasNext'] as bool,
      items: (json['items'] as List)
          .map((e) => Quiz.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@freezed
sealed class QuizQuestionsResponse with _$QuizQuestionsResponse {
  const factory QuizQuestionsResponse({
    required int total,
    required int page,
    required int pageSize,
    required List<QuizQuestion> items,
  }) = _QuizQuestionsResponse;

  factory QuizQuestionsResponse.fromJson(Map<String, dynamic> json) {
    return QuizQuestionsResponse(
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      items: (json['items'] as List)
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@freezed
sealed class QuizSubmitResponse with _$QuizSubmitResponse {
  const QuizSubmitResponse._();

  const factory QuizSubmitResponse({
    required int total,
    required int answered,
    required int correct,
    required double percent,
    required List<QuizResponseResult> responses,
  }) = _QuizSubmitResponse;

  factory QuizSubmitResponse.fromJson(Map<String, dynamic> json) {
    return QuizSubmitResponse(
      total: json['total'] as int,
      answered: json['answered'] as int,
      correct: json['correct'] as int,
      percent: (json['percent'] as num).toDouble(),
      responses: (json['responses'] as List)
          .map((e) => QuizResponseResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Formatted result string
  String get resultFormatted =>
      '$correct / $total correct (${percent.toStringAsFixed(0)}%)';
}

@freezed
sealed class QuizResponseResult with _$QuizResponseResult {
  const factory QuizResponseResult({
    required int questionId,
    required int selected,
    required int isCorrect,
    String? questionText,
    String? selectedText,
    String? correctText,
  }) = _QuizResponseResult;

  factory QuizResponseResult.fromJson(Map<String, dynamic> json) =>
      _$QuizResponseResultFromJson(json);
}

@freezed
sealed class QuizScoreHistory with _$QuizScoreHistory {
  const QuizScoreHistory._();

  const factory QuizScoreHistory({
    required int quizId,
    required String quizName,
    String? topic,
    required int score,
    required int total,
    required double percent,
  }) = _QuizScoreHistory;

  factory QuizScoreHistory.fromJson(Map<String, dynamic> json) {
    return QuizScoreHistory(
      quizId: json['quizId'] as int,
      quizName: json['quizName'] as String,
      topic: json['topic'] as String?,
      score: json['score'] as int,
      total: json['total'] as int,
      percent: (json['percent'] as num).toDouble(),
    );
  }

  /// Formatted score string
  String get scoreFormatted =>
      '$score / $total (${percent.toStringAsFixed(0)}%)';
}
