// `GET /admin/teachers` and `GET /teachers/{token}` (#622): a gender's teachers
// with the levels each is trained to conduct, and one teacher's detail. The
// writes are `TrainingChange`s sent to `POST /admin/teachers/training`.
//
// Strict about the envelope, tolerant about the rows, as for the reports: a body
// that is not this answer throws, so the screen offers a retry.

/// Text as sent, or empty for anything that is not text (a missing value, or the
/// number the server's casting can make of an empty one): one odd field must not
/// stop the whole list from loading.
String _text(Object? value) => value is String ? value : '';

/// A whole number as sent, or 0 for anything else.
int _int(Object? value) => value is num ? value.toInt() : 0;

/// Text as sent, null when there is none.
String? _textOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// The five training flags as sent: level key to trained. A flag the server left
/// out is false.
Map<String, bool> _flags(Object? value, List<String> keys) {
  final sent = value is Map<String, dynamic> ? value : const {};
  return {for (final k in keys) k: sent[k] == true};
}

/// The keys of the five levels, in the order the web shows them. The server
/// sends them with the list; this is what a detail (which does not) falls back to.
const List<String> teacherLevelKeys = [
  'salman',
  'abuzar',
  'miqdad',
  'ammar',
  'bilal',
];

/// A level a teacher can be trained to conduct: `ammar`, `AY`, `Ammar`.
class TeacherLevel {
  const TeacherLevel({
    required this.key,
    required this.code,
    required this.name,
  });

  final String key;
  final String code;
  final String name;

  factory TeacherLevel.fromJson(Map<String, dynamic> json) => TeacherLevel(
    key: _text(json['key']),
    code: _text(json['code']),
    name: _text(json['name']),
  );
}

/// A teacher in the list.
class TeacherRow {
  const TeacherRow({
    required this.token,
    required this.name,
    required this.level,
    required this.classes,
    required this.flags,
    required this.conducting,
  });

  final int token;
  final String name;

  /// The level of the class they attend, as the web list shows it; empty if none.
  final String level;

  /// How many classes they are enrolled in.
  final int classes;

  /// Level key to trained.
  final Map<String, bool> flags;

  /// Codes of the classes they conduct.
  final List<String> conducting;

  bool isTrainedFor(String level) => flags[level] == true;

  /// What a search looks in: name, token and the codes of the classes they conduct.
  List<String> get searchFields => [name, '$token', ...conducting];

  factory TeacherRow.fromJson(Map<String, dynamic> json, List<String> keys) =>
      TeacherRow(
        token: _int(json['token']),
        name: _text(json['name']),
        level: _text(json['level']),
        classes: _int(json['classes']),
        flags: _flags(json['flags'], keys),
        conducting: [
          for (final c
              in json['conducting'] is List
                  ? json['conducting'] as List
                  : const [])
            if (c is String) c,
        ],
      );
}

/// The teachers of one gender, with the levels the flags stand for.
class TeachersList {
  const TeachersList({
    required this.gender,
    required this.levels,
    required this.teachers,
  });

  /// 1 gents, 2 ladies.
  final int gender;
  final List<TeacherLevel> levels;
  final List<TeacherRow> teachers;

  /// Throws [FormatException] when [body] is not this answer.
  factory TeachersList.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['gender'] is! num ||
        body['levels'] is! List ||
        body['teachers'] is! List) {
      throw const FormatException('teachers: unexpected response');
    }
    final levels = [
      for (final l in body['levels'] as List)
        if (l is Map<String, dynamic>) TeacherLevel.fromJson(l),
    ];
    final keys = levels.map((l) => l.key).toList();
    return TeachersList(
      gender: (body['gender'] as num).toInt(),
      levels: levels,
      teachers: [
        for (final t in body['teachers'] as List)
          if (t is Map<String, dynamic>) TeacherRow.fromJson(t, keys),
      ],
    );
  }
}

/// A class in a teacher's detail: one they conduct or conducted, or attend or
/// attended. Which fields are set depends on which of the four lists it is in.
class TeacherClass {
  const TeacherClass({
    required this.id,
    required this.code,
    required this.level,
    required this.city,
    required this.country,
    required this.startedOn,
    required this.endedOn,
    required this.comments,
    required this.teacher,
    required this.teacherToken,
    required this.removedBy,
    required this.schedules,
  });

