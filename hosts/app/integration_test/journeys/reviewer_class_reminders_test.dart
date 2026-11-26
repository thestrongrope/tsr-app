import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:the_strong_rope/core/services/notification_service.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';

/// Regression journey for the class reminder pipeline (#379 / #381).
///
/// **What this proves and what it cannot.** As merged, #379 could not fire a
/// reminder for three separate reasons. This journey covers one of them
/// end-to-end and would have caught it on the first run:
///
/// - *Covered.* `GET /classes` returned no `schedules`, so `ClassModel
///   .schedules` was always the `@Default([])` and the scheduling loop had
///   nothing to iterate. Nothing was ever registered. That is exactly what the
///   wait below detects, and it is the one failure that no unit test can see,
///   because it needs the real API, the real response shape and the real app
///   wiring together.
/// - *Not covered — receivers.* `ScheduledNotificationReceiver` and
///   `ScheduledNotificationBootReceiver` were absent from the manifest. A
///   missing receiver does not stop the request being registered; the app-side
///   registry is happy and the failure appears only at delivery, minutes to
///   days later. Nothing in a test run of any kind catches that. The manifest
///   is the control.
/// - *Not covered — the instant.* Whether a reminder is computed in the right
///   zone and survives a DST change is asserted directly, against a fixed
///   clock, in `test/core/services/next_occurrence_test.dart`.
///   `PendingNotificationRequest` does not expose its fire time, so this
///   journey cannot check it and deliberately does not pretend to.
///
/// So: this is the *integration* half. The arithmetic is unit-tested, the
/// delivery path is a manifest review, and this journey asserts that a real
/// login against a real API results in real alarms being registered.
///
/// **Read-only.** Unlike the conduction journey this writes nothing to the
/// database. It signs in, lets the class list load, and inspects the
/// notification plugin's own pending queue.
///
/// ## Running it, and reading a failure
///
/// **The API must be serving the `schedules` fix.** `tsr_mobileapi` bind-mounts
/// the *main checkout* at `/var/www/html`, not this worktree, so the emulator
/// talks to whatever branch is checked out there. On a branch that predates
/// #381, `GET /classes` omits `schedules`, nothing is scheduled, and this
/// journey fails — correctly, but for an environment reason rather than a code
/// one. Confirm with:
///
/// ```
/// curl -sk -H "Authorization: Bearer $(scripts/mint-reviewer-token.sh)" \
///   https://127.0.0.1:4005/classes | head -c 400
/// ```
///
/// **A failure here hangs until the watchdog.** Patrol does not report a thrown
/// error to the runner: it prints nothing and blocks until
/// `TSR_PATROL_TIMEOUT` (default 1800s) fires, which is the same trap the
/// conduction journey documents for `expect`. Lower it when debugging
/// (`TSR_PATROL_TIMEOUT=120 scripts/patrol-android.sh ...`), and read the
/// reason from the device rather than the runner:
///
/// ```
/// adb logcat -d -s flutter:V | grep -E "Scheduled [0-9]+ class|no class reminders"
/// ```
///
/// `🔔 Scheduled 0 class notification(s)` is the scheduler's own line and is
/// the single most useful thing in a red run: it means the loop ran and found
/// nothing to iterate, which points at the response shape, not the scheduler.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer sign-in registers class reminders', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);

    // The class list having rendered is the precondition, not the assertion:
    // reminders are scheduled from this very response, so there is nothing to
    // look for until it has arrived.
    await classes.demoClassCard.waitUntilVisible();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // ClassesNotifier fires _rescheduleNotifications without awaiting it, so
    // the alarms land shortly after the list renders rather than with it.
    // Poll instead of sampling once; a bare check here is racy and would fail
    // intermittently in a way that looks like the bug it is meant to catch.
    final pending = await _awaitClassReminders(
      NotificationService().localNotificationsPlugin,
    );

    // Not `expect`. A failing expect inside a Patrol test does not surface its
    // reason — it becomes `_pendingExceptionDetails` in logcat and then hangs
    // until the watchdog fires (see the conduction journey and plan.md task
    // 12). `StateError` is the same choice signInAsReviewer makes for a
    // missing precondition, and it carries its message to the runner.
    if (pending.isEmpty) {
      throw StateError(
        'No class reminders were registered after the class list loaded. '
        'The usual cause is the API: if GET /classes omits `schedules`, '
        'ClassModel.schedules falls back to [] and the scheduling loop has '
        'nothing to iterate — the #379 defect. Check the response shape '
        'before looking at the scheduler.',
      );
    }

    // A reminder for the demo class specifically, not merely some reminder.
    // The class is found by code elsewhere in this suite because the reset
    // migration changes its id every run; here the id is not knowable from the
    // test, so the payload's type is what is matched.
    final hasClassReminder = pending.any(
      (p) => p.payload?.contains('"type":"class_reminder"') ?? false,
    );
    if (!hasClassReminder) {
      throw StateError(
        'Reminders were registered, but none is a class_reminder. '
        'Registered payloads: ${pending.map((p) => p.payload).toList()}',
      );
    }
  });
}

/// Poll the plugin until class-range reminders appear, or give up.
///
/// The id range is the scheduler's own: it reserves ids at and above 100000
/// for class notifications so they cannot collide with the hashCode ids used
/// for FCM-triggered ones. Filtering on it keeps an unrelated notification
/// from making this journey pass.
Future<List<PendingNotificationRequest>> _awaitClassReminders(
  FlutterLocalNotificationsPlugin plugin, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  const idBase = 100000;
  final deadline = DateTime.now().add(timeout);

  var pending = <PendingNotificationRequest>[];
  while (DateTime.now().isBefore(deadline)) {
    final all = await plugin.pendingNotificationRequests();
    pending = all.where((p) => p.id >= idBase).toList();
    if (pending.isNotEmpty) {
      debugPrint('🔔 ${pending.length} class reminder(s) registered');
      return pending;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  debugPrint('🔔 no class reminders after ${timeout.inSeconds}s');
  return pending;
}
