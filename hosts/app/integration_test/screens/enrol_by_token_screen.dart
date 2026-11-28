import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/widgets/app_surface_card.dart';

/// Finders for Enrol by token (#1050): the Manage card, the token form, the
/// member's details card, the class chooser and the confirm dialog.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
class EnrolByTokenScreenObject {
  const EnrolByTokenScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The card on Manage; the screen it opens carries the same words in the
  /// AppBar, so tap this one before navigating.
  PatrolFinder get card => $('Enrol by token');

  /// The screen's title, scoped to the AppBar.
  PatrolFinder get title => $(AppBar).$('Enrol by token');

  PatrolFinder get tokenField => $(TextFormField);
  PatrolFinder get lookUpButton => $(FilledButton).$('Look up');

  /// The sentence shown when no registered member has the token.
  PatrolFinder get notFound => $('No registered member has this token');

  /// The member's details card, scoped so the chooser's class codes cannot match.
  PatrolFinder get details =>
      $(AppSurfaceCard).containing('In these classes now');
  PatrolFinder get notInAnyClass => $('Not in any class.');

  // --- The class chooser -----------------------------------------------------

  PatrolFinder get chooserSearch => $(TextField).containing('Search classes');
  PatrolFinder get noClassToChoose => $('No class to choose from.');

  /// The chooser row whose subtitle is [code].
  PatrolFinder classRow(String code) => $(ListTile).containing($(code));
  PatrolFinder get chosenMark => $(Icons.check_circle);
  PatrolFinder get alreadyInClass => $('Already in this class');
  PatrolFinder get confirmButton => $(FilledButton).containing('Confirm');

  // --- The confirm dialog ----------------------------------------------------

  PatrolFinder get enrolButton => $(AlertDialog).$(FilledButton);
}
