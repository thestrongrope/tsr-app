import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/services/scheduled_notification_service.dart';

class _Plugin implements FlutterLocalNotificationsPlugin {
  final cancelled = <int>[];
  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [
    const PendingNotificationRequest(107000, 'reminder', '', null),
    // Class 9900's reminder: the first id that used to read as an event alarm.
    const PendingNotificationRequest(10000000, 'reminder', '', null),
    const PendingNotificationRequest(1000000000, 'event', '', null),
  ];
  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelled.add(id);
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'legacy cancellation leaves event alarms; event cancellation leaves reminders',
    () async {
      final plugin = _Plugin();
      final service = ScheduledNotificationService.instance;
      await service.initialize(plugin);
      await service.cancelAll();
      expect(plugin.cancelled, [107000, 10000000]);
      plugin.cancelled.clear();
      await service.cancelEvents();
      expect(plugin.cancelled, [1000000000]);
    },
  );
}
