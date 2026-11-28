// `GET /classes/{id}/students/performance` (#692): each current student's
// attendance, MCQ results and recitation over a range, the figures the web page
// view_class_students.php shows. Strict about the envelope, tolerant about the
// rows, as for the reports.

/// One topic's column of the MCQ view: its name and the marks on offer.
class FigureTopic {
  const FigureTopic({required this.name, required this.max});

  final String name;
  final int max;
}

/// One student over the range.
class StudentFigures {
  const StudentFigures({
    required this.token,
    required this.name,
    required this.expected,
    required this.present,
    required this.attendance,
    required this.mcqAttempted,
    required this.mcqCorrect,
    required this.topicCorrect,
    required this.recitation,
  });

  final int token;
  final String name;
  final int expected;
  final int present;

  /// Whole percent, as the web page shows it.
  final int attendance;
  final int mcqAttempted;
  final int mcqCorrect;

  /// Correct answers by topic name.
  final Map<String, int> topicCorrect;
  final int recitation;

  factory StudentFigures.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    final topics = json['topics'];
    return StudentFigures(
      token: n('token'),
      name: json['name'] as String? ?? '',
      expected: n('expected'),
      present: n('present'),
      attendance: n('attendance'),
      mcqAttempted: n('mcqAttempted'),
      mcqCorrect: n('mcqCorrect'),
      topicCorrect: {
        if (topics is Map<String, dynamic>)
          for (final e in topics.entries)
            e.key: (e.value as num?)?.toInt() ?? 0,
      },
      recitation: n('recitation'),
    );
  }
}

class ClassStudentFigures {
  const ClassStudentFigures({
    required this.from,
    required this.to,
    required this.totalMcqs,
    required this.maxTotal,
    required this.topics,
    required this.students,
  });

  /// `YYYY-MM-DD`, the first and last day the server used.
  final String from;
  final String to;

  /// MCQs published in the range, and the marks they carry in all.
  final int totalMcqs;
  final int maxTotal;
  final List<FigureTopic> topics;
  final List<StudentFigures> students;

  /// Nothing to show: no students, or none of them has any activity in the
  /// range and no MCQ was published.
  bool get isEmpty =>
      students.isEmpty ||
      (totalMcqs == 0 &&
          students.every((s) => s.expected == 0 && s.recitation == 0));

  /// Throws [FormatException] when [body] is not a figures response.
  factory ClassStudentFigures.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['students'] is! List) {
      throw const FormatException('class student figures: unexpected response');
    }
    final max = body['maxMarks'];
    return ClassStudentFigures(
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      totalMcqs: (body['totalMcqs'] as num?)?.toInt() ?? 0,
      maxTotal: max is Map<String, dynamic>
          ? (max['total'] as num?)?.toInt() ?? 0
          : 0,
      topics: [
        if (max is Map<String, dynamic> && max['topics'] is List)
          for (final t in max['topics'] as List)
            if (t is Map<String, dynamic>)
              FigureTopic(
                name: t['name'] as String? ?? '',
                max: (t['max'] as num?)?.toInt() ?? 0,
              ),
      ],
      students: [
        for (final s in body['students'] as List)
          if (s is Map<String, dynamic>) StudentFigures.fromJson(s),
      ],
    );
  }
}

/// [obtained] of [max] as a whole percent; 0 when there is nothing on offer, as
/// the web page does.
int figurePercent(int obtained, int max) =>
    max > 0 ? (obtained / max * 100).round() : 0;
