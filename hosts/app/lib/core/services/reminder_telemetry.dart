import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production visibility for local class reminders (#395).
///
/// Every call swallows its own failure: telemetry must never be the reason a
/// reminder is not scheduled, and in a debug or test build Firebase may not be
/// initialised at all. Delivery is deliberately not logged -- the plugin shows
/// scheduled notifications from native code, so no Dart runs at fire time.
class ReminderTelemetry {
  const ReminderTelemetry._();

  /// A scheduling failure that used to end in a `debugPrint`.
  static void recordRescheduleFailure(Object error, StackTrace stack) {
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'Reminder reschedule failed',
        fatal: false,
      );
    } catch (e) {
      debugPrint('Failed to report reminder error to Crashlytics: $e');
    }
  }

  /// Fires on each reschedule; its frequency exposes reschedule storms.
  static Future<void> logScheduled({
    required int classCount,
    required int conductionCount,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'reminders_scheduled',
        parameters: {
          'class_count': classCount,
          'conduction_count': conductionCount,
        },
      );
    } catch (e) {
      debugPrint('Failed to log reminders_scheduled: $e');
    }
  }

  /// The payload types of the local class reminders. A push (an announcement,
  /// a quiz release) is not a reminder and must not count as one.
  static bool isReminderType(String type) =>
      type == 'class_reminder' || type == 'conduction_reminder';

  /// Fires when a reminder is tapped; [type] is the payload's `type`.
  static Future<void> logOpened(String type) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'reminder_opened',
        parameters: {'type': type},
      );
    } catch (e) {
      debugPrint('Failed to log reminder_opened: $e');
    }
  }
}
