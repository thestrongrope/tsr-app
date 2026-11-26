import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/route_config.dart';
import '../../wordpress/services/tsr_web_service.dart';
import '../models/search_result.dart';

/// The answer of `GET /search` (#557): what the server found among the private
/// kinds, and which kinds it could not search.
class PrivateSearch {
  const PrivateSearch({required this.groups, required this.unavailable});

  final Map<SearchKind, SearchGroup> groups;
  final Set<SearchKind> unavailable;

  /// The private kinds and the server's name for each.
  static const _kinds = {
    'class': SearchKind.classRecord,
    'teacher': SearchKind.teacher,
    'guide': SearchKind.guide,
    'student': SearchKind.student,
    'subscriber': SearchKind.subscriber,
  };

  /// The card or screen a result of [kind] opens, from its id.
  static String _target(SearchKind kind, int id) => switch (kind) {
    SearchKind.classRecord => AppRoutes.classDashboardDetail.replaceFirst(
      ':classId',
      '$id',
    ),
    SearchKind.teacher => AppRoutes.adminTeacherPath(id),
    // A guide result's id is a class of that level the person reaches.
    SearchKind.guide => AppRoutes.classGuide.replaceFirst(':classId', '$id'),
    SearchKind.student => AppRoutes.studentCardPath(id),
    SearchKind.subscriber => AppRoutes.subscriberCardPath(id),
    _ => '',
  };

  /// Throws [FormatException] when [body] is not a search answer.
  factory PrivateSearch.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['groups'] is! List) {
      throw const FormatException('search: unexpected response');
    }
    final groups = <SearchKind, SearchGroup>{};
    for (final g in body['groups'] as List) {
      if (g is! Map<String, dynamic>) continue;
      final kind = _kinds[g['kind']];
      if (kind == null) continue;
      final results = [
        for (final r in g['results'] as List? ?? const [])
          if (r is Map<String, dynamic>)
            SearchResult(
              kind: kind,
              id: (r['id'] as num?)?.toInt() ?? 0,
              title: r['title'] as String? ?? '',
              subtitle: r['subtitle'] as String? ?? '',
              target: _target(kind, (r['id'] as num?)?.toInt() ?? 0),
            ),
      ];
      groups[kind] = SearchGroup(
        kind: kind,
        results: results,
        count: (g['count'] as num?)?.toInt() ?? results.length,
        capped: g['capped'] as bool? ?? false,
      );
    }
    return PrivateSearch(
      groups: groups,
      unavailable: {
        for (final k in body['unavailable'] as List? ?? const [])
          if (_kinds[k] != null) _kinds[k]!,
      },
    );
  }
}

/// The lookups behind global search (#557): the website for articles, videos and
/// publications, our own API for the private kinds. Each call asks one source
/// and fails alone.
class SearchRepository {
  SearchRepository({TsrWebService? web, ApiClient? api})
    : _web = web,
      _api = api;

  final TsrWebService? _web;
  final ApiClient? _api;

  TsrWebService get _site => _web ?? TsrWebService();
  ApiClient get _client => _api ?? ApiClient();

  Future<SearchGroup> articles(String query) async {
    final found = await _site.searchArticles(query: query, limit: 20);
    final results = [
      for (final a in found.results)
        SearchResult(
          kind: SearchKind.article,
          id: a.id,
          title: a.title,
          subtitle: a.excerpt.trim(),
          target: '/home/articles/detail/${a.slug}',
        ),
    ];
    return SearchGroup(
      kind: SearchKind.article,
      results: results,
      count: found.total > results.length ? found.total : results.length,
    );
  }

  Future<SearchGroup> videos(String query) async {
    final found = await _site.searchLectures(query: query, limit: 20);
    final results = [
      for (final l in found.results)
        SearchResult(
          kind: SearchKind.video,
          id: 0,
          title: l.title,
          subtitle: l.matchedChapters.isNotEmpty
              ? l.matchedChapters.first.title
              : '',
          target: l.openUrl,
        ),
    ];
    return SearchGroup(
      kind: SearchKind.video,
      results: results,
      count: found.total > results.length ? found.total : results.length,
    );
  }

  /// The website sends every publication in one short list, so this filters it
  /// here, by title and summary.
  Future<SearchGroup> publications(String query) async {
    final needle = query.trim().toLowerCase();
    final all = await _site.getPublications();
    final results = [
      for (final p in all)
        if (p.primaryUrl != null &&
            (p.title.toLowerCase().contains(needle) ||
                (p.summary ?? '').toLowerCase().contains(needle)))
          SearchResult(
            kind: SearchKind.publication,
            id: 0,
            title: p.title,
            subtitle: p.language ?? '',
            target: p.primaryUrl!,
          ),
    ];
    return SearchGroup(
      kind: SearchKind.publication,
      results: results,
      count: results.length,
    );
  }

  Future<PrivateSearch> privateSearch(String query) async {
    final body = await _client.get<dynamic>(
      AppConstants.searchEndpoint,
      queryParameters: {'q': query},
    );
    return PrivateSearch.fromJson(body);
  }
}
