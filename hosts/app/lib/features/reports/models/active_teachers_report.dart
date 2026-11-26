// `GET /reports/active-teachers` (#598): the same figures as the web page
// active_teachers_report.php, from the server's MisModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

class ActiveTeacher {
  const ActiveTeacher({
    required this.token,
    required this.name,
    required this.attendingClass,
    required this.selfTeacher,
    required this.maxLevel,
    required this.totalClasses,
    required this.conductingClasses,
  });

  final int token;
  final String name;

  /// The classes they attend as a student, comma-separated; empty for none.
  final String attendingClass;

  /// The teachers of those classes, in the same order; empty for none.
  final String selfTeacher;
  final String maxLevel;
  final int totalClasses;

  /// The classes they conduct, comma-separated.
  final String conductingClasses;

  factory ActiveTeacher.fromJson(Map<String, dynamic> json) => ActiveTeacher(
    token: (json['token'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    attendingClass: json['attendingClass'] as String? ?? '',
    selfTeacher: json['selfTeacher'] as String? ?? '',
    maxLevel: json['maxLevel'] as String? ?? '',
    totalClasses: (json['totalClasses'] as num?)?.toInt() ?? 0,
    conductingClasses: json['conductingClasses'] as String? ?? '',
  );
}

class ActiveTeachersReport {
  const ActiveTeachersReport({required this.gender, required this.teachers});

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// In name order, as the server sends them.
  final List<ActiveTeacher> teachers;

  /// Throws [FormatException] when [body] is not this report.
  factory ActiveTeachersReport.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['teachers'] is! List) {
      throw const FormatException('active teachers: unexpected response');
    }
    return ActiveTeachersReport(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      teachers: [
        for (final t in body['teachers'] as List)
          if (t is Map<String, dynamic>) ActiveTeacher.fromJson(t),
      ],
    );
  }
}
