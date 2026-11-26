// `GET /reports/subject-conduction` (#590): the same rows as the web page
// class_subject_conduction_report.php, from the server's MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

/// One class in one week it was held: when, and the topic each subject covered
/// (an empty string for a subject not taught that week).
class SubjectWeek {
  const SubjectWeek({
    required this.week,
    required this.heldOn,
    required this.arabic,
    required this.aqaed,
    required this.ahkam,
    required this.akhlaq,
    required this.other,
  });

  /// `YYYY-Www`, as the web page labels it.
  final String week;

  /// The last day of the week the class was held, already formatted.
  final String heldOn;
  final String arabic;
  final String aqaed;
  final String ahkam;
  final String akhlaq;
  final String other;
}

/// A class with the weeks it was held, in date order.
class SubjectClass {
  const SubjectClass({
    required this.className,
    required this.level,
    required this.teacher,
    required this.weeks,
  });

  final String className;
  final String level;
  final String teacher;
  final List<SubjectWeek> weeks;
}

/// A class the user may narrow the report to (#678): every class in reach,
/// including one with no sessions in the period.
class ClassChoice {
  const ClassChoice({
    required this.classId,
    required this.className,
    required this.level,
    required this.teacher,
  });

  final int classId;
  final String className;
  final String level;
  final String teacher;
}

class SubjectConductionReport {
  const SubjectConductionReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.classes,
    this.classChoices = const [],
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `MM-YYYY`, the first and last month of the period.
  final String from;
  final String to;
  final List<String> levels;
  final List<SubjectClass> classes;

  /// The classes to choose from, by level; empty from an older server.
  final List<ClassChoice> classChoices;

  /// Whether any class was held in the period.
  bool get hasSessions => classes.isNotEmpty;

  /// Throws [FormatException] when [body] is not this report.
  factory SubjectConductionReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['rows'] is! List) {
      throw const FormatException(
        'subject conduction report: unexpected response',
      );
    }

    // The server sends one row per class and week, sorted by level then class;
    // group them here, keeping that order.
    final byClass = <String, List<Map<String, dynamic>>>{};
    for (final row in body['rows'] as List) {
      if (row is! Map<String, dynamic>) continue;
      final key = '${row['level']}|${row['class']}';
      byClass.putIfAbsent(key, () => []).add(row);
    }

    String s(Map<String, dynamic> row, String key) => row[key] as String? ?? '';
    return SubjectConductionReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classChoices: [
        if (body['classes'] is List)
          for (final c in body['classes'] as List)
            if (c is Map<String, dynamic> && c['classId'] is num)
              ClassChoice(
                classId: (c['classId'] as num).toInt(),
                className: s(c, 'class'),
                level: s(c, 'level'),
                teacher: s(c, 'teacher'),
              ),
      ],
      classes: [
        for (final rows in byClass.values)
          SubjectClass(
            className: s(rows.first, 'class'),
            level: s(rows.first, 'level'),
            teacher: s(rows.first, 'teacher'),
            weeks: [
              for (final row in rows)
                SubjectWeek(
                  week: s(row, 'week'),
                  heldOn: s(row, 'heldOn'),
                  arabic: s(row, 'arabic'),
                  aqaed: s(row, 'aqaed'),
                  ahkam: s(row, 'ahkam'),
                  akhlaq: s(row, 'akhlaq'),
                  other: s(row, 'other'),
                ),
            ],
          ),
      ],
    );
  }
}
