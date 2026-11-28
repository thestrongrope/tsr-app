import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../reports/providers/reports_provider.dart' show ReportFormat;
import '../models/access_log.dart';
import '../providers/access_log_provider.dart';

enum _PeopleSort {
  mostHits('Most hits'),
  fewestHits('Fewest hits'),
  latest('Latest access'),
  earliest('Earliest access'),
  name('Name A–Z');

  const _PeopleSort(this.label);
  final String label;
}

enum _PagesSort {
  mostHits('Most hits'),
  fewestHits('Fewest hits'),
  latest('Latest access'),
  earliest('Earliest access'),
  pageAz('Page A–Z'),
  pageZa('Page Z–A');

  const _PagesSort(this.label);
  final String label;
}

enum _RecentSort {
  newest('Newest first'),
  oldest('Oldest first'),
  person('Person'),
  pageAz('Page A–Z'),
  pageZa('Page Z–A');

  const _RecentSort(this.label);
  final String label;
}

/// The admin access log (#419), the mobile counterpart of the web's Admin Access
/// Log: who used the admin pages most, which pages, and the latest accesses, for
/// the last 30 days, filtered by member and by part of a page name, and as a
/// file. Shown to whoever holds `audit-log:read`; the server decides.
///
/// The server filters; sorting is here, because the lists are small.
class AccessLogScreen extends ConsumerStatefulWidget {
  const AccessLogScreen({super.key});

  @override
  ConsumerState<AccessLogScreen> createState() => _AccessLogScreenState();
}

