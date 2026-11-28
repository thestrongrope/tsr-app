import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/conduction_screen.dart';

/// Regression journey for issue #376: **a class marked Not Conducted saves.**
///
/// Before the fix this failed with `ApiException: Server error occurred
/// (Status: 500)`. The client was never at fault — it sent `arabicConducted:
/// false`, exactly as the web form does — but the mobile API turned that
/// `false` into SQL `NULL` for all five subject flags
/// (`tsr-account web/api/mobile/routes/conduction.php:227-231`), and those
/// columns are `char(1) NOT NULL`. A column `DEFAULT` applies only when the
/// column is *omitted*; an explicit `NULL` is `ERROR 1048`. The exception
/// escaped unhandled, so the 500 arrived with an empty body and the snackbar
/// could name no cause.
///
/// **This is the first journey in the suite that writes.** It is safe to run
/// in any order: the runner re-seeds the cohort before every journey
/// (`scripts/patrol-android.sh`), so the record this leaves behind is gone
/// before the next one starts. Nothing downstream counts sessions.
///
/// **Why it needs no date picker.** The cohort seeds sessions at one through
/// eight whole weeks back, so today is always free, and the form opens on
/// either today or the class's next scheduled date — never on a seeded one.
/// That keeps the journey clear of both the duplicate-date guard and the
/// hardcoded-date rule in design.md.
///
/// **One journey covers both routes.** `route_conduction_create` and
/// `route_conduction_update` share `api_conduction_payload()`, which is where
/// the nulls were made, so exercising create exercises the edit path's payload
/// too. A second journey would re-prove the same line.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer saves a class marked Not Conducted', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final conduction = ConductionScreenObject($);

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.classConductionAction.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await conduction.addRecordButton.waitUntilVisible();
    await conduction.addRecordButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // Arrival on the form, before anything is tapped. This wait is what makes
    // the toggle finder below unambiguous: the list underneath prints 'Not
    // Conducted' too, and only goes offstage once the push has settled.
    await conduction.addFormTitle.waitUntilVisible();

    await conduction.notConductedOption.tap();
    await $.pumpAndSettle();

    await conduction.reasonField.enterText(
      ConductionScreenObject.notConductedReason,
    );
    await $.pumpAndSettle();

    await conduction.saveButton.tap();

    // The save is a POST and then a list refetch, so it is slower than a
    // normal settle allows for.
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // Both assertions are Patrol waits, never `expect`. A failing `expect`
    // inside a Patrol test does not report its `reason:` — it surfaces only as
    // `_pendingExceptionDetails != null` in logcat, prints nothing to the
    // runner and then hangs until the watchdog fires, so the one fact a red
    // run has to carry is the one that gets lost. A failing wait is logged as
    // a named step carrying its own finder text. See plan.md task 12.
    //
    // They are also deliberately *positive*. Asserting the absence of the
    // error snackbar would pass on a blank screen, on a spinner, and on a form
    // that simply never submitted.

    // First: the form popped. On success `_submit` invalidates the sessions
    // provider and calls `context.pop()`, so the list's FAB comes back — and
    // it is absent while the form is up, which is what makes its return mean
    // something. Before the fix this is where the run goes red: the form stays
    // put behind its snackbar and the FAB never reappears.
    await conduction.addRecordButton.waitUntilVisible();

    // Second: the record actually persisted. Arriving back on the list only
    // proves the client popped; this proves a row came back from the server
    // carrying the reason that was typed. The string is one no seeded row
    // holds, so the fixture cannot satisfy it.
    await conduction.savedReasonRow.waitUntilExists();
  });
}
