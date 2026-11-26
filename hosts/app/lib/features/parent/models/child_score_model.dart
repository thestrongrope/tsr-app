/// A quiz score entry for a child in a class (#633).
class ChildScoreModel {
  final int quizId;
  final String quizName;
  final int score;
  final int totalQuestions;
  final double percentage;
  final String attemptedOn;

  const ChildScoreModel({
    required this.quizId,
    required this.quizName,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.attemptedOn,
  });

  String get scoreFormatted => '$score / $totalQuestions';

  String get percentageFormatted => '${percentage.toStringAsFixed(1)}%';

  factory ChildScoreModel.fromJson(Map<String, dynamic> json) {
    return ChildScoreModel(
      quizId: (json['quiz_id'] as num?)?.toInt() ?? 0,
      quizName: json['quiz_name'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      attemptedOn: json['attempted_on'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'quiz_id': quizId,
    'quiz_name': quizName,
    'score': score,
    'total_questions': totalQuestions,
    'percentage': percentage,
    'attempted_on': attemptedOn,
  };
}
