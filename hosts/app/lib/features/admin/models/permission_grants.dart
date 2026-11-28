// `GET/POST /admin/permissions/...` (#567): finding a member, what they hold
// (from their role and granted to them, apart) and what may still be granted.
// Only the super admin sees these; the server checks it on every call.

String _text(Object? value) => value is String ? value : '';

String? _textOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class MemberRef {
  const MemberRef({required this.token, required this.name});

  final int token;
  final String name;

  factory MemberRef.fromJson(Map<String, dynamic> json) =>
      MemberRef(token: json['token'] as int, name: _text(json['name']));

  static List<MemberRef> listFromJson(Object? body) {
    final members = (body as Map<String, dynamic>)['members'] as List<dynamic>?;
    return [
      for (final m in members ?? const [])
        MemberRef.fromJson(m as Map<String, dynamic>),
    ];
  }
}

/// A permission as the app shows it: what it lets the member do, and how far.
class PermissionInfo {
  const PermissionInfo({
    required this.name,
    required this.description,
    required this.reach,
  });

  final String name;
  final String description;
  final String reach;

  factory PermissionInfo.fromJson(Map<String, dynamic> json) => PermissionInfo(
    name: _text(json['name']),
    description: _text(json['description']),
    reach: _text(json['reach']),
  );
}

/// A live grant: the permission, who gave it, when and why.
class GrantedPermission {
  const GrantedPermission({
    required this.id,
    required this.info,
    required this.reason,
    required this.grantedBy,
    required this.grantedAt,
  });

  final int id;
  final PermissionInfo info;
  final String? reason;
  final String? grantedBy;

  /// As the server sends it, `2026-10-01T10:00:00`.
  final String? grantedAt;

  factory GrantedPermission.fromJson(Map<String, dynamic> json) =>
      GrantedPermission(
        id: json['id'] as int,
        info: PermissionInfo.fromJson(json),
        reason: _textOrNull(json['reason']),
        grantedBy: _textOrNull(json['grantedBy']),
        grantedAt: _textOrNull(json['grantedAt']),
      );
}

class MemberPermissions {
  const MemberPermissions({
    required this.member,
    required this.fromRole,
    required this.granted,
    required this.grantable,
  });

  final MemberRef member;

  /// What their role gives; not changed from here.
  final List<PermissionInfo> fromRole;

  /// Grants made from the app or by migration, each of which can be revoked.
  final List<GrantedPermission> granted;

  /// What may still be granted: not held in any way.
  final List<PermissionInfo> grantable;

  factory MemberPermissions.fromJson(Object? body) {
    final json = body as Map<String, dynamic>;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final e in json[key] as List<dynamic>? ?? const [])
        parse(e as Map<String, dynamic>),
    ];
    return MemberPermissions(
      member: MemberRef.fromJson(json['member'] as Map<String, dynamic>),
      fromRole: list('fromRole', PermissionInfo.fromJson),
      granted: list('granted', GrantedPermission.fromJson),
      grantable: list('grantable', PermissionInfo.fromJson),
    );
  }
}