class _AccessLogScreenState extends ConsumerState<AccessLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));
  final _pageField = TextEditingController();

  AccessLogFilter _filter = const AccessLogFilter();

  /// What the member chip says, kept from the row that was tapped.
  String _memberLabel = '';

  _PeopleSort _peopleSort = _PeopleSort.mostHits;
  _PagesSort _pagesSort = _PagesSort.mostHits;
  _RecentSort _recentSort = _RecentSort.newest;
  bool _sharing = false;

  @override
  void dispose() {
    _tabs.dispose();
    _pageField.dispose();
    super.dispose();
  }

  void _filterByMember(AccessLogUser user) {
    setState(() {
      _filter = _filter.copyWith(token: user.token);
      _memberLabel = user.name.isEmpty ? 'Member ${user.token}' : user.name;
    });
  }

  void _filterByPage(String page) {
    _pageField.text = page;
    setState(() => _filter = _filter.copyWith(page: page));
  }

  Future<void> _share(ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareAccessLogProvider)(format, _filter);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'The file could not be prepared. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(accessLogProvider(_filter));
    final hasData = log.asData?.value.isEmpty == false;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Access log'),
        actions: [
          if (hasData) _sortMenu(),
          if (hasData)
            PopupMenuButton<ReportFormat>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: _share,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ReportFormat.xlsx,
                  child: Text('Share as Excel'),
                ),
                PopupMenuItem(
                  value: ReportFormat.pdf,
                  child: Text('Share as PDF'),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Pages'),
            Tab(text: 'Recent'),
          ],
        ),
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: log.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Couldn't load the access log."),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(accessLogProvider(_filter)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) => data.isEmpty
                  ? const Center(child: Text('No accesses match.'))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _people(data.users),
                        _pages(data.pages),
                        _recent(data.recent),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _pageField,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Page contains…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _filter.page.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear page filter',
                      icon: const Icon(Icons.close),
                      onPressed: () => _filterByPage(''),
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) => _filterByPage(value.trim()),
          ),
          if (_filter.token != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InputChip(
                label: Text(_memberLabel),
                deleteButtonTooltipMessage: 'Remove member filter',
                onDeleted: () => setState(
                  () => _filter = _filter.copyWith(clearToken: true),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The sort menu for the tab that is showing.
  Widget _sortMenu() {
    return switch (_tabs.index) {
      0 => PopupMenuButton<_PeopleSort>(
        tooltip: 'Sort',
        icon: const Icon(Icons.sort),
        onSelected: (v) => setState(() => _peopleSort = v),
        itemBuilder: (_) => [
          for (final s in _PeopleSort.values)
            PopupMenuItem(value: s, child: Text(s.label)),
        ],
      ),
      1 => PopupMenuButton<_PagesSort>(
        tooltip: 'Sort',
        icon: const Icon(Icons.sort),
        onSelected: (v) => setState(() => _pagesSort = v),
        itemBuilder: (_) => [
          for (final s in _PagesSort.values)
            PopupMenuItem(value: s, child: Text(s.label)),
        ],
      ),
      _ => PopupMenuButton<_RecentSort>(
        tooltip: 'Sort',
        icon: const Icon(Icons.sort),
        onSelected: (v) => setState(() => _recentSort = v),
        itemBuilder: (_) => [
          for (final s in _RecentSort.values)
            PopupMenuItem(value: s, child: Text(s.label)),
        ],
      ),
    };
  }

  Widget _people(List<AccessLogUser> users) {
    int byHits(AccessLogUser a, AccessLogUser b) => b.hits.compareTo(a.hits);
    int byLast(AccessLogUser a, AccessLogUser b) =>
        b.lastAccessed.compareTo(a.lastAccessed);
    final sorted = [...users]
      ..sort(switch (_peopleSort) {
        _PeopleSort.mostHits => (a, b) => byHits(a, b),
        _PeopleSort.fewestHits => (a, b) => byHits(b, a),
        _PeopleSort.latest => (a, b) => byLast(a, b),
        _PeopleSort.earliest => (a, b) => byLast(b, a),
        _PeopleSort.name => (a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      });

    return ListView(
      children: [
        for (final u in sorted)
          ListTile(
            title: Text(u.name.isEmpty ? 'Member ${u.token}' : u.name),
            subtitle: Text(
              [
                if (u.email.isNotEmpty) u.email,
                '${u.hits} hits',
                '${u.activeDays} days',
                'last ${u.lastAccessed}',
              ].join(' · '),
            ),
            onTap: () => _filterByMember(u),
          ),
      ],
    );
  }

  Widget _pages(List<AccessLogPage> pages) {
    int byHits(AccessLogPage a, AccessLogPage b) => b.hits.compareTo(a.hits);
    int byLast(AccessLogPage a, AccessLogPage b) =>
        b.lastAccessed.compareTo(a.lastAccessed);
    final sorted = [...pages]
      ..sort(switch (_pagesSort) {
        _PagesSort.mostHits => (a, b) => byHits(a, b),
        _PagesSort.fewestHits => (a, b) => byHits(b, a),
        _PagesSort.latest => (a, b) => byLast(a, b),
        _PagesSort.earliest => (a, b) => byLast(b, a),
        _PagesSort.pageAz => (a, b) => a.page.compareTo(b.page),
        _PagesSort.pageZa => (a, b) => b.page.compareTo(a.page),
      });

    return ListView(
      children: [
        for (final p in sorted)
          ListTile(
            title: Text(p.page),
            subtitle: Text('${p.hits} hits · last ${p.lastAccessed}'),
            onTap: () => _filterByPage(p.page),
          ),
      ],
    );
  }

  Widget _recent(List<AccessLogEntry> recent) {
    final sorted = [...recent]
      ..sort(switch (_recentSort) {
        _RecentSort.newest => (a, b) => b.id.compareTo(a.id),
        _RecentSort.oldest => (a, b) => a.id.compareTo(b.id),
        _RecentSort.person => (a, b) {
          final c = a.token.compareTo(b.token);
          return c != 0 ? c : b.id.compareTo(a.id);
        },
        _RecentSort.pageAz => (a, b) => a.page.compareTo(b.page),
        _RecentSort.pageZa => (a, b) => b.page.compareTo(a.page),
      });

    return ListView(
      children: [
        for (final e in sorted)
          ListTile(
            title: Text(e.page),
            subtitle: Text(
              [
                e.accessedAt,
                e.name.isEmpty ? 'Member ${e.token}' : e.name,
                e.role,
                e.method,
                e.ip,
              ].where((part) => part.isNotEmpty).join(' · '),
            ),
          ),
      ],
    );
  }
}
