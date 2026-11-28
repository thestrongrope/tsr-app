// `GET/POST /admin/class-access/...` (#1034): a coordination admin finds a
// member, sees the classes they manage and the rule each comes from, and adds
// or removes access. The server decides who may; these types only carry it.

import 'permission_grants.dart';

String _text(Object? value) => value is String ? value : '';

List<String> _names(Object? value) => [
  if (value is List<dynamic>)
    for (final v in value)
      if (v is String && v.isNotEmpty) v,
];

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) => [
  for (final e in value as List<dynamic>? ?? const [])
    parse(e as Map<String, dynamic>),
];

class AccessClass {
  const AccessClass({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory AccessClass.fromJson(Map<String, dynamic> json) => AccessClass(
    id: json['id'] as int,
    code: _text(json['code']),
    name: _text(json['name']),
  );
}

/// One rule the member holds and the classes it reaches (at most 200 are sent;
/// [classCount] is the real total).
class AccessRule {
  const AccessRule({
    required this.id,
    required this.note,
    required this.createdAt,
    required this.classCount,
    required this.classes,
  });

  final int id;

  /// The rule in words, such as "Gents, levels 3-5".
  final String note;

  /// As the server sends it, `2026-10-01T10:00:00`.
  final String createdAt;
  final int classCount;
  final List<AccessClass> classes;

  factory AccessRule.fromJson(Map<String, dynamic> json) => AccessRule(
    id: json['id'] as int,
    note: _text(json['note']),
    createdAt: _text(json['createdAt']),
    classCount: json['classCount'] as int? ?? 0,
    classes: _list(json['classes'], AccessClass.fromJson),
  );
}

class MemberAccess {
  const MemberAccess({
    required this.member,
    required this.version,
    required this.fromRole,
    required this.rules,
  });

  final MemberRef member;

  /// Echoed on every write, so a change made by someone else is caught.
  final String version;

  /// One line when the member's role already reaches classes, else null.
  final String? fromRole;
  final List<AccessRule> rules;

  factory MemberAccess.fromJson(Object? body) {
    final json = body as Map<String, dynamic>;
    final fromRole = json['fromRole'];
    return MemberAccess(
      member: MemberRef.fromJson(json['member'] as Map<String, dynamic>),
      version: _text(json['version']),
      fromRole: fromRole is String && fromRole.isNotEmpty ? fromRole : null,
      rules: _list(json['rules'], AccessRule.fromJson),
    );
  }
}

class AccessOption {
  const AccessOption({required this.id, required this.name});

  final int id;
  final String name;

  factory AccessOption.fromJson(Map<String, dynamic> json) =>
      AccessOption(id: json['id'] as int, name: _text(json['name']));
}

/// What the admin chose for one condition field: the values of a field are
/// alternatives (`level` takes level ids; `city`, `country` and `tag` take names).
class AccessFilter {
  const AccessFilter(this.field, this.values);

  final String field;
  final List<Object> values;

  List<Map<String, Object?>> toConditions() => [
    for (final v in values) {'field': field, 'negate': false, 'value': v},
  ];
}

/// What the admin may choose from: the genders their permission reaches, the
/// class levels, and the cities, countries and tags of the classes they manage.
class AccessOptions {
  const AccessOptions({
    required this.genders,
    required this.levels,
    this.cities = const [],
    this.countries = const [],
    this.tags = const [],
  });

  final List<AccessOption> genders;
  final List<AccessOption> levels;
  final List<String> cities;
  final List<String> countries;
  final List<String> tags;

  factory AccessOptions.fromJson(Object? body) {
    final json = body as Map<String, dynamic>;
    return AccessOptions(
      genders: _list(json['genders'], AccessOption.fromJson),
      levels: _list(json['levels'], AccessOption.fromJson),
      cities: _names(json['cities']),
      countries: _names(json['countries']),
      tags: _names(json['tags']),
    );
  }
}

/// The classes an access would reach. At most 200 are listed; [count] is the
/// real total. [previewHash] stands for the full list and goes back with the
/// grant, so the server can tell when the classes changed since they were shown.
class ClassPreview {
  const ClassPreview({
    required this.classes,
    required this.count,
    required this.previewHash,
  });

  final List<AccessClass> classes;
  final int count;
  final String previewHash;

  factory ClassPreview.fromJson(Object? body) {
    final json = body as Map<String, dynamic>;
    final classes = _list(json['classes'], AccessClass.fromJson);
    return ClassPreview(
      classes: classes,
      count: json['classCount'] as int? ?? classes.length,
      previewHash: _text(json['previewHash']),
    );
  }
}

/// 409 `preview_changed`: the classes differ from those shown. Nothing was
/// saved; [preview] is the current list, to show and ask again.
class PreviewChanged implements Exception {
  const PreviewChanged(this.preview);

  final ClassPreview preview;
}

/// 409 `member_changed`: someone else changed this member first. Nothing was
/// saved; the member must be read again.
class MemberChanged implements Exception {
  const MemberChanged();
}
