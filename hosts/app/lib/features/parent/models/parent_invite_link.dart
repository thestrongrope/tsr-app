import 'package:flutter/foundation.dart';

/// A one-time invite link for adding a parent to a child (#633).
class ParentInviteLink {
  final String code;
  final String url;
  final String expiresAt;

  const ParentInviteLink({
    required this.code,
    required this.url,
    required this.expiresAt,
  });

  factory ParentInviteLink.fromJson(Map<String, dynamic> json) {
    var link = (json['link'] ?? json['url']) as String? ?? '';
    final code = json['code'] as String? ?? '';
    final defaultBase = kDebugMode
        ? 'https://localhost:4004'
        : 'https://account.thestrongrope.com';

    if (link.startsWith('/')) {
      link = '$defaultBase$link';
    } else if (link.isEmpty && code.isNotEmpty) {
      link = '$defaultBase/link/$code';
    }

    return ParentInviteLink(
      code: code,
      url: link,
      expiresAt: json['expires_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'url': url,
    'expires_at': expiresAt,
  };
}

/// What an invite link says before it is accepted: `GET /me/children/link/{code}`.
/// [state] is `valid`, `expired` (also used or cancelled) or `not_found`.
/// [firstName] is the child's first name, sent for a valid invite only.
class ParentInvitePreview {
  final String state;
  final String? firstName;

  const ParentInvitePreview({required this.state, this.firstName});

  bool get isValid => state == 'valid';

  factory ParentInvitePreview.fromJson(Map<String, dynamic> json) =>
      ParentInvitePreview(
        state: (json['state'] as String?) ?? 'not_found',
        firstName: json['first_name'] as String?,
      );
}
