// `GET /admin/deletion-requests` and its actions (#416): the account-deletion
// queue the web's Deletion Requests page works. The server decides what each
// request can do (`can_complete`, `confirmation`), so nothing here repeats a rule.
//
// Strict about the envelope, tolerant about the rows, as for the donors: a body
// that is not this answer throws, so the screen offers a retry.

/// The statuses in the order the filter shows them.
const deletionStatuses = [
  'pending',
  'awaiting_prize_delivery',
  'completed',
  'cancelled',
];

String deletionStatusLabel(String status) {
  final words = status.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

String _text(Object? value) => value is String ? value : '';

String? _textOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// The confirmation the operator sends by email, for a live request that has
/// not had one recorded.
class DeletionConfirmation {
  const DeletionConfirmation({
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;

  static DeletionConfirmation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return DeletionConfirmation(
      to: _text(json['to']),
      subject: _text(json['subject']),
      body: _text(json['body']),
    );
  }
}

class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.status,
    required this.source,
    required this.memberName,
    required this.contactEmail,
    required this.requestedAt,
    required this.reason,
    required this.operatorNote,
    required this.confirmationSentAt,
    required this.handledByName,
    required this.memberZip,
    required this.memberMobile,
    required this.isDemo,
    required this.canComplete,
    required this.confirmation,
  });

  final int id;
  final String status;
  final String source;
  final String memberName;
  final String contactEmail;
  final String? requestedAt;
  final String? reason;
  final String? operatorNote;
  final String? confirmationSentAt;
  final String? handledByName;

  /// Sent only while the request is held for prize delivery.
  final String? memberZip;
  final String? memberMobile;
  final bool isDemo;
  final bool canComplete;
  final DeletionConfirmation? confirmation;

  /// Still open: pending, or held for prize delivery.
  bool get isLive => status == 'pending' || status == 'awaiting_prize_delivery';
  bool get isHeld => status == 'awaiting_prize_delivery';
  bool get confirmationSent => confirmationSentAt != null;

  factory DeletionRequest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! num) throw const FormatException('deletion request has no id');
    return DeletionRequest(
      id: id.toInt(),
      status: _text(json['status']),
      source: _text(json['source']),
      memberName: _text(json['member_name']),
      contactEmail: _text(json['contact_email']),
      requestedAt: _textOrNull(json['requested_at']),
      reason: _textOrNull(json['reason']),
      operatorNote: _textOrNull(json['operator_note']),
      confirmationSentAt: _textOrNull(json['confirmation_sent_at']),
      handledByName: _textOrNull(json['handled_by_name']),
      memberZip: _textOrNull(json['member_zip']),
      memberMobile: _textOrNull(json['member_mobile']),
      isDemo: json['is_demo'] == true,
      canComplete: json['can_complete'] == true,
      confirmation: DeletionConfirmation.fromJson(json['confirmation']),
    );
  }

  /// The `{request: {...}}` an action answers with.
  static DeletionRequest oneFromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['request'] is! Map<String, dynamic>) {
      throw const FormatException('deletion request: unexpected response');
    }
    return DeletionRequest.fromJson(json['request'] as Map<String, dynamic>);
  }
}

class DeletionQueue {
  const DeletionQueue({required this.counts, required this.requests});

  final Map<String, int> counts;
  final List<DeletionRequest> requests;

  int count(String status) => counts[status] ?? 0;
  int get total => counts.values.fold(0, (a, b) => a + b);

  factory DeletionQueue.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['requests'] is! List ||
        json['counts'] is! Map) {
      throw const FormatException('deletion requests: unexpected response');
    }
    final counts = <String, int>{
      for (final e in (json['counts'] as Map).entries)
        if (e.value is num) e.key as String: (e.value as num).toInt(),
    };
    return DeletionQueue(
      counts: counts,
      requests: [
        for (final r in json['requests'] as List<dynamic>)
          if (r is Map<String, dynamic>) DeletionRequest.fromJson(r),
      ],
    );
  }
}

/// What raising from an emailed address did: opened a request, or found the
/// member already had one open.
class RaisedDeletionRequest {
  const RaisedDeletionRequest({required this.request, required this.created});

  final DeletionRequest request;
  final bool created;

  factory RaisedDeletionRequest.fromJson(Object? json) {
    final request = DeletionRequest.oneFromJson(json);
    return RaisedDeletionRequest(
      request: request,
      created: (json as Map<String, dynamic>)['created'] == true,
    );
  }
}
