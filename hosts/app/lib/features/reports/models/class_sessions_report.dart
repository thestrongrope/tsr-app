// `GET /reports/class-sessions` and `GET /reports/class-sessions/{id}` (#592):
// the same figures as the web page class_sessions_report.php, from the
// server's MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

/// One class with how many sessions it has recorded and what the last covered.
class ClassSessionsClass {
  const ClassSessionsClass({
    required this.classId,
    required this.className,
    required this.level,
    required this.teacher,
    required this.totalSessions,
    required this.lastDate,
    required this.lastQuran,
    required this.lastTopics,
  });

  final int classId;
  final String className;
  final String level;
  final String teacher;
  final int totalSessions;

  /// `YYYY-MM-DD`, null for a class with no session.
  final String? lastDate;
  final String lastQuran;

  /// Subject to topic for the last session, only the subjects it covered.
  final Map<String, String> lastTopics;

  factory ClassSessionsClass.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] as String?) ?? '';
    final topics = {
      'Arabic': s('lastArabic'),
      'Aqaed': s('lastAqaed'),
      'Ahkam': s('lastAhkam'),
      'Akhlaq': s('lastAkhlaq'),
      'Other': s('lastOther'),
    }..removeWhere((_, topic) => topic.isEmpty);
    return ClassSessionsClass(
      classId: (json['classId'] as num?)?.toInt() ?? 0,
      className: s('class'),
      level: s('level'),
      teacher: s('teacher'),
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      lastDate: json['lastDate'] as String?,
      lastQuran: s('lastQuran'),
      lastTopics: topics,
    );
  }
}

class ClassSessionsReport {
  const ClassSessionsReport({
    required this.gender,
    required this.levels,
    required this.classes,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;
  final List<String> levels;
  final List<ClassSessionsClass> classes;

  /// Throws [FormatException] when [body] is not this report.
  factory ClassSessionsReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['classes'] is! List) {
      throw const FormatException('class sessions: unexpected response');
    }
    return ClassSessionsReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      classes: [
        for (final c in body['classes'] as List)
          if (c is Map<String, dynamic>) ClassSessionsClass.fromJson(c),
      ],
    );
  }
}

/// One recorded session of a class.
class ClassSession {
  const ClassSession({
    required this.date,
    required this.held,
    required this.reason,
    required this.quran,
    required this.topics,
  });

  /// `YYYY-MM-DD`.
  final String date;
  final bool held;

  /// Why a session was not held; null when it was, or none was given.
  final String? reason;
  final String quran;

  /// Subject to topic, only the subjects the session covered.
  final Map<String, String> topics;

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] as String?) ?? '';
    final topics = {
      'Arabic': s('arabic'),
      'Aqaed': s('aqaed'),
      'Ahkam': s('ahkam'),
      'Akhlaq': s('akhlaq'),
      'Other': s('other'),
    }..removeWhere((_, topic) => topic.isEmpty);
    return ClassSession(
      date: s('date'),
      held: json['held'] as bool? ?? false,
      reason: json['reason'] as String?,
      quran: s('quran'),
      topics: topics,
    );
  }

  /// Throws [FormatException] when [body] is not a class's history, newest
  /// session first as the server sends it.
  static List<ClassSession> listFromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['sessions'] is! List) {
      throw const FormatException('class sessions: unexpected response');
    }
    return [
      for (final s in body['sessions'] as List)
        if (s is Map<String, dynamic>) ClassSession.fromJson(s),
    ];
  }
}
