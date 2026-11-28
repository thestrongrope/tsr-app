import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/scheduled_notification.dart';
import '../repositories/class_scheduled_notifications_repository.dart';

final classScheduledNotificationsRepositoryProvider =
    Provider<ClassScheduledNotificationsRepository>((ref) {
      return ClassScheduledNotificationsRepository();
    });

/// The schedules and the class's live slots for one class. Invalidate it after
/// a create or delete.
final classScheduledNotificationsProvider = FutureProvider.autoDispose
    .family<ScheduledNotificationsPayload, int>((ref, classId) {
      return ref
          .watch(classScheduledNotificationsRepositoryProvider)
          .list(classId);
    });

/// The IANA zone of this phone, such as `Asia/Kolkata`. A scheduled
/// notification is timed in it. Never defaulted: if the phone cannot say, the
/// future fails and nothing is saved.
final deviceTimezoneProvider = FutureProvider<String>((ref) async {
  final info = await FlutterTimezone.getLocalTimezone();
  return info.identifier;
});
