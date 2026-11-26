import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

/// Finders for the version row in the Me tab and the release-notes screen.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// No release wording or version number is named here: both change every
/// release. Only the app's own labels are used.
class ReleaseNotesScreenObject {
  const ReleaseNotesScreenObject(this.$);

  final PatrolIntegrationTester $;

  PatrolFinder get meTab => $(GlassBottomNavBar).$('Me');

  /// "Version 1.1.0 (16)" in the Me tab.
  PatrolFinder get versionRow => $(ListTile).containing(RegExp('^Version'));

  PatrolFinder get title => $(AppBar).$('Release notes');

  /// One per release shown.
  PatrolFinder get cards => $(Card);

  PatrolFinder get loadError => $('The release notes could not be loaded.');

  PatrolFinder get noNotes => $('No release notes yet.');
}
