// `GET /admin/transfers/...` (#420): the classes one can move students between,
// who can be moved out of one, the result of a move and the log of past ones.
// The server shows these to the super admin only, and shows them in full.

import '../../../core/utils/api_datetime.dart';

/// 'Gents' or 'Ladies' for the gender ids the server sends; '' otherwise.
String transferGenderLabel(int gender) => switch (gender) {
  1 => 'Gents',
  2 => 'Ladies',
  _ => '',
};

String _text(Object? value) => value is String ? value : '';

String? _textOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class TransferClass {
  const TransferClass({
    required this.id,
    required this.code,
    required this.name,
    required this.level,
    required this.gender,
    required this.teacher,
    required this.city,
    required this.country,
    required this.students,
    required this.active,
  });

  final int id;
  final String code;
  final String name;
  final String level;
  final int gender;
  final String? teacher;
  final String? city;
  final String? country;
  final int students;
  final bool active;

  factory TransferClass.fromJson(Map<String, dynamic> json) => TransferClass(
    id: json['id'] as int,
    code: _text(json['code']),
    name: _text(json['name']),
    level: _text(json['level']),
    gender: json['gender'] as int? ?? 0,
    teacher: _textOrNull(json['teacher']),
    city: _textOrNull(json['city']),
    country: _textOrNull(json['country']),
    students: json['students'] as int? ?? 0,
    active: json['active'] == true,
  );

  /// The one line a class is listed by: code, name, then level and teacher.
  String get subtitle => [
    level,
    teacher,
    city,
    country,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
}

class TransferClasses {
  const TransferClasses({required this.classes, required this.levels});

  final List<TransferClass> classes;
  final List<String> levels;

  factory TransferClasses.fromJson(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Not the transfer classes answer');
    }
    return TransferClasses(
      classes: [
        for (final c in body['classes'] as List<dynamic>)
          TransferClass.fromJson(c as Map<String, dynamic>),
      ],
      levels: [for (final l in body['levels'] as List<dynamic>) l as String],
    );
  }
}

/// The classes that pass the filters and the search, as the web page does:
/// [gender] 0 means all, [level] empty means all, and [query] matches the
/// code, name, level, teacher, city or country in any case. Destinations are
/// [activeOnly]; a source may be a deactivated class.
List<TransferClass> filterTransferClasses(
  List<TransferClass> classes, {
  int gender = 0,
  String level = '',
  String query = '',
  bool activeOnly = false,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final c in classes)
      if ((gender == 0 || c.gender == gender) &&
          (level.isEmpty || c.level == level) &&
          (!activeOnly || c.active) &&
          (needle.isEmpty ||
              [
                c.code,
                c.name,
                c.level,
                c.teacher,
                c.city,
                c.country,
              ].any((f) => f != null && f.toLowerCase().contains(needle))))
        c,
  ];
}

class TransferStudent {
  const TransferStudent({
    required this.token,
    required this.name,
    required this.email,
    required this.mobile,
    required this.joinedOn,
    required this.removedOn,
    required this.fromDeactivation,
  });

  final int token;
  final String name;
  final String? email;
  final String? mobile;
  final String? joinedOn;
  final String? removedOn;

  /// A student the class had when it was deactivated, not one it has now.
  final bool fromDeactivation;

  factory TransferStudent.fromJson(Map<String, dynamic> json) =>
      TransferStudent(
        token: json['token'] as int,
        name: _text(json['name']),
        email: _textOrNull(json['email']),
        mobile: _textOrNull(json['mobile']),
        joinedOn: _textOrNull(json['joinedOn']),
        removedOn: _textOrNull(json['removedOn']),
        fromDeactivation: json['fromDeactivation'] == true,
      );

  static List<TransferStudent> listFromJson(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Not the transfer students answer');
    }
    return [
      for (final s in body['students'] as List<dynamic>)
        TransferStudent.fromJson(s as Map<String, dynamic>),
    ];
  }

  /// Does [query] match the name, token, email or mobile?
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      name,
      '$token',
      email,
      mobile,
    ].any((f) => f != null && f.toLowerCase().contains(needle));
  }
}

/// A student named in a move's answer; the name is null for a token the
/// source class did not list.
class TransferOutcome {
  const TransferOutcome({required this.token, required this.name, this.reason});

  final int token;
  final String? name;
  final String? reason;

  String get label => name ?? 'Student $token';

  factory TransferOutcome.fromJson(Map<String, dynamic> json) =>
      TransferOutcome(
        token: json['token'] as int,
        name: _textOrNull(json['name']),
        reason: _textOrNull(json['reason']),
      );
}

/// Who moved and who did not.
class TransferResult {
  const TransferResult({required this.moved, required this.failed});

  final List<TransferOutcome> moved;
  final List<TransferOutcome> failed;

  factory TransferResult.fromJson(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Not the transfer answer');
    }
    return TransferResult(
      moved: [
        for (final m in body['moved'] as List<dynamic>)
          TransferOutcome.fromJson(m as Map<String, dynamic>),
      ],
      failed: [
        for (final f in body['failed'] as List<dynamic>)
          TransferOutcome.fromJson(f as Map<String, dynamic>),
      ],
    );
  }
}

class TransferHistoryEntry {
  const TransferHistoryEntry({
    required this.id,
    required this.studentToken,
    required this.studentName,
    required this.type,
    required this.fromCode,
    required this.toCode,
    required this.reason,
    required this.transferredBy,
    required this.transferredAt,
  });

  final int id;
  final int studentToken;
  final String studentName;
  final String type;
  final String fromCode;
  final String toCode;
  final String? reason;
  final String transferredBy;
  final DateTime? transferredAt;

  factory TransferHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TransferHistoryEntry(
        id: json['id'] as int,
        studentToken: json['studentToken'] as int,
        studentName: _text(json['studentName']),
        type: _text(json['type']),
        fromCode: _text(json['fromCode']),
        toCode: _text(json['toCode']),
        reason: _textOrNull(json['reason']),
        transferredBy: _text(json['transferredBy']),
        transferredAt: parseApiLocalDateTime(_text(json['transferredAt'])),
      );
}

class TransferHistoryPage {
  const TransferHistoryPage({required this.total, required this.items});

  final int total;
  final List<TransferHistoryEntry> items;

  factory TransferHistoryPage.fromJson(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Not the transfer history answer');
    }
    return TransferHistoryPage(
      total: body['total'] as int,
      items: [
        for (final i in body['items'] as List<dynamic>)
          TransferHistoryEntry.fromJson(i as Map<String, dynamic>),
      ],
    );
  }
}

/// The moves a type can be, in the order they are offered.
const transferTypes = <String, String>{
  'promotion': 'Promotion',
  'transfer': 'Transfer',
  'demotion': 'Demotion',
};
