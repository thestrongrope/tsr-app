// `GET /reports/conduction` (#568): the same figures as the web page
// class_reports_conduction.php, computed once in the server's MisModel.
//
// Parsing is strict about the envelope and tolerant about the rows, as for
// the release notes: a body that is not a report throws, so the screen can
// offer a retry instead of showing an empty week.

/// One class over the summary window (the weeks before the chosen one).
class ConductionClass {
  const ConductionClass({
    required this.level,
    required this.className,
    required this.teacher,
    required this.expected,
    required this.conducted,
    required this.notFilled,
    required this.notConducted,
    required this.students,
    required this.percentConduction,
    required this.percentAttendance,
    required this.percentNotFilled,
  });

  final String level;
  final String className;
  final String teacher;
  final int expected;
  final int conducted;
  final int notFilled;
  final int notConducted;
  final int students;
  final int percentConduction;
  final int percentAttendance;
  final int percentNotFilled;

  /// A class that was expected to meet and never did: nothing conducted at all.
  bool get neverHeld => expected > 0 && conducted == 0;

  factory ConductionClass.fromJson(Map<String, dynamic> json) =>
      ConductionClass(
        level: json['level'] as String? ?? '',
        className: json['class'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        expected: (json['expected'] as num?)?.toInt() ?? 0,
        conducted: (json['conducted'] as num?)?.toInt() ?? 0,
        notFilled: (json['notFilled'] as num?)?.toInt() ?? 0,
        notConducted: (json['notConducted'] as num?)?.toInt() ?? 0,
        students: (json['students'] as num?)?.toInt() ?? 0,
        percentConduction: (json['percentConduction'] as num?)?.toInt() ?? 0,
        percentAttendance: (json['percentAttendance'] as num?)?.toInt() ?? 0,
        percentNotFilled: (json['percentNotFilled'] as num?)?.toInt() ?? 0,
      );
}

/// How a class's session in the chosen week went.
enum WeekStatus { held, notHeld, notFilled }

/// One class's session in the chosen week.
class ConductionWeekRow {
  const ConductionWeekRow({
    required this.classId,
    required this.level,
    required this.className,
    required this.teacher,
    required this.status,
    this.conductedOn,
    this.reason,
    this.duration,
    this.attendance,
  });

  final int classId;
  final String level;
  final String className;
  final String teacher;
  final WeekStatus status;

  /// `YYYY-MM-DD`, as the server sends it.
  final String? conductedOn;
  final String? reason;
  final int? duration;
  final int? attendance;

  factory ConductionWeekRow.fromJson(Map<String, dynamic> json) =>
      ConductionWeekRow(
        classId: (json['classId'] as num?)?.toInt() ?? 0,
        level: json['level'] as String? ?? '',
        className: json['class'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        status: switch (json['status']) {
          'Yes' => WeekStatus.held,
          'No' => WeekStatus.notHeld,
          _ => WeekStatus.notFilled,
        },
        conductedOn: json['conductedOn'] as String?,
        reason: json['reason'] as String?,
        duration: (json['duration'] as num?)?.toInt(),
        attendance: (json['attendance'] as num?)?.toInt(),
      );
}

/// A week as the server numbers it: the calendar's Sunday-to-Saturday weeks,
/// per calendar year, so early January is week 0.
typedef WeekRef = ({int year, int week});

class ConductionReport {
  const ConductionReport({
    required this.gender,
    required this.year,
    required this.week,
    this.previous,
    this.next,
    required this.weekOf,
    required this.summaryStart,
    required this.summaryEnd,
    required this.levels,
    required this.classes,
    required this.lastWeek,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;
  final int year;
  final int week;

  /// The weeks either side; [next] is null on the last completed week.
  final WeekRef? previous;
  final WeekRef? next;

  /// e.g. `04-Oct to 10-Oct`; empty when no class has a row that week.
  final String weekOf;
  final String summaryStart;
  final String summaryEnd;
  final List<String> levels;
  final List<ConductionClass> classes;
  final List<ConductionWeekRow> lastWeek;

  /// Throws [FormatException] when [body] is not a conduction report.
  factory ConductionReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['classes'] is! List ||
        body['lastWeek'] is! List) {
      throw const FormatException('conduction report: unexpected response');
    }
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final row in body[key] as List)
        if (row is Map<String, dynamic>) parse(row),
    ];

    return ConductionReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      year: (body['year'] as num?)?.toInt() ?? 0,
      week: (body['week'] as num?)?.toInt() ?? 0,
      previous: _weekRef(body['previous']),
      next: _weekRef(body['next']),
      weekOf: body['weekOf'] as String? ?? '',
      summaryStart: body['summaryStart'] as String? ?? '',
      summaryEnd: body['summaryEnd'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classes: rows('classes', ConductionClass.fromJson),
      lastWeek: rows('lastWeek', ConductionWeekRow.fromJson),
    );
  }
}

WeekRef? _weekRef(dynamic json) {
  if (json is! Map) return null;
  final year = (json['year'] as num?)?.toInt();
  final week = (json['week'] as num?)?.toInt();
  return year == null || week == null ? null : (year: year, week: week);
}
