// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserNotification _$UserNotificationFromJson(Map<String, dynamic> json) =>
    _UserNotification(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      body: json['body'] as String,
      actionLink: json['actionLink'] as String?,
      sentAt: _localTime(json['sentAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      readAt: _localTimeOrNull(json['readAt'] as String?),
      classes:
          (json['classes'] as List<dynamic>?)
              ?.map(
                (e) => NotificationClass.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$UserNotificationToJson(_UserNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'actionLink': instance.actionLink,
      'sentAt': instance.sentAt.toIso8601String(),
      'isRead': instance.isRead,
      'readAt': instance.readAt?.toIso8601String(),
      'classes': instance.classes,
    };

_NotificationClass _$NotificationClassFromJson(Map<String, dynamic> json) =>
    _NotificationClass(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$NotificationClassToJson(_NotificationClass instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_UserNotificationsResponse _$UserNotificationsResponseFromJson(
  Map<String, dynamic> json,
) => _UserNotificationsResponse(
  notifications: (json['notifications'] as List<dynamic>)
      .map((e) => UserNotification.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  unreadCount: (json['unreadCount'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  offset: (json['offset'] as num).toInt(),
);

Map<String, dynamic> _$UserNotificationsResponseToJson(
  _UserNotificationsResponse instance,
) => <String, dynamic>{
  'notifications': instance.notifications,
  'total': instance.total,
  'unreadCount': instance.unreadCount,
  'limit': instance.limit,
  'offset': instance.offset,
};
