// `GET /reports/mcq-adherence` and `GET /reports/mcq-adherence/{id}` (#595):
// the same figures as the web page mcq_adherence_report.php, from the server's
// MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

/// How many of a class's standard MCQs were conducted, are pending (copied, not
/// conducted) or were skipped.
class McqAdherenceFigures {
  const McqAdherenceFigures({
    required this.expected,
    required this.conducted,
    required this.pending,
    required this.skipped,
    required this.adherencePercent,
  });

  final int expected;
  final int conducted;
  final int pending;
  final int skipped;
  final double adherencePercent;

  factory McqAdherenceFigures.fromJson(Map<String, dynamic> json) =>
      McqAdherenceFigures(
        expected: (json['expected'] as num?)?.toInt() ?? 0,
        conducted: (json['conducted'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        adherencePercent: (json['adherencePercent'] as num?)?.toDouble() ?? 0,
      );

  /// `33.3` as `33.3%`, `50.0` as `50%`.
  String get percentLabel {
    final p = adherencePercent;
    return '${p == p.roundToDouble() ? p.toInt() : p}%';
  }
}

class McqAdherenceClass {
  const McqAdherenceClass({
    required this.classId,
    required this.className,
    required this.level,
    required this.teacher,
    required this.figures,
  });

  final int classId;
  final String className;
  final String level;
  final String teacher;
  final McqAdherenceFigures figures;

  factory McqAdherenceClass.fromJson(Map<String, dynamic> json) =>
      McqAdherenceClass(
        classId: (json['classId'] as num?)?.toInt() ?? 0,
        className: json['class'] as String? ?? '',
        level: json['level'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        figures: McqAdherenceFigures.fromJson(json),
      );
}

class McqAdherenceReport {
  const McqAdherenceReport({
    required this.gender,
    required this.levels,
    required this.classes,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;
  final List<String> levels;

  /// Worst adherence first, as the server sends them.
  final List<McqAdherenceClass> classes;

  /// Throws [FormatException] when [body] is not this report.
  factory McqAdherenceReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['classes'] is! List) {
      throw const FormatException('mcq adherence: unexpected response');
    }
    return McqAdherenceReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classes: [
        for (final c in body['classes'] as List)
          if (c is Map<String, dynamic>) McqAdherenceClass.fromJson(c),
      ],
    );
  }
}

/// One standard MCQ and where the class stands on it.
class AdherenceMcq {
  const AdherenceMcq({
    required this.topic,
    required this.subject,
    required this.lesson,
    required this.name,
    required this.status,
  });

  final String topic;
  final String subject;
  final String lesson;
  final String name;

  /// `conducted`, `pending` or `skipped`.
  final String status;

  factory AdherenceMcq.fromJson(Map<String, dynamic> json) => AdherenceMcq(
    topic: json['topic'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    lesson: json['lesson'] as String? ?? '',
    name: json['name'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

/// One class's standard MCQs.
class McqAdherenceDetail {
  const McqAdherenceDetail({required this.figures, required this.mcqs});

  final McqAdherenceFigures figures;
  final List<AdherenceMcq> mcqs;

  /// Throws [FormatException] when [body] is not a class's MCQs.
  factory McqAdherenceDetail.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['mcqs'] is! List) {
      throw const FormatException('mcq adherence: unexpected response');
    }
    return McqAdherenceDetail(
      figures: McqAdherenceFigures.fromJson(body),
      mcqs: [
        for (final m in body['mcqs'] as List)
          if (m is Map<String, dynamic>) AdherenceMcq.fromJson(m),
      ],
    );
  }
}
