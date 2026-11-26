import 'package:freezed_annotation/freezed_annotation.dart';

part 'class_performance.freezed.dart';
part 'class_performance.g.dart';

@freezed
sealed class ClassPerformance with _$ClassPerformance {
  const ClassPerformance._();

  const factory ClassPerformance({
    required int totalSessions,
    required int attendedSessions,
    required double attendancePercent,
    required int totalRecitation,
    required double averageRecitation,
    required int quizzesAttempted,
    required double quizAverageScore,
  }) = _ClassPerformance;

  factory ClassPerformance.fromJson(Map<String, dynamic> json) =>
      _$ClassPerformanceFromJson(json);

  /// Formatted attendance percentage
  String get attendanceFormatted => '${attendancePercent.toStringAsFixed(1)}%';

  /// Formatted quiz average
  String get quizAverageFormatted => '${quizAverageScore.toStringAsFixed(1)}%';

  /// Get attendance status color indicator
  String get attendanceStatus {
    if (attendancePercent >= 80) return 'excellent';
    if (attendancePercent >= 60) return 'good';
    if (attendancePercent >= 40) return 'fair';
    return 'poor';
  }

  /// Get quiz performance status
  String get quizStatus {
    if (quizAverageScore >= 80) return 'excellent';
    if (quizAverageScore >= 60) return 'good';
    if (quizAverageScore >= 40) return 'fair';
    return 'needs_improvement';
  }
}
