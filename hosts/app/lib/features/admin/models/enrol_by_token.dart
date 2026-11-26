// `GET /admin/members/{token}` and `POST /admin/members/{token}/enrolments`
// (#1050): a super admin looks a member up by token number and enrols them in
// one class. The server decides who may and who counts as found; these types
// only carry the answer.
//
// The member's email and phone live in these objects only. They are never put
// in an exception message, a route or a log line.

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<EnrolClassRef> _classes(Object? value) => [
  for (final e in value as List<dynamic>? ?? const [])
    EnrolClassRef.fromJson(e as Map<String, dynamic>),
];

/// A class the member is in, left, or asked for.
class EnrolClassRef {
  const EnrolClassRef({
    required this.id,
    required this.code,
    required this.name,
    this.level,
    this.leftOn,
  });

  final int id;
  final String code;
  final String name;

  /// Only on the classes the member is in now.
  final String? level;

  /// Only on the classes the member left, as the server sends it, `2026-08-01`.
  final String? leftOn;

  factory EnrolClassRef.fromJson(Map<String, dynamic> json) => EnrolClassRef(
    id: json['id'] as int,
    code: _text(json['code']) ?? '',
    name: _text(json['name']) ?? '',
    level: _text(json['level']),
    leftOn: _text(json['leftOn']),
  );
}

class MemberDetails {
  const MemberDetails({
    required this.token,
    required this.name,
    required this.classesNow,
    required this.classesLeft,
    this.gender,
    this.email,
    this.mobile,
    this.city,
    this.country,
    this.registeredOn,
    this.requestedClass,
  });

  final int token;
  final String name;

  /// 1 gents, 2 ladies, null when none is recorded.
  final int? gender;
  final String? email;
  final String? mobile;
  final String? city;
  final String? country;
  final String? registeredOn;

  /// The class the member's join link named, or null when they came another way.
  final EnrolClassRef? requestedClass;
  final List<EnrolClassRef> classesNow;
  final List<EnrolClassRef> classesLeft;

  factory MemberDetails.fromJson(Object? body) {
    final json = body as Map<String, dynamic>;
    final requested = json['requestedClass'];
    return MemberDetails(
      token: json['token'] as int,
      name: _text(json['name']) ?? '',
      gender: json['gender'] as int?,
      email: _text(json['email']),
      mobile: _text(json['mobile']),
      city: _text(json['city']),
      country: _text(json['country']),
      registeredOn: _text(json['registeredOn']),
      requestedClass: requested is Map<String, dynamic>
          ? EnrolClassRef.fromJson(requested)
          : null,
      classesNow: _classes(json['classesNow']),
      classesLeft: _classes(json['classesLeft']),
    );
  }
}

/// A refusal the server explained; [message] is its sentence, safe to show.
sealed class EnrolRefusal implements Exception {
  const EnrolRefusal(this.message);

  final String message;
}

/// 404: no registered member has this token (guest, negative and unknown
/// tokens all answer alike).
class MemberNotFound extends EnrolRefusal {
  const MemberNotFound(super.message);
}

/// 422 `ambiguous_token`: more than one member has the number.
class AmbiguousToken extends EnrolRefusal {
  const AmbiguousToken(super.message);
}

/// 409 `already_enrolled`: nothing was written.
class AlreadyEnrolled extends EnrolRefusal {
  const AlreadyEnrolled(super.message);
}

/// 422 `other_gender`: the class is for the other gender; nothing was written.
class OtherGender extends EnrolRefusal {
  const OtherGender(super.message);
}
