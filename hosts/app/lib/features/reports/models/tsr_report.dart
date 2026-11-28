// `GET /reports/tsr` (#580): the same figures as the web page
// tsr_summary_report.php ("TSR at a glance"), computed once in the server's
// MisModel.
//
// Each section is one thing measured per level, and the classes behind it. The
// words shown for a level and a class are built here, so the screen treats the
// four sections alike.
//
// Strict about the envelope, tolerant about the rows, as for the other reports.

/// One level's line in a section: `AMMAR   4 of 6 (66.7%)`.
class TsrLevelRow {
  const TsrLevelRow({required this.level, required this.summary});

  final String level;
  final String summary;
}

/// One class behind a level's figure: `A1 · Teacher` with what it did.
class TsrClassRow {
  const TsrClassRow({
    required this.level,
    required this.className,
    required this.teacher,
    required this.detail,
  });

  final String level;
  final String className;
  final String teacher;
  final String detail;
}

class TsrSection {
  const TsrSection({
    required this.title,
    required this.levels,
    required this.classes,
  });

  final String title;
  final List<TsrLevelRow> levels;
  final List<TsrClassRow> classes;

  /// The classes of one level, for the drill-down.
  List<TsrClassRow> classesOf(String level) => [
    for (final c in classes)
      if (c.level == level) c,
  ];
}

class TsrReport {
  const TsrReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.sections,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `YYYY-MM-DD`, the first and last day of the period.
  final String from;
  final String to;

  /// Class conduction, MCQ conduction, attendance and recitation, in that order.
  final List<TsrSection> sections;

  /// Whether any level has a class at all in the period.
  bool get hasClasses => sections.any((s) => s.levels.isNotEmpty);

  /// Throws [FormatException] when [body] is not a TSR report.
  factory TsrReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['conduction'] is! Map ||
        body['mcq'] is! Map ||
        body['attendance'] is! Map ||
        body['recitation'] is! Map) {
      throw const FormatException('tsr report: unexpected response');
    }

    return TsrReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      sections: [
        _section(
          'Class conduction',
          body['conduction'],
          (l) =>
              '${_n(l, 'conducted')} of ${_n(l, 'total')} '
              '(${_percent(l['percent'])}%)',
          (c) => _lastConducted(c, 'Last held'),
        ),
        _section(
          'MCQ conduction',
          body['mcq'],
          (l) =>
              '${_n(l, 'conducted')} of ${_n(l, 'total')} '
              '(${_percent(l['percent'])}%)',
          (c) => _lastConducted(c, 'Last MCQ'),
        ),
        _section(
          'Attendance',
          body['attendance'],
          (l) => '${_n(l, 'percent')}%',
          (c) => '${_n(c, 'percent')}%',
        ),
        _section(
          'Recitation',
          body['recitation'],
          (l) => '${_n(l, 'total')}',
          (c) => '${_n(c, 'total')}',
        ),
      ],
    );
  }
}

int _n(Map<dynamic, dynamic> row, String key) =>
    (row[key] as num?)?.toInt() ?? 0;

/// `66.7`, but `100` and `0` without the `.0`, as the web page prints them.
String _percent(dynamic value) {
  final n = (value as num?)?.toDouble() ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

String _lastConducted(Map<dynamic, dynamic> c, String label) {
  final date = c['lastConducted'];
  return date is String && date.isNotEmpty
      ? '$label $date'
      : 'None in this period';
}

TsrSection _section(
  String title,
  dynamic json,
  String Function(Map<dynamic, dynamic>) levelText,
  String Function(Map<dynamic, dynamic>) classText,
) {
  final map = json as Map;
  return TsrSection(
    title: title,
    levels: [
      if (map['levels'] is List)
        for (final l in map['levels'] as List)
          if (l is Map)
            TsrLevelRow(
              level: l['level'] as String? ?? '',
              summary: levelText(l),
            ),
    ],
    classes: [
      if (map['classes'] is List)
        for (final c in map['classes'] as List)
          if (c is Map)
            TsrClassRow(
              level: c['level'] as String? ?? '',
              className: c['class'] as String? ?? '',
              teacher: c['teacher'] as String? ?? '',
              detail: classText(c),
            ),
    ],
  );
}
