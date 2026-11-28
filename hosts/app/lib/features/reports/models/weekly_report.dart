// `GET /reports/weekly` (#569): the same figures as the web page
// class_reports_weekly_*.php, computed once in the server's MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the conduction
// report: a body that is not a report throws, so the screen offers a retry
// instead of an empty month.

import 'conduction_report.dart' show WeekStatus;

/// One week of the range: Sunday to Saturday, labelled `Wk n` within its month.
class WeeklyWeek {
  const WeeklyWeek({
    required this.month,
    required this.label,
    required this.from,
    required this.to,
  });

  /// e.g. `Sep-2026`.
  final String month;
  final String label;

  /// `YYYY-MM-DD`, as the server sends them.
  final String from;
  final String to;

  factory WeeklyWeek.fromJson(Map<String, dynamic> json) => WeeklyWeek(
    month: json['month'] as String? ?? '',
    label: json['label'] as String? ?? '',
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
  );
}

/// How a class's week went: held (how many times), not held or not filled.
class WeeklyCell {
  const WeeklyCell({required this.status, required this.sessions});

  final WeekStatus status;
  final int sessions;

  factory WeeklyCell.fromJson(Map<String, dynamic> json) => WeeklyCell(
    status: switch (json['status']) {
      'held' => WeekStatus.held,
      'notHeld' => WeekStatus.notHeld,
      _ => WeekStatus.notFilled,
    },
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
  );
}

class WeeklyClass {
  const WeeklyClass({
    required this.classId,
    required this.level,
    required this.className,
    required this.teacher,
    required this.weeks,
  });

  final int classId;
  final String level;
  final String className;
  final String teacher;

  /// One cell per entry of [WeeklyReport.weeks], in the same order.
  final List<WeeklyCell> weeks;

  /// Whether any week of the range has a filled session.
  bool get hasSessions => weeks.any((w) => w.status != WeekStatus.notFilled);

  factory WeeklyClass.fromJson(Map<String, dynamic> json) => WeeklyClass(
    classId: (json['classId'] as num?)?.toInt() ?? 0,
    level: json['level'] as String? ?? '',
    className: json['class'] as String? ?? '',
    teacher: json['teacher'] as String? ?? '',
    weeks: [
      if (json['weeks'] is List)
        for (final cell in json['weeks'] as List)
          if (cell is Map<String, dynamic>) WeeklyCell.fromJson(cell),
    ],
  );
}

class WeeklyReport {
  const WeeklyReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.weeks,
    required this.classes,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `MM-YYYY`, the months the range covers.
  final String from;
  final String to;
  final List<String> levels;
  final List<WeeklyWeek> weeks;
  final List<WeeklyClass> classes;

  /// Throws [FormatException] when [body] is not a weekly report.
  factory WeeklyReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['weeks'] is! List ||
        body['classes'] is! List) {
      throw const FormatException('weekly report: unexpected response');
    }
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final row in body[key] as List)
        if (row is Map<String, dynamic>) parse(row),
    ];

    return WeeklyReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      weeks: rows('weeks', WeeklyWeek.fromJson),
      classes: rows('classes', WeeklyClass.fromJson),
    );
  }
}
