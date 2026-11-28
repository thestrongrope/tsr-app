import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/scheduled_notification.dart';

/// API calls behind scheduled and reminder class notifications.
///
/// Every call is checked on the server with `notifications:send` scoped to the
/// class. The screen hiding what the caller may not touch is a courtesy, not
/// the gate.
class ClassScheduledNotificationsRepository {
  final ApiClient _apiClient;

  ClassScheduledNotificationsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ScheduledNotificationsPayload> list(int classId) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classScheduledNotificationsEndpoint(classId),
    );
    return ScheduledNotificationsPayload.fromJson(json);
  }

  Future<ClassScheduledNotification> create(
    int classId,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      AppConstants.classScheduledNotificationsEndpoint(classId),
      data: data,
    );
    return ClassScheduledNotification.fromJson(
      json['item'] as Map<String, dynamic>,
    );
  }

  Future<void> delete(int classId, int id) async {
    await _apiClient.delete<Map<String, dynamic>>(
      AppConstants.classScheduledNotificationEndpoint(classId, id),
    );
  }
}
