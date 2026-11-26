// `GET /reports/pending` (#584): each teacher with class forms not filled and
// MCQs copied but not conducted, class by class, for the CC team's chase.
//
// Strict about the envelope, tolerant about the rows, as for the other reports:
// a body that is not a report throws, so the screen offers a retry.

/// One class of a teacher with something pending.
class PendingClass {
  const PendingClass({
    required this.classId,
    required this.level,
    required this.className,
    required this.notFilled,
    required this.mcqPending,
    required this.mcqConducted,
    required this.mcqExpected,
  });

  final int classId;
  final String level;
  final String className;

  /// Sessions in the months with no class form.
  final int notFilled;

  /// MCQs the teacher copied and has not conducted.
  final int mcqPending;
  final int mcqConducted;
  final int mcqExpected;

  factory PendingClass.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PendingClass(
      classId: n('classId'),
      level: json['level'] as String? ?? '',
      className: json['class'] as String? ?? '',
      notFilled: n('notFilled'),
      mcqPending: n('mcqPending'),
      mcqConducted: n('mcqConducted'),
      mcqExpected: n('mcqExpected'),
    );
  }
}

class PendingTeacher {
  const PendingTeacher({
    required this.token,
    required this.name,
    required this.classes,
  });

  final int token;
  final String name;
  final List<PendingClass> classes;

  int get notFilled => classes.fold(0, (sum, c) => sum + c.notFilled);
  int get mcqPending => classes.fold(0, (sum, c) => sum + c.mcqPending);

  /// This teacher with only the classes of [level] (all when null); their
  /// totals follow, since they are the sum of the classes.
  PendingTeacher inLevel(String? level) => PendingTeacher(
    token: token,
    name: name,
    classes: [
      for (final c in classes)
        if (level == null || c.level == level) c,
    ],
  );

  factory PendingTeacher.fromJson(Map<String, dynamic> json) => PendingTeacher(
    token: (json['teacherToken'] as num?)?.toInt() ?? 0,
    name: json['teacher'] as String? ?? '',
    classes: [
      if (json['classes'] is List)
        for (final c in json['classes'] as List)
          if (c is Map<String, dynamic>) PendingClass.fromJson(c),
    ],
  );
}

class PendingReport {
  const PendingReport({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.teachers,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `MM-YYYY`, the first and last month the forms are counted over.
  final String from;
  final String to;
  final List<String> levels;
  final List<PendingTeacher> teachers;

  /// Throws [FormatException] when [body] is not a pending report.
  factory PendingReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['teachers'] is! List) {
      throw const FormatException('pending report: unexpected response');
    }
    return PendingReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      teachers: [
        for (final t in body['teachers'] as List)
          if (t is Map<String, dynamic>) PendingTeacher.fromJson(t),
      ],
    );
  }
}

/// What `POST /reports/pending/nudge` answers: the message that would go (or
/// went) to a teacher, and whether they were reminded in the last 24 hours.
class PendingNudge {
  const PendingNudge({
    required this.teacher,
    required this.title,
    required this.body,
    required this.alreadyReminded,
    required this.sent,
    this.lastReminded,
  });

  final String teacher;
  final String title;

  /// The exact text of the notification, from the server's fixed template.
  final String body;
  final bool alreadyReminded;

  /// When they were last reminded, as the server sends it; null if not within
  /// the last 24 hours.
  final String? lastReminded;

  /// True once the reminder has actually gone out.
  final bool sent;

  /// Throws [FormatException] when [body] is not a nudge answer.
  factory PendingNudge.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['body'] is! String) {
      throw const FormatException('nudge: unexpected response');
    }
    return PendingNudge(
      teacher: body['teacher'] as String? ?? '',
      title: body['title'] as String? ?? '',
      body: body['body'] as String,
      alreadyReminded: body['alreadyReminded'] == true,
      lastReminded: body['lastReminded'] as String?,
      sent: body['sent'] == true,
    );
  }
}
