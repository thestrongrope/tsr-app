// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/api_datetime.dart';

part 'user_notification.freezed.dart';
part 'user_notification.g.dart';

/// The API sends these as UTC with no zone marker; show them in the member's own clock.
DateTime _localTime(String value) =>
    parseApiLocalDateTime(value) ?? DateTime.parse(value);

DateTime? _localTimeOrNull(String? value) => parseApiLocalDateTime(value);

/// Model representing a notification for the user
@freezed
sealed class UserNotification with _$UserNotification {
  const factory UserNotification({
    required int id,
    required String title,
    required String body,
    String? actionLink,
    @JsonKey(fromJson: _localTime) required DateTime sentAt,
    @Default(false) bool isRead,
    @JsonKey(fromJson: _localTimeOrNull) DateTime? readAt,

    /// The classes a reminder covers (#831); empty for any other notification.
    @Default([]) List<NotificationClass> classes,
  }) = _UserNotification;

  factory UserNotification.fromJson(Map<String, dynamic> json) =>
      _$UserNotificationFromJson(json);
}

/// One class a reminder covers: enough to name it in a list and open it.
@freezed
sealed class NotificationClass with _$NotificationClass {
  const factory NotificationClass({required int id, required String name}) =
      _NotificationClass;

  factory NotificationClass.fromJson(Map<String, dynamic> json) =>
      _$NotificationClassFromJson(json);
}

/// Response model for user notifications API
@freezed
sealed class UserNotificationsResponse with _$UserNotificationsResponse {
  const factory UserNotificationsResponse({
    required List<UserNotification> notifications,
    required int total,
    required int unreadCount,
    required int limit,
    required int offset,
  }) = _UserNotificationsResponse;

  factory UserNotificationsResponse.fromJson(Map<String, dynamic> json) =>
      _$UserNotificationsResponseFromJson(json);
}
