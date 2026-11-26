import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

/// Finders for Class admins (#1034): the Manage card, the member search, the
/// member's rules, the add sheet and the remove dialog.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
class ClassAccessScreenObject {
  const ClassAccessScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The card on Manage; the screens it opens carry the same words in the
  /// AppBar, so tap this one before navigating.
  PatrolFinder get card => $('Class admins');

  /// Both screens' title, scoped to the AppBar.
  PatrolFinder get title => $(AppBar).$('Class admins');

  /// The member search field and its button.
  PatrolFinder get searchField => $(TextField);
  PatrolFinder get searchButton => $(Icons.search);

  /// A member in the search results, scoped to the list so the typed text in
  /// the field cannot match.
  PatrolFinder result(String name) => $(ListTile).$(name);

  /// The search found nobody.
  PatrolFinder get noMemberFound => $(RegExp('^No member found'));

  /// The member's screen says they manage nothing.
  PatrolFinder get managesNothing => $(RegExp('does not manage any class yet'));

  PatrolFinder get addButton => $(FilledButton).$('Add class access');

  /// A rule card's title, e.g. "Gents, level 4, Pune".
  PatrolFinder get rule => $(RegExp(r'^Gents, level 4, Pune$'));
  PatrolFinder get removeButton => $(TextButton).$('Remove');

  // --- The add sheet ---------------------------------------------------------

  PatrolFinder get sheet => $(BottomSheet);
  PatrolFinder get sheetScrollable => $(BottomSheet).$(Scrollable);
  PatrolFinder get previewButton => $(BottomSheet).$('Preview classes');
  PatrolFinder get reasonField => $(BottomSheet).$(TextField);
  PatrolFinder get addAccessButton => $(BottomSheet).$(FilledButton);
  PatrolFinder get reaches => $(BottomSheet).$(RegExp(r'^Reaches \d+ class'));

  // --- The remove dialog -----------------------------------------------------

  PatrolFinder get removeReasonField => $(AlertDialog).$(TextField);
  PatrolFinder get confirmRemoveButton => $(AlertDialog).$(FilledButton);
}
