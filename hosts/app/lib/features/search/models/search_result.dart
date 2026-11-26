// What global search finds (#557): results grouped by kind. A result carries
// where a tap goes, either a route inside the app or an address outside it.

enum SearchKind {
  article,
  video,
  publication,
  classRecord,
  teacher,
  guide,
  student,
  subscriber,
  destination,
}

/// One thing found.
class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.target,
  });

  final SearchKind kind;

  /// The record's id (a class id, a token, a level id for a guide's class, an
  /// article id); 0 for a destination.
  final int id;
  final String title;
  final String subtitle;

  /// A route path in the app (`/students/101`), or an `https://` address for a
  /// video or a publication.
  final String target;
}

/// The results of one kind, with how many were found.
class SearchGroup {
  const SearchGroup({
    required this.kind,
    required this.results,
    required this.count,
    this.capped = false,
  });

  final SearchKind kind;
  final List<SearchResult> results;

  /// How many were found. For a private kind this is the number that passed the
  /// server's access check.
  final int count;

  /// The server stopped at its limit, so there may be more.
  final bool capped;
}

/// Everything one search found, as the screen shows it: what answered, what
/// could not be searched, and whether anything is still on its way. A kind that
/// failed is named so the screen never presents the results as complete.
class GlobalSearchView {
  const GlobalSearchView({
    required this.groups,
    required this.failed,
    required this.searching,
  });

  /// Nothing asked yet: the query was too short.
  static const idle = GlobalSearchView(
    groups: {},
    failed: {},
    searching: false,
  );

  /// The kinds that answered, with their results.
  final Map<SearchKind, SearchGroup> groups;

  /// The kinds that were asked and could not be searched.
  final Set<SearchKind> failed;

  /// Some answer has not come back yet.
  final bool searching;

  /// Every kind that was asked answered.
  bool get complete => failed.isEmpty;

  /// Everything answered and nothing matched.
  bool get nothingFound =>
      !searching && failed.isEmpty && groups.values.every((g) => g.count == 0);

  /// Nothing answered at all and something failed: the whole search is down.
  bool get allFailed => !searching && groups.isEmpty && failed.isNotEmpty;
}
