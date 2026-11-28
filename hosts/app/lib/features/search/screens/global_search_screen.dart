import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/search_result.dart';
import '../providers/search_provider.dart';

/// One search for everything (#557): articles, videos and publications from the
/// website, classes, teachers, guides, students and subscribers from our own
/// server for whoever may see them, and the screens and reports of the app.
///
/// Results are grouped by kind, each group with how many it found. A kind that
/// could not be searched is named and the rest still show, never presented as
/// the whole answer.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  static const _debounce = Duration(milliseconds: 350);
  static const _shown = 5;

  /// The order groups appear in, and the name each goes by.
  static const _order = [
    (SearchKind.destination, 'Screens and reports'),
    (SearchKind.classRecord, 'Classes'),
    (SearchKind.student, 'Students'),
    (SearchKind.teacher, 'Teachers'),
    (SearchKind.guide, 'Guides'),
    (SearchKind.subscriber, 'Subscribers'),
    (SearchKind.article, 'Articles'),
    (SearchKind.video, 'Videos'),
    (SearchKind.publication, 'Publications'),
  ];

  final _controller = TextEditingController();
  Timer? _timer;
  String _query = '';
  final _expanded = <SearchKind>{};

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) {
        setState(() {
          _query = text.trim();
          _expanded.clear();
        });
      }
    });
  }

  void _retry() {
    ref.invalidate(searchArticlesProvider(_query));
    ref.invalidate(searchVideosProvider(_query));
    ref.invalidate(searchPublicationsProvider(_query));
    ref.invalidate(searchPrivateProvider(_query));
  }

  /// "Videos", "Teachers and Students", "A, B and C".
  static String _names(Iterable<SearchKind> kinds) {
    final names = [
      for (final o in _order)
        if (kinds.contains(o.$1)) o.$2,
    ];
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(globalSearchProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search TSR',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _query.length < 2
            ? const [Text('Type at least two letters to search')]
            : _body(view),
      ),
    );
  }

  List<Widget> _body(GlobalSearchView view) {
    if (view.allFailed) {
      return [
        const Text('The search could not be done.'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: _retry,
            child: const Text('Try again'),
          ),
        ),
      ];
    }

    return [
      if (view.failed.isNotEmpty) ...[
        Text(
          '${_names(view.failed)} could not be searched, so these results may be incomplete.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _retry, child: const Text('Try again')),
        ),
        const SizedBox(height: 8),
      ],
      if (view.searching)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Searching…'),
            ],
          ),
        ),
      for (final (kind, name) in _order)
        if (view.groups[kind] case final group? when group.results.isNotEmpty)
          ..._group(kind, name, group),
      if (view.nothingFound) const Text('Nothing found'),
    ];
  }

  List<Widget> _group(SearchKind kind, String name, SearchGroup group) {
    final open = ref.read(searchOpenProvider);
    final showAll = _expanded.contains(kind) || group.results.length <= _shown;
    final results = showAll
        ? group.results
        : group.results.take(_shown).toList();

    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          '$name (${group.count}${group.capped ? '+' : ''})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final result in results)
        Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            title: Text(result.title),
            subtitle: result.subtitle.isEmpty
                ? null
                : Text(
                    result.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => open(context, result),
          ),
        ),
      if (!showAll)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded.add(kind)),
            child: Text('Show all ${group.results.length}'),
          ),
        ),
    ];
  }
}
