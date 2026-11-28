// `GET /reports/mcq-summary` and `GET /reports/mcq-summary/{id}` (#594): the
// same figures as the web page mcq_summary_report.php, from the server's
// MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

/// A class that published MCQs in the period.
class McqSummaryClass {
  const McqSummaryClass({
    required this.classId,
    required this.className,
    required this.level,
    required this.teacher,
    required this.mcqs,
    required this.students,
  });

  final int classId;
  final String className;
  final String level;
  final String teacher;
  final int mcqs;
  final int students;

  factory McqSummaryClass.fromJson(Map<String, dynamic> json) =>
      McqSummaryClass(
        classId: (json['classId'] as num?)?.toInt() ?? 0,
        className: json['class'] as String? ?? '',
        level: json['level'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        mcqs: (json['mcqs'] as num?)?.toInt() ?? 0,
        students: (json['students'] as num?)?.toInt() ?? 0,
      );
}

class McqSummaryReport {
  const McqSummaryReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.classes,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `YYYY-MM-DD`, the first and last day of the period.
  final String from;
  final String to;
  final List<String> levels;
  final List<McqSummaryClass> classes;

  /// Throws [FormatException] when [body] is not this report.
  factory McqSummaryReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['classes'] is! List) {
      throw const FormatException('mcq summary: unexpected response');
    }
    return McqSummaryReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classes: [
        for (final c in body['classes'] as List)
          if (c is Map<String, dynamic>) McqSummaryClass.fromJson(c),
      ],
    );
  }
}

/// A student's score in one topic; [correct] is null when they have none.
class McqTopicScore {
  const McqTopicScore({
    required this.topic,
    required this.max,
    required this.correct,
  });

  final String topic;
  final int max;
  final int? correct;
}

class McqStudent {
  const McqStudent({
    required this.name,
    required this.attempted,
    required this.pending,
    required this.correct,
    required this.percent,
    required this.topics,
  });

  final String name;
  final int attempted;
  final int pending;
  final int correct;

  /// Null for a student who attempted nothing: no score, not zero.
  final int? percent;
  final List<McqTopicScore> topics;

  factory McqStudent.fromJson(Map<String, dynamic> json) => McqStudent(
    name: json['name'] as String? ?? '',
    attempted: (json['attempted'] as num?)?.toInt() ?? 0,
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    correct: (json['correct'] as num?)?.toInt() ?? 0,
    percent: (json['percent'] as num?)?.toInt(),
    topics: [
      if (json['topics'] is List)
        for (final t in json['topics'] as List)
          if (t is Map<String, dynamic>)
            McqTopicScore(
              topic: t['topic'] as String? ?? '',
              max: (t['max'] as num?)?.toInt() ?? 0,
              correct: (t['correct'] as num?)?.toInt(),
            ),
    ],
  );
}

/// One class's students over the period.
class McqSummaryDetail {
  const McqSummaryDetail({
    required this.mcqs,
    required this.maxMarks,
    required this.students,
  });

  final int mcqs;
  final int maxMarks;
  final List<McqStudent> students;

  /// Throws [FormatException] when [body] is not a class's students.
  factory McqSummaryDetail.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['students'] is! List) {
      throw const FormatException('mcq summary: unexpected response');
    }
    return McqSummaryDetail(
      mcqs: (body['mcqs'] as num?)?.toInt() ?? 0,
      maxMarks: (body['maxMarks'] as num?)?.toInt() ?? 0,
      students: [
        for (final s in body['students'] as List)
          if (s is Map<String, dynamic>) McqStudent.fromJson(s),
      ],
    );
  }
}
