import '../harness/network_switch.dart';
import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/conduction_screen.dart';

/// Journey for #719 item 5: **a conduction record saved with no network is kept
/// and sent when the device is back online.**
///
/// The path is the Not Conducted one (see reviewer_conduction_not_conducted_test)
/// because it needs only a reason, and the queue does not care what the record
/// holds. What it proves that the unit and widget tests cannot is the whole
/// chain on a device: the form opens from the copy saved while online, the save
/// is kept instead of refused, the list shows it as waiting, and going back
/// online sends it to the real server so it lands in the list.
///
/// **Order matters.** The form is opened while online, because that is what
/// saves the copy that lets it open offline. A teacher who has never opened a
/// class's form online cannot open it offline the first time; that is a known
/// limit, not something this journey hides.
///
/// **Writes.** One record, today's date, gone when the runner re-seeds the
/// cohort before the next journey.
///
/// Waits, never `expect`, for the reason the not-conducted journey records: a
/// failing `expect` inside a Patrol test hangs instead of reporting.
///
/// See docs/specs/offline-conduction-mobile/plan.md
void main() {
  patrolAppTest('reviewer saves a record offline and it is sent on reconnect', (
    $,
  ) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final conduction = ConductionScreenObject($);
    final network = NetworkSwitch($);

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.classConductionAction.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await conduction.addRecordButton.waitUntilVisible();
    await conduction.addRecordButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // Online: the form has loaded, so its data is now saved on the device.
    await conduction.addFormTitle.waitUntilVisible();

    // From here nothing reaches the server.
    await network.goOffline();

    await conduction.notConductedOption.tap();
    await $.pumpAndSettle();
    await conduction.reasonField.enterText(
      ConductionScreenObject.notConductedReason,
    );
    await $.pumpAndSettle();
    await conduction.saveButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The form closed (the FAB is back) and the record is held, not refused.
    // Before the queue this is where the run went red: the form stayed up
    // behind an error snackbar.
    await conduction.addRecordButton.waitUntilVisible();
    await conduction.unsentRecord.waitUntilVisible();

    // The server has nothing yet, so the reason is not in the list. It is a
    // positive check on the card above that carries that meaning; a negative
    // one here would pass on a blank screen.

    await network.goOnline();

    // The send, then the list refetch that follows it.
    await conduction.savedReasonRow.waitUntilExists(
      timeout: const Duration(seconds: 60),
    );

    // The waiting card must be gone once the server has the record. Checked by
    // hand rather than `expect`, which would hang instead of reporting.
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    if (conduction.unsentRecord.exists) {
      throw StateError(
        'The record reached the list but its "waiting to send" card is '
        'still showing: the queue did not clear after a successful send.',
      );
    }
  });
}
