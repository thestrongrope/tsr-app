// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationHistory _$NotificationHistoryFromJson(Map<String, dynamic> json) =>
    _NotificationHistory(
      notificationId: (json['notification_id'] as num).toInt(),
      title: json['title'] as String,
      body: json['body'] as String,
      targetAudienceCriteria: TargetAudienceCriteria.fromJson(
        json['target_audience_criteria'] as Map<String, dynamic>,
      ),
      deviceCount: (json['device_count'] as num).toInt(),
      successCount: (json['success_count'] as num).toInt(),
      failureCount: (json['failure_count'] as num).toInt(),
      sentAt: json['sent_at'] as String,
      senderName: json['sender_name'] as String,
      senderEmail: json['sender_email'] as String,
      actionLink: json['action_link'] as String?,
      audienceSummary: json['audience_summary'] as String? ?? '',
      audienceItems:
          (json['audience_items'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$NotificationHistoryToJson(
  _NotificationHistory instance,
) => <String, dynamic>{
  'notification_id': instance.notificationId,
  'title': instance.title,
  'body': instance.body,
  'target_audience_criteria': instance.targetAudienceCriteria,
  'device_count': instance.deviceCount,
  'success_count': instance.successCount,
  'failure_count': instance.failureCount,
  'sent_at': instance.sentAt,
  'sender_name': instance.senderName,
  'sender_email': instance.senderEmail,
  'action_link': instance.actionLink,
  'audience_summary': instance.audienceSummary,
  'audience_items': instance.audienceItems,
  'recipient_count': instance.recipientCount,
};

_TargetAudienceCriteria _$TargetAudienceCriteriaFromJson(
  Map<String, dynamic> json,
) => _TargetAudienceCriteria(
  type: json['type'] as String,
  value: (json['value'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$TargetAudienceCriteriaToJson(
  _TargetAudienceCriteria instance,
) => <String, dynamic>{'type': instance.type, 'value': instance.value};

_NotificationHistoryResponse _$NotificationHistoryResponseFromJson(
  Map<String, dynamic> json,
) => _NotificationHistoryResponse(
  notifications: (json['notifications'] as List<dynamic>)
      .map((e) => NotificationHistory.fromJson(e as Map<String, dynamic>))
      .toList(),
  limit: (json['limit'] as num).toInt(),
  offset: (json['offset'] as num).toInt(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$NotificationHistoryResponseToJson(
  _NotificationHistoryResponse instance,
) => <String, dynamic>{
  'notifications': instance.notifications,
  'limit': instance.limit,
  'offset': instance.offset,
  'count': instance.count,
};
