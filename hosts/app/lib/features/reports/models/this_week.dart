// `GET /reports/this-week` and `GET /reports/this-week/class/{id}` (#615): the
// class coordinator's weekly review, in four stages (C-form, conduction,
// attendance, alignment), and a class's last eight weeks of teaching.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this answer throws, so the screen offers a retry.

/// A teacher's number as WhatsApp and the dialer want it: digits only, with the
/// country code. The server sends it in full with a `+` (#1158), which is kept
/// as it is. A number without one, from an older server, follows the notifier's
/// `formatMobile`: drop one leading 0 and treat a bare ten-digit number as
/// Indian (91). Empty when there is nothing usable.
String dialableNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (raw.trim().startsWith('+')) return digits;
  if (digits.startsWith('0')) digits = digits.substring(1);
  return digits.length == 10 ? '91$digits' : digits;
}

/// A subject a class that did meet has not taught for [weeks] weeks in a row.
class QuietSubject {
  const QuietSubject({required this.subject, required this.weeks});

  /// `arabic`, `aqaed`, `ahkam` or `akhlaq`.
  final String subject;
  final int weeks;

  factory QuietSubject.fromJson(Map<String, dynamic> json) => QuietSubject(
    subject: json['subject'] as String? ?? '',
    weeks: (json['weeks'] as num?)?.toInt() ?? 0,
  );
}

/// One class in one stage, with who to contact.
class ThisWeekRow {
  const ThisWeekRow({
    required this.classId,
    required this.code,
    required this.level,
    required this.teacher,
    required this.teacherMobile,
    required this.detail,
    required this.action,
    required this.quiet,
  });

  final int classId;
  final String code;
  final String level;

  /// Empty when the class has no teacher.
  final String teacher;

  /// Null when the caller may not use this teacher's number: the row then has
  /// no call or message button.
  final String? teacherMobile;

  /// What is wrong, as a short line; empty when the row only lists subjects.
  final String detail;

  /// `message`, `call`, or null when the row asks nothing of the coordinator.
  final String? action;

  final List<QuietSubject> quiet;

  factory ThisWeekRow.fromJson(Map<String, dynamic> json) => ThisWeekRow(
    classId: (json['classId'] as num?)?.toInt() ?? 0,
    code: json['code'] as String? ?? '',
    level: json['level'] as String? ?? '',
    teacher: json['teacher'] as String? ?? '',
    teacherMobile: json['teacherMobile'] as String?,
    detail: json['detail'] as String? ?? '',
    action: json['action'] as String?,
    quiet: [
      for (final q in json['quiet'] as List? ?? const [])
        if (q is Map<String, dynamic>) QuietSubject.fromJson(q),
    ],
  );
}

/// The strip at the top of the screen.
class ThisWeekSummary {
  const ThisWeekSummary({
    required this.met,
    required this.total,
    required this.formsMissing,
    required this.attendance,
    required this.flagged,
  });

  /// Classes that met, out of [total] that filled their form.
  final int met;
  final int total;
  final int formsMissing;

  /// 0 to 1; null when no class has marked attendance.
  final double? attendance;

  /// Classes flagged in any stage, each counted once.
  final int flagged;

  factory ThisWeekSummary.fromJson(Map<String, dynamic> json) =>
      ThisWeekSummary(
        met: (json['met'] as num?)?.toInt() ?? 0,
        total: (json['of'] as num?)?.toInt() ?? 0,
        formsMissing: (json['formsMissing'] as num?)?.toInt() ?? 0,
        attendance: (json['attendance'] as num?)?.toDouble(),
        flagged: (json['flagged'] as num?)?.toInt() ?? 0,
      );
}

/// The whole screen.
class ThisWeek {
  const ThisWeek({
    required this.gender,
    required this.weekFrom,
    required this.weekTo,
    required this.summary,
    required this.cform,
    required this.conduction,
    required this.attendance,
    required this.alignment,
    this.met = const [],
    this.attended = const [],
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `YYYY-MM-DD`: the last completed week.
  final String weekFrom;
  final String weekTo;

  final ThisWeekSummary summary;
  final List<ThisWeekRow> cform;
  final List<ThisWeekRow> conduction;
  final List<ThisWeekRow> attendance;

  /// Every class the caller reaches; not a list of problems.
  final List<ThisWeekRow> alignment;

  /// The classes counted in "N of M met", one row each.
  final List<ThisWeekRow> met;

  /// The classes whose attendance makes up the average, one row each.
  final List<ThisWeekRow> attended;

  /// Throws [FormatException] when [body] is not this answer.
  factory ThisWeek.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['stages'] is! Map<String, dynamic> ||
        body['summary'] is! Map<String, dynamic> ||
        body['week'] is! Map<String, dynamic>) {
      throw const FormatException('this week: unexpected response');
    }
    final stages = body['stages'] as Map<String, dynamic>;
    final week = body['week'] as Map<String, dynamic>;
    List<ThisWeekRow> rows(String stage) => [
      for (final r in stages[stage] as List? ?? const [])
        if (r is Map<String, dynamic>) ThisWeekRow.fromJson(r),
    ];
    return ThisWeek(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      weekFrom: week['from'] as String? ?? '',
      weekTo: week['to'] as String? ?? '',
      summary: ThisWeekSummary.fromJson(
        body['summary'] as Map<String, dynamic>,
      ),
      cform: rows('cform'),
      conduction: rows('conduction'),
      attendance: rows('attendance'),
      alignment: rows('alignment'),
      met: rows('met'),
      attended: rows('attended'),
    );
  }
}

/// One week of a class's teaching.
class AlignmentWeek {
  const AlignmentWeek({
    required this.from,
    required this.to,
    required this.status,
    required this.subjects,
  });

  final String from;
  final String to;

  /// `taught`, `no class` (a form was filled, nothing held) or `no form`.
  final String status;

  /// Subject to the topic(s) written for it, as written.
  final Map<String, String> subjects;

  factory AlignmentWeek.fromJson(Map<String, dynamic> json) => AlignmentWeek(
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    status: json['status'] as String? ?? 'no form',
    subjects: {
      for (final e in (json['subjects'] as Map? ?? const {}).entries)
        e.key.toString(): e.value.toString(),
    },
  );
}

/// A class's last eight weeks, newest first, with the Standard Syllabus Chart
/// for its level when there is one.
class ClassAlignment {
  const ClassAlignment({
    required this.classId,
    required this.code,
    required this.level,
    required this.weeks,
    required this.chart,
  });

  final int classId;
  final String code;
  final String level;
  final List<AlignmentWeek> weeks;

  /// Subject to topic group to sub-topics; null for a level with no chart.
  final Map<String, dynamic>? chart;

  /// Throws [FormatException] when [body] is not this answer.
  factory ClassAlignment.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['weeks'] is! List) {
      throw const FormatException('class alignment: unexpected response');
    }
    return ClassAlignment(
      classId: (body['classId'] as num?)?.toInt() ?? 0,
      code: body['code'] as String? ?? '',
      level: body['level'] as String? ?? '',
      weeks: [
        for (final w in body['weeks'] as List)
          if (w is Map<String, dynamic>) AlignmentWeek.fromJson(w),
      ],
      chart: body['chart'] is Map<String, dynamic>
          ? body['chart'] as Map<String, dynamic>
          : null,
    );
  }
}
