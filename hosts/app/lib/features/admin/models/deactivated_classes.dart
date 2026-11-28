// `GET /admin/deactivated-classes` and `/candidates` (#618): the classes that
// have been retired, the log of retiring them, and the active classes one can
// choose to retire. The server shows these to the super admin only.
//
// Strict about the envelope, tolerant about the rows, as for the reports: a body
// that is not this answer throws, so the screen offers a retry.

/// 'Gents' or 'Ladies' for the gender ids the server sends; '' for anything else.
String genderLabel(int gender) => switch (gender) {
  1 => 'Gents',
  2 => 'Ladies',
  _ => '',
};

/// 'Completed' or 'Shutdown' for the type the server sends; the text as sent
/// otherwise, '' when there is none.
String deactivationTypeLabel(String type) => switch (type) {
  'completed' => 'Completed',
  'shutdown' => 'Shutdown',
  _ => type,
};

/// Text as sent, or empty for anything that is not text (a missing value, or the
/// number the server's casting can make of an empty one): one odd field must not
/// stop the whole list from loading.
String _text(Object? value) => value is String ? value : '';

/// The server's times are UTC with a Z; null when there is none or it cannot be read.
DateTime? _utc(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// A class that has been deactivated, with why and by whom.
class DeactivatedClass {
  const DeactivatedClass({
    required this.id,
    required this.code,
    required this.level,
    required this.gender,
    required this.teacher,
    required this.type,
    required this.effectiveDate,
    required this.reason,
    required this.performedBy,
    required this.performedAt,
  });

  final int id;
  final String code;
  final String level;

  /// 1 gents, 2 ladies.
  final int gender;
  final String teacher;

  /// `completed` or `shutdown`.
  final String type;

  /// `YYYY-MM-DD`, empty when unknown.
  final String effectiveDate;
  final String reason;
  final String performedBy;
  final DateTime? performedAt;

  String get genderName => genderLabel(gender);
  String get typeName => deactivationTypeLabel(type);

  /// What a search looks in, as the web table's search does.
  List<String> get searchFields => [
    code,
    level,
    genderName,
    teacher,
    type,
    effectiveDate,
    reason,
    performedBy,
  ];

  factory DeactivatedClass.fromJson(Map<String, dynamic> json) =>
      DeactivatedClass(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: _text(json['code']),
        level: _text(json['level']),
        gender: (json['gender'] as num?)?.toInt() ?? 0,
        teacher: _text(json['teacher']),
        type: _text(json['type']),
        effectiveDate: _text(json['effectiveDate']),
        reason: _text(json['reason']),
        performedBy: _text(json['performedBy']),
        performedAt: _utc(json['performedAt']),
      );
}

/// One deactivation in the activity log; a class deactivated twice is two entries.
class DeactivationLogEntry {
  const DeactivationLogEntry({
    required this.id,
    required this.code,
    required this.level,
    required this.gender,
    required this.type,
    required this.effectiveDate,
    required this.reason,
    required this.performedBy,
    required this.performedAt,
  });

  final int id;

  /// `#<id>` when the class no longer exists.
  final String code;
  final String level;
  final int gender;
  final String type;
  final String effectiveDate;
  final String reason;
  final String performedBy;
  final DateTime? performedAt;

  String get genderName => genderLabel(gender);
  String get typeName => deactivationTypeLabel(type);

  factory DeactivationLogEntry.fromJson(Map<String, dynamic> json) =>
      DeactivationLogEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: _text(json['code']),
        level: _text(json['level']),
        gender: (json['gender'] as num?)?.toInt() ?? 0,
        type: _text(json['type']),
        effectiveDate: _text(json['effectiveDate']),
        reason: _text(json['reason']),
        performedBy: _text(json['performedBy']),
        performedAt: _utc(json['performedAt']),
      );
}

/// The screen's two lists.
class DeactivatedClasses {
  const DeactivatedClasses({required this.deactivated, required this.log});

  /// Newest first.
  final List<DeactivatedClass> deactivated;

  /// Newest first.
  final List<DeactivationLogEntry> log;

  /// Throws [FormatException] when [body] is not this answer.
  factory DeactivatedClasses.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['deactivated'] is! List ||
        body['log'] is! List) {
      throw const FormatException('deactivated classes: unexpected response');
    }
    return DeactivatedClasses(
      deactivated: [
        for (final r in body['deactivated'] as List)
          if (r is Map<String, dynamic>) DeactivatedClass.fromJson(r),
      ],
      log: [
        for (final r in body['log'] as List)
          if (r is Map<String, dynamic>) DeactivationLogEntry.fromJson(r),
      ],
    );
  }
}

/// An active class that can be chosen for deactivation, with what the
/// confirmation shows.
class DeactivationCandidate {
  const DeactivationCandidate({
    required this.id,
    required this.code,
    required this.level,
    required this.gender,
    required this.teacher,
    required this.city,
    required this.students,
  });

  final int id;
  final String code;
  final String level;
  final int gender;
  final String teacher;
  final String city;
  final int students;

  String get genderName => genderLabel(gender);

  /// What a search looks in: the same as the web picker.
  List<String> get searchFields => [code, level, genderName, teacher, city];

  /// "AMMAR · Gents · Ali · Pune": what is known about the class, in order.
  String get summary =>
      [level, genderName, teacher, city].where((p) => p.isNotEmpty).join(' · ');

  factory DeactivationCandidate.fromJson(Map<String, dynamic> json) =>
      DeactivationCandidate(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: _text(json['code']),
        level: _text(json['level']),
        gender: (json['gender'] as num?)?.toInt() ?? 0,
        teacher: _text(json['teacher']),
        city: _text(json['city']),
        students: (json['students'] as num?)?.toInt() ?? 0,
      );

  /// Throws [FormatException] when [body] is not this answer.
  static List<DeactivationCandidate> listFromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['classes'] is! List) {
      throw const FormatException(
        'deactivation candidates: unexpected response',
      );
    }
    return [
      for (final c in body['classes'] as List)
        if (c is Map<String, dynamic>) DeactivationCandidate.fromJson(c),
    ];
  }
}
