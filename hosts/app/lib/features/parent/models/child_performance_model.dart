// Child academic performance figures for a class (#633).

class ChildAttendanceSummary {
  final int totalSessions;
  final int attendedSessions;
  final double attendancePercentage;
  final int totalRecitation;

  const ChildAttendanceSummary({
    required this.totalSessions,
    required this.attendedSessions,
    required this.attendancePercentage,
    required this.totalRecitation,
  });

  String get percentageFormatted =>
      '${attendancePercentage.toStringAsFixed(1)}%';

  String get ratioFormatted => '$attendedSessions / $totalSessions';

  factory ChildAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return ChildAttendanceSummary(
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      attendedSessions: (json['attended_sessions'] as num?)?.toInt() ?? 0,
      attendancePercentage:
          (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      totalRecitation: (json['total_recitation'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_sessions': totalSessions,
    'attended_sessions': attendedSessions,
    'attendance_percentage': attendancePercentage,
    'total_recitation': totalRecitation,
  };
}

class ChildQuizSummary {
  final int quizzesAttempted;
  final double quizAverageScore;

  const ChildQuizSummary({
    required this.quizzesAttempted,
    required this.quizAverageScore,
  });

  String get averageFormatted => '${quizAverageScore.toStringAsFixed(1)}%';

  factory ChildQuizSummary.fromJson(Map<String, dynamic> json) {
    return ChildQuizSummary(
      quizzesAttempted: (json['quizzes_attempted'] as num?)?.toInt() ?? 0,
      quizAverageScore:
          (json['quiz_average_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'quizzes_attempted': quizzesAttempted,
    'quiz_average_score': quizAverageScore,
  };
}

class ChildPerformanceModel {
  final ChildAttendanceSummary attendance;
  final ChildQuizSummary quizzes;

  const ChildPerformanceModel({
    required this.attendance,
    required this.quizzes,
  });

  factory ChildPerformanceModel.fromJson(Map<String, dynamic> json) {
    final att = json['attendance'];
    final quiz = json['quizzes'];
    return ChildPerformanceModel(
      attendance: att is Map<String, dynamic>
          ? ChildAttendanceSummary.fromJson(att)
          : const ChildAttendanceSummary(
              totalSessions: 0,
              attendedSessions: 0,
              attendancePercentage: 0.0,
              totalRecitation: 0,
            ),
      quizzes: quiz is Map<String, dynamic>
          ? ChildQuizSummary.fromJson(quiz)
          : const ChildQuizSummary(
              quizzesAttempted: 0,
              quizAverageScore: 0.0,
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'attendance': attendance.toJson(),
    'quizzes': quizzes.toJson(),
  };
}

class ChildAttendanceHistory {
  final String date;
  final int duration;
  final bool present;
  final int recitation;

  const ChildAttendanceHistory({
    required this.date,
    required this.duration,
    required this.present,
    required this.recitation,
  });

  factory ChildAttendanceHistory.fromJson(Map<String, dynamic> json) {
    final rawPresent = json['present'];
    final isPresent = rawPresent == true || rawPresent == 1 || rawPresent == '1';
    return ChildAttendanceHistory(
      date: json['date'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      present: isPresent,
      recitation: (json['recitation'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'duration': duration,
    'present': present,
    'recitation': recitation,
  };
}
