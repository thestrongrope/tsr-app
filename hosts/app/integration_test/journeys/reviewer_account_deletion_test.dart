import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/account_deletion_screen.dart';
import '../screens/class_list_screen.dart';

/// Journey 3 of the verification checklist: **a deletion request can be raised
/// and then cancelled.**
///
/// Apple Guideline 5.1.1(v) requires a reviewer to be able to find in-app
/// account deletion, so this path is one they will walk. It is also the only
/// journey in this suite that writes.
///
/// **Read the teardown before the body.** Raising the request closes the
/// account down to six routes and `403`s the rest, and completion is manual —
/// nothing clears a pending request on its own. So the cancel is registered as
/// a teardown *before* the request is raised, which is what makes it run when
/// an assertion throws rather than only on the happy path. Below that sits a
/// second floor: `reset-demo-cohort.sh` runs before every journey and cancels
/// any pending request for the demo cohort while rebuilding it.
///
/// Local only. Against production this would leave a state a real store
/// reviewer could walk into — see design.md, "Why local rather than the online
/// API".
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer raises a deletion request and cancels it', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final deletion = AccountDeletionScreenObject($);

    await classes.demoClassCard.waitUntilVisible();

    // Profile lives in the Me tab.
    await deletion.meTab.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await deletion.profileItem.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // scrollTo() on the button, not just on the heading above it. Scrolling
    // the Danger Zone into view leaves its button below the fold, and a bare
    // tap() then times out at Patrol's 10s selector timeout -- the same trap
    // the Sign In button set in reviewer_session.dart.
    await deletion.dangerZoneHeading.scrollTo();
    await deletion.deleteMyAccountButton.scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await deletion.requestScreenTitle.waitUntilVisible();

    // Registered before the request is raised, and deliberately so: a teardown
    // added afterwards would not exist yet if the tap itself threw.
    addTearDown(() => _cancelIfPending($, deletion));

    await deletion.requestButton.scrollTo();
    await deletion.requestButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The confirmation is a Flutter AlertDialog, so it is driven from the tree.
    await deletion.confirmDialogTitle.waitUntilVisible();
    await deletion.confirmDelete.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 60));

    // The account is now restricted. Everything from here is on the clock.
    await deletion.pendingHeading.waitUntilVisible();
    await deletion.cancelButton.waitUntilVisible();

    await deletion.cancelButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 60));

    // Cancelling returns the account to the rest of the app. Asserting on the
    // demo class rather than on the absence of the pending screen: "the class
    // list is back" is a positive statement about a restored account, where
    // "the pending screen is gone" would also be true of a crash.
    await classes.demoClassCard.waitUntilVisible();
  });
}

/// Best-effort cancel, for the case where the body threw with a request live.
///
/// Deliberately swallows its own failures. A throwing teardown replaces the
/// real failure with this one, and the reset before the next journey cancels
/// the request anyway — so the worst this can cost is one confusing run, while
/// masking the assertion that actually broke costs far more.
Future<void> _cancelIfPending(
  PatrolIntegrationTester $,
  AccountDeletionScreenObject deletion,
) async {
  try {
    if (!deletion.cancelButton.exists) return;
    await deletion.cancelButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 60));
  } catch (_) {
    // Left to reset-demo-cohort.sh.
  }
}
