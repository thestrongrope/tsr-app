// `GET /reports/summary` (#570): the same figures as the web page
// class_reports_summary_*.php, computed once in the server's MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not a summary throws, so the screen offers a retry.

/// How often one subject was conducted: the sessions, and their share of the
/// sessions held.
class SubjectFigure {
  const SubjectFigure({required this.count, required this.percent});

  final int count;
  final int percent;

  factory SubjectFigure.fromJson(dynamic json) => json is Map
      ? SubjectFigure(
          count: (json['count'] as num?)?.toInt() ?? 0,
          percent: (json['percent'] as num?)?.toInt() ?? 0,
        )
      : const SubjectFigure(count: 0, percent: 0);
}

/// The subjects a class can be taught across.
class SummarySubjects {
  const SummarySubjects({
    required this.arabic,
    required this.aqaed,
    required this.ahkam,
    required this.akhlaq,
    required this.other,
  });

  final SubjectFigure arabic;
  final SubjectFigure aqaed;
  final SubjectFigure ahkam;
  final SubjectFigure akhlaq;
  final SubjectFigure other;

  factory SummarySubjects.fromJson(Map<String, dynamic> json) =>
      SummarySubjects(
        arabic: SubjectFigure.fromJson(json['arabic']),
        aqaed: SubjectFigure.fromJson(json['aqaed']),
        ahkam: SubjectFigure.fromJson(json['ahkam']),
        akhlaq: SubjectFigure.fromJson(json['akhlaq']),
        other: SubjectFigure.fromJson(json['other']),
      );
}

class SummaryClass {
  const SummaryClass({
    required this.classId,
    required this.level,
    required this.className,
    required this.teacher,
    required this.expected,
    required this.conducted,
    required this.notFilled,
    required this.notConducted,
    required this.avgStudents,
    required this.avgDuration,
    required this.percentNotFilled,
    required this.percentConduction,
    required this.percentAttendance,
    this.subjects,
  });

  final int classId;
  final String level;
  final String className;
  final String teacher;
  final int expected;
  final int conducted;
  final int notFilled;
  final int notConducted;
  final int avgStudents;

  /// Minutes.
  final int avgDuration;
  final int percentNotFilled;
  final int percentConduction;
  final int percentAttendance;

  /// Null for a class that recorded no subject in the period.
  final SummarySubjects? subjects;

  factory SummaryClass.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    final subjects = json['subjects'];
    return SummaryClass(
      classId: n('classId'),
      level: json['level'] as String? ?? '',
      className: json['class'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      expected: n('expected'),
      conducted: n('conducted'),
      notFilled: n('notFilled'),
      notConducted: n('notConducted'),
      avgStudents: n('avgStudents'),
      avgDuration: n('avgDuration'),
      percentNotFilled: n('percentNotFilled'),
      percentConduction: n('percentConduction'),
      percentAttendance: n('percentAttendance'),
      subjects: subjects is Map<String, dynamic>
          ? SummarySubjects.fromJson(subjects)
          : null,
    );
  }
}

class SummaryReport {
  const SummaryReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.classes,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `MM-YYYY`, the first and last month of the period.
  final String from;
  final String to;
  final List<String> levels;
  final List<SummaryClass> classes;

  /// Whether any class was expected to meet in the period.
  bool get hasSessions => classes.any((c) => c.expected > 0);

  /// Throws [FormatException] when [body] is not a summary.
  factory SummaryReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['classes'] is! List) {
      throw const FormatException('summary report: unexpected response');
    }
    return SummaryReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classes: [
        for (final row in body['classes'] as List)
          if (row is Map<String, dynamic>) SummaryClass.fromJson(row),
      ],
    );
  }
}
