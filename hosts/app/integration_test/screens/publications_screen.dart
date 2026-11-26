import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

/// Finders for the Publications screen and the way a guest reaches it.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// The list comes live from thestrongrope.com, so nothing here names a
/// publication's title: those change whenever the website adds a book. Only
/// the app's own labels and the language names are used.
class PublicationsScreenObject {
  const PublicationsScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The Library tab, and its Publications item.
  PatrolFinder get libraryTab => $(GlassBottomNavBar).$('Library');

  PatrolFinder get libraryItem => $(ListTile).containing('Publications');

  PatrolFinder get title => $(AppBar).$('Publications');

  PatrolFinder get allChip => $(ChoiceChip).containing('All');

  PatrolFinder get englishChip => $(ChoiceChip).containing('English');

  PatrolFinder get hindiChip => $(ChoiceChip).containing('Hindi');

  /// One per publication shown.
  PatrolFinder get cards => $(Card);

  /// A card's language line, e.g. "Hindi · PDF · Updated Apr 06, 2024".
  PatrolFinder detailsIn(String language) =>
      $(RegExp('^${RegExp.escape(language)} · '));

  PatrolFinder get searchField => $(TextField);

  PatrolFinder get clearSearch =>
      $(IconButton).which<IconButton>((b) => b.tooltip == 'Clear search');

  PatrolFinder get noMatch => $('No publications match your search.');

  PatrolFinder get loadError => $('Could not load publications');
}
