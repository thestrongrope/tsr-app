// `GET /reports/students` (#578): the same figures as the web page
// student_performance_report.php, computed once in the server's MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not a report throws, so the screen offers a retry.

/// One student in one class over the period. Percentages are whole numbers, as
/// the web page shows them.
class StudentPerformance {
  const StudentPerformance({
    required this.token,
    required this.name,
    required this.level,
    required this.className,
    required this.sessions,
    required this.attendance,
    required this.totalMcqs,
    required this.mcqAttempted,
    required this.mcqPerformance,
    required this.recitation,
    required this.recitationAvg,
    required this.tsrScore,
  });

  final String token;
  final String name;
  final String level;
  final String className;
  final int sessions;
  final int attendance;
  final int totalMcqs;
  final int mcqAttempted;
  final int mcqPerformance;
  final int recitation;

  /// Recitation per session.
  final double recitationAvg;
  final int tsrScore;

  factory StudentPerformance.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return StudentPerformance(
      token: json['token'] as String? ?? '',
      name: json['name'] as String? ?? '',
      level: json['level'] as String? ?? '',
      className: json['class'] as String? ?? '',
      sessions: n('sessions'),
      attendance: n('attendance'),
      totalMcqs: n('totalMcqs'),
      mcqAttempted: n('mcqAttempted'),
      mcqPerformance: n('mcqPerformance'),
      recitation: n('recitation'),
      recitationAvg: (json['recitationAvg'] as num?)?.toDouble() ?? 0,
      tsrScore: n('tsrScore'),
    );
  }
}

/// A class that has a student in the period, for the class picker.
class StudentClass {
  const StudentClass({required this.className, required this.level});

  final String className;
  final String level;

  factory StudentClass.fromJson(Map<String, dynamic> json) => StudentClass(
    className: json['class'] as String? ?? '',
    level: json['level'] as String? ?? '',
  );
}

class StudentsReport {
  const StudentsReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.classes,
    required this.students,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `YYYY-MM-DD`, the first and last day of the period.
  final String from;
  final String to;
  final List<String> levels;
  final List<StudentClass> classes;
  final List<StudentPerformance> students;

  /// Throws [FormatException] when [body] is not a students report.
  factory StudentsReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['students'] is! List) {
      throw const FormatException('students report: unexpected response');
    }
    return StudentsReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classes: [
        if (body['classes'] is List)
          for (final c in body['classes'] as List)
            if (c is Map<String, dynamic>) StudentClass.fromJson(c),
      ],
      students: [
        for (final s in body['students'] as List)
          if (s is Map<String, dynamic>) StudentPerformance.fromJson(s),
      ],
    );
  }
}
