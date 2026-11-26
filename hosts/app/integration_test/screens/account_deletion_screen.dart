import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

/// Finders for the account-deletion path: the Me tab that reaches Profile, the
/// Danger Zone, the request screen and its confirmation, and the pending screen
/// that the request locks the account into.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// **This is the one journey that writes.** A pending request closes the
/// account down to six routes and `403`s the rest, and completion is manual, so
/// nothing clears it on its own. Two things make that safe rather than
/// hopeful: the journey cancels in `addTearDown`, so the cancel runs even when
/// an assertion throws, and `reset-demo-cohort.sh` — which now runs before
/// *every* journey, not once per invocation — cancels any pending request for
/// the demo cohort as part of rebuilding it. The teardown is the fast path; the
/// reset is the floor.
class AccountDeletionScreenObject {
  const AccountDeletionScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The Me tab, and its Profile item.
  PatrolFinder get meTab => $(GlassBottomNavBar).$('Me');
  PatrolFinder get profileItem => $(ListTile).containing('Profile');

  /// The Danger Zone's button on the profile screen. Its label is the same
  /// string as the confirmation dialog's destructive action below, but the two
  /// are never in the tree at once — the dialog only exists a screen later.
  PatrolFinder get dangerZoneHeading => $('Danger Zone');
  PatrolFinder get deleteMyAccountButton => $('Delete my account');

  /// The request screen, reached from [deleteMyAccountButton]. It has no
  /// AppBar: since #379 (06920f87) the title is a plain `Text` in a header row
  /// beside a `CustomBackButton`, and it reads 'Delete Account', capital A.
  /// The old `$(AppBar).$('Delete account')` waited out its timeout and hung
  /// the whole run behind the per-journey watchdog.
  PatrolFinder get requestScreenTitle => $('Delete Account');
  PatrolFinder get requestButton => $('Request account deletion');

  /// The confirmation dialog raised by [requestButton]. A Flutter
  /// `AlertDialog`, not a platform one, so it is driven from the widget tree
  /// and needs no native automation.
  PatrolFinder get confirmDialog => $(AlertDialog);
  PatrolFinder get confirmDialogTitle => $('Delete your account?');
  PatrolFinder get confirmDelete => $(AlertDialog).$('Delete my account');
  PatrolFinder get keepMyAccount => $(AlertDialog).$('Keep my account');

  /// The pending screen. `'Deletion requested'` rather than the on-hold
  /// wording, which only appears when a prize is owed.
  PatrolFinder get pendingHeading => $('Deletion requested');
  PatrolFinder get cancelButton => $('Cancel deletion');
}
