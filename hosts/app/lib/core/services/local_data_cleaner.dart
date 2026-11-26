import 'package:flutter/foundation.dart';
import '../../features/calendar/calendar_repository.dart';
import 'package:hive_ce/hive.dart';

import '../providers/permissions_provider.dart';
import 'scheduled_notification_service.dart';
import '../../features/classes/repositories/classes_repository.dart';
import '../../features/classes/services/conduction_queue_store.dart';
import '../../features/feedback/services/feedback_queue_store.dart';
import '../../features/grand_quiz/repositories/grand_quiz_repository.dart';
import '../../features/home/services/recent_actions_store.dart';
import '../../features/wordpress/services/bookmark_service.dart';
import '../../features/notifications/providers/user_notifications_provider.dart';
import '../constants/app_constants.dart';

/// Clears the on-device data that belongs to the signed-in member, so the next
/// person to sign in on this device sees none of it. Each step is independent:
/// one failing never stops the others, and nothing here throws.
///
/// Deliberately NOT cleared, because it is not per-user:
/// - `settings_box` (theme, notification and reminder settings: per device),
///   except its `recent_actions:<token>` keys (Home's Jump back in) and its
///   `conduction_queue:<token>` keys (unsent conduction records), cleared below
/// - the syllabus and WordPress content caches in `cache_box` (public content)
/// Cleared here, being saved copies of the member's own data: the classes and
/// class performance copies (`classes_cache`) and the notification inbox copy
/// (`notifications_inbox_<token>` in `cache_box`).
/// Also cleared here: the remembered permissions and the scheduled class and
/// conduction reminders. Sign-out and account deletion both run this.
///
/// Returns the names of the steps that failed (empty when all succeeded), so
/// account deletion can tell the member some data could not be removed.
Future<List<String>> clearPerUserLocalData() async {
  final failed = <String>[];
  Future<void> step(String what, Future<void> Function() clear) async {
    try {
      await clear();
    } catch (e) {
      debugPrint('🟡 Failed to clear $what: $e');
      failed.add(what);
    }
  }

  await step('grand quiz cache', () => GrandQuizRepository().clearCache());
  await step('classes cache', () => ClassesRepository().clearCache());
  await step('notification inbox copies', clearSavedInboxes);
  await step('offline box', () => Hive.box(AppConstants.offlineBoxKey).clear());
  await step('bookmarks', () => BookmarkService().clearAllBookmarks());
  await step('recent actions', () => RecentActionsStore().clearAll());
  await step('unsent conduction', () => ConductionQueueStore().clearAll());
  await step('unsent feedback', () => FeedbackQueueStore().clearAll());
  await step('permissions', PermissionsNotifier.deleteSaved);
  await step('calendar and unsent settings', CalendarRepository.clearAll);
  await step(
    'event alerts',
    () => ScheduledNotificationService.instance.cancelEvents(),
  );
  await step(
    'scheduled reminders',
    () => ScheduledNotificationService.instance.cancelAll(),
  );
  return failed;
}

@visibleForTesting
Future<void> clearSavedInboxes() async {
  final box = Hive.box(AppConstants.cacheBoxKey);
  final keys = box.keys.where(
    (k) => '$k'.startsWith(UserNotificationsNotifier.savedInboxPrefix),
  );
  await box.deleteAll(keys.toList());
}