  final int id;
  final String code;
  final String level;
  final String city;
  final String country;

  /// `YYYY-MM-DD`; null when unknown.
  final String? startedOn;
  final String? endedOn;
  final String? comments;

  /// The teacher of a class they attend; null in the lists of classes they conduct.
  final String? teacher;
  final int? teacherToken;
  final String? removedBy;
  final List<String> schedules;

  /// "Pune, India": what is known about where, in order.
  String get place => [city, country].where((p) => p.isNotEmpty).join(', ');

  factory TeacherClass.fromJson(Map<String, dynamic> json) => TeacherClass(
    id: _int(json['id']),
    code: _text(json['code']),
    level: _text(json['level']),
    city: _text(json['city']),
    country: _text(json['country']),
    startedOn: _textOrNull(json['startedOn']),
    endedOn: _textOrNull(json['endedOn']),
    comments: _textOrNull(json['comments']),
    teacher: _textOrNull(json['teacher']),
    teacherToken: json['teacherToken'] is num
        ? (json['teacherToken'] as num).toInt()
        : null,
    removedBy: _textOrNull(json['removedBy']),
    schedules: [
      for (final s
          in json['schedules'] is List ? json['schedules'] as List : const [])
        if (s is String) s,
    ],
  );
}

/// One entry in a teacher's training history.
class TeacherHistoryEntry {
  const TeacherHistoryEntry({
    required this.comments,
    required this.by,
    required this.on,
  });

  final String comments;
  final String by;

  /// `YYYY-MM-DD`; empty when unknown.
  final String on;

  factory TeacherHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TeacherHistoryEntry(
        comments: _text(json['comments']),
        by: _text(json['by']),
        on: _text(json['on']),
      );
}

/// One teacher: contact details, the levels trained, their classes (now and
/// before) and the history of their training.
class TeacherDetail {
  const TeacherDetail({
    required this.token,
    required this.name,
    required this.email,
    required this.mobile,
    required this.state,
    required this.city,
    required this.country,
    required this.zip,
    required this.trained,
    required this.flags,
    required this.conducting,
    required this.conducted,
    required this.attending,
    required this.attended,
    required this.history,
  });

  final int token;
  final String name;
  final String? email;
  final String? mobile;
  final String? state;
  final String? city;
  final String? country;
  final String? zip;

  /// Trained for at least one level.
  final bool trained;
  final Map<String, bool> flags;
  final List<TeacherClass> conducting;
  final List<TeacherClass> conducted;
  final List<TeacherClass> attending;
  final List<TeacherClass> attended;
  final List<TeacherHistoryEntry> history;

  /// "Pune, MH, India 411001": what is known about where, in order.
  String get address => [
    city,
    state,
    country,
    zip,
  ].whereType<String>().where((p) => p.isNotEmpty).join(', ');

  /// Throws [FormatException] when [body] is not this answer.
  factory TeacherDetail.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['token'] is! num ||
        body['flags'] is! Map) {
      throw const FormatException('teacher: unexpected response');
    }
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) read) => [
      for (final r in body[key] is List ? body[key] as List : const [])
        if (r is Map<String, dynamic>) read(r),
    ];
    return TeacherDetail(
      token: (body['token'] as num).toInt(),
      name: _text(body['name']),
      email: _textOrNull(body['email']),
      mobile: _textOrNull(body['mobile']),
      state: _textOrNull(body['state']),
      city: _textOrNull(body['city']),
      country: _textOrNull(body['country']),
      zip: _textOrNull(body['zip']),
      trained: body['trained'] == true,
      flags: _flags(body['flags'], teacherLevelKeys),
      conducting: rows('conducting', TeacherClass.fromJson),
      conducted: rows('conducted', TeacherClass.fromJson),
      attending: rows('attending', TeacherClass.fromJson),
      attended: rows('attended', TeacherClass.fromJson),
      history: rows('history', TeacherHistoryEntry.fromJson),
    );
  }
}

/// A flag the admin has changed: the teacher, the level key, and whether it was
/// switched on (`added`) or off (`removed`).
class TrainingChange {
  const TrainingChange({
    required this.token,
    required this.level,
    required this.added,
  });

  final int token;
  final String level;
  final bool added;

  Map<String, dynamic> toJson() => {
    'token': token,
    'level': level,
    'action': added ? 'added' : 'removed',
  };
}
