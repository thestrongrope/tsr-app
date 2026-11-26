import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/publication.dart';
import '../providers/tsr_providers.dart';
import '../widgets/publication_cover.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Opens [uri] outside the app; true when the phone took it.
typedef OpenUrl = Future<bool> Function(Uri uri);

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Every TSR publication, read outside the app: a tap hands the reading page
/// or the file to the phone's browser or PDF viewer.
class PublicationsListScreen extends ConsumerStatefulWidget {
  const PublicationsListScreen({super.key, this.openUrl = _openExternally});

  final OpenUrl openUrl;

  @override
  ConsumerState<PublicationsListScreen> createState() =>
      _PublicationsListScreenState();
}

class _PublicationsListScreenState
    extends ConsumerState<PublicationsListScreen> {
  /// The chosen language; null is "All".
  String? _language;

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final publications = ref.watch(tsrPublicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publications'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.darkText,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
        child: publications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorView(),
          data: _buildList,
        ),
      ),
    );
  }

  Widget _buildList(List<Publication> all) {
    final languages = _languagesOf(all);
    // A language that vanished on refresh falls back to "All".
    final selected = languages.contains(_language) ? _language : null;
    final query = _search.text.trim().toLowerCase();
    final shown = all.where((p) {
      if (selected != null && p.language != selected) return false;
      if (query.isEmpty) return true;
      return p.title.toLowerCase().contains(query) ||
          (p.summary ?? '').toLowerCase().contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        // A failure shows as the provider's error state; swallow it here so
        // it does not also escape as an uncaught (Crashlytics-fatal) error.
        try {
          ref.invalidate(tsrPublicationsProvider);
          await ref.read(tsrPublicationsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search publications',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => setState(() => _language = null),
              ),
              for (final language in languages)
                ChoiceChip(
                  label: Text(language),
                  selected: selected == language,
                  onSelected: (_) => setState(() => _language = language),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  query.isEmpty
                      ? 'No publications yet.'
                      : 'No publications match your search.',
                ),
              ),
            ),
          for (final p in shown)
            _PublicationCard(publication: p, onOpen: _open),
        ],
      ),
    );
  }

  /// The languages present, English first and the rest alphabetical, as the
  /// website's publications page orders them.
  List<String> _languagesOf(List<Publication> all) {
    final languages = all
        .map((p) => p.language)
        .whereType<String>()
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    languages.sort((a, b) {
      if (a == 'English') return -1;
      if (b == 'English') return 1;
      return a.compareTo(b);
    });
    return languages;
  }

  Future<void> _open(String? url) async {
    var opened = false;
    if (url != null) {
      try {
        opened = await widget.openUrl(Uri.parse(url));
      } catch (e) {
        debugPrint('🔴 PublicationsListScreen open error: $e');
      }
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this publication.')),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Could not load publications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(tsrPublicationsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({required this.publication, required this.onOpen});

  final Publication publication;
  final Future<void> Function(String? url) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = publication;
    final textTheme = Theme.of(context).textTheme;
    final details = [
      p.language,
      p.type,
      p.displaySize,
      if (p.updated != null) 'Updated ${p.updated}',
    ].whereType<String>().where((d) => d.isNotEmpty).join(' · ');
    final secondary = p.secondaryUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: AppSurfaceCard(
        onTap: () => onOpen(p.primaryUrl),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PublicationCover(publication: p),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (p.summary != null && p.summary!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      p.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      details,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                  if (secondary != null)
                    TextButton.icon(
                      onPressed: () => onOpen(secondary),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text('Open ${p.type ?? 'file'}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
