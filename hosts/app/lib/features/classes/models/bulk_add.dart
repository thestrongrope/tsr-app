import 'class_manage.dart';

/// One pasted line's outcome from POST /classes/{id}/students/bulk (#691).
/// [status] is `added`, `enrolled`, `rejected`, `ready`, or one of the two
/// flags that wait for the user: `duplicate_name`, `mobile_match`.
class BulkLineResult {
  final int line;
  final String name;
  final String status;
  final String? reason;

  /// The existing member a `mobile_match` line would enrol instead.
  final String? memberName;

  const BulkLineResult({
    required this.line,
    required this.name,
    required this.status,
    this.reason,
    this.memberName,
  });

  bool get needsChoice =>
      status == 'duplicate_name' || status == 'mobile_match';

  factory BulkLineResult.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>?;
    return BulkLineResult(
      line: json['line'] as int,
      name: json['name'] as String? ?? '',
      status: json['status'] as String,
      reason: json['reason'] as String?,
      memberName: member?['name'] as String?,
    );
  }
}

/// The answer to a bulk add. [status] `confirm` means nothing was written yet:
/// the flagged lines need a choice and the list is sent again.
class BulkAddResult {
  final String status;
  final int added;
  final List<BulkLineResult> lines;

  /// The refreshed roster, present when anyone was added.
  final ManageRoster? roster;

  const BulkAddResult({
    required this.status,
    required this.added,
    required this.lines,
    this.roster,
  });

  bool get needsConfirmation => status == 'confirm';

  factory BulkAddResult.fromJson(Map<String, dynamic> json) {
    final roster = json['roster'] as Map<String, dynamic>?;
    return BulkAddResult(
      status: json['status'] as String,
      added: json['added'] as int? ?? 0,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((l) => BulkLineResult.fromJson(l as Map<String, dynamic>))
          .toList(),
      roster: roster == null ? null : ManageRoster.fromJson(roster),
    );
  }
}
