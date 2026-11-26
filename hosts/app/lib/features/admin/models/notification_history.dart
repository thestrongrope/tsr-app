// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_history.freezed.dart';
part 'notification_history.g.dart';

/// Notification history model representing a sent notification record
@freezed
sealed class NotificationHistory with _$NotificationHistory {
  const factory NotificationHistory({
    @JsonKey(name: 'notification_id') required int notificationId,
    required String title,
    required String body,
    @JsonKey(name: 'target_audience_criteria')
    required TargetAudienceCriteria targetAudienceCriteria,
    @JsonKey(name: 'device_count') required int deviceCount,
    @JsonKey(name: 'success_count') required int successCount,
    @JsonKey(name: 'failure_count') required int failureCount,
    @JsonKey(name: 'sent_at') required String sentAt,
    @JsonKey(name: 'sender_name') required String senderName,
    @JsonKey(name: 'sender_email') required String senderEmail,

    /// Where the notification opens in the app, when it has a link.
    @JsonKey(name: 'action_link') String? actionLink,

    /// Who it went to, in words ("Students of a class"), then the classes,
    /// levels or teacher by name. Empty when an older server does not send it.
    @JsonKey(name: 'audience_summary') @Default('') String audienceSummary,
    @JsonKey(name: 'audience_items') @Default([]) List<String> audienceItems,

    /// How many people have it in their inbox.
    @JsonKey(name: 'recipient_count') @Default(0) int recipientCount,
  }) = _NotificationHistory;

  factory NotificationHistory.fromJson(Map<String, dynamic> json) =>
      _$NotificationHistoryFromJson(json);
}

/// Target audience criteria model
@freezed
sealed class TargetAudienceCriteria with _$TargetAudienceCriteria {
  const factory TargetAudienceCriteria({
    required String type,
    List<String>? value,
  }) = _TargetAudienceCriteria;

  factory TargetAudienceCriteria.fromJson(Map<String, dynamic> json) =>
      _$TargetAudienceCriteriaFromJson(json);
}

/// Response model for notification history API
@freezed
sealed class NotificationHistoryResponse with _$NotificationHistoryResponse {
  const factory NotificationHistoryResponse({
    required List<NotificationHistory> notifications,
    required int limit,
    required int offset,
    required int count,
  }) = _NotificationHistoryResponse;

  factory NotificationHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationHistoryResponseFromJson(json);
}
