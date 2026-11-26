import '../../../core/utils/api_datetime.dart';

/// The grace period the API applies, used when a response omits it.
const int _defaultCompletionDays = 60;

/// The state of the signed-in member's account deletion request.
///
/// The wire values come from the `status` enum in
/// `migrations/2026_09_02_account_deletion_requests.sql`, plus `none`, which
/// the read route synthesises when no row exists.
enum DeletionStatus {
  none,
  pending,
  awaitingPrizeDelivery,
  completed,
  cancelled,

  /// A status this build does not recognise. Treated as restricted: if the
  /// server grows a new blocking state, opening screens it is already refusing
  /// would show an error on every one of them.
  unknown;

  static DeletionStatus fromApi(String? value) {
    switch (value) {
      case null:
      case 'none':
        return DeletionStatus.none;
      case 'pending':
        return DeletionStatus.pending;
      case 'awaiting_prize_delivery':
        return DeletionStatus.awaitingPrizeDelivery;
      case 'completed':
        return DeletionStatus.completed;
      case 'cancelled':
        return DeletionStatus.cancelled;
      default:
        return DeletionStatus.unknown;
    }
  }

  /// Whether a live request is limiting what the API will answer.
  bool get isRestricted =>
      this == DeletionStatus.pending ||
      this == DeletionStatus.awaitingPrizeDelivery ||
      this == DeletionStatus.unknown;

  /// Whether the account is gone. Not restricted — there is nothing left to
  /// restrict, and the app's only correct move is a local sign-out.
  bool get isTerminal => this == DeletionStatus.completed;
}

/// One deletion request as the member sees it.
class DeletionRequest {
  final DeletionStatus status;
  final DateTime? requestedAt;
  final int expectedCompletionDays;

  const DeletionRequest({
    required this.status,
    this.requestedAt,
    this.expectedCompletionDays = _defaultCompletionDays,
  });

  factory DeletionRequest.fromJson(Map<String, dynamic> json) {
    return DeletionRequest(
      status: DeletionStatus.fromApi(json['status'] as String?),
      requestedAt: parseApiDateTime(json['requested_at'] as String?),
      expectedCompletionDays:
          json['expected_completion_days'] as int? ?? _defaultCompletionDays,
    );
  }
}
