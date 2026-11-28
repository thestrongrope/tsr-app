import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/route_config.dart';
import '../theme/app_theme.dart';
import 'release_notes.dart';
import '../../core/widgets/tab_bar_inset.dart';

/// "Version 1.1.0 (16)", or just "Version" while the number is unreadable.
String _versionLabel(InstalledVersion? installed) => installed == null
    ? 'Version'
    : 'Version ${installed.version} (${installed.build})';

/// The installed version in the Me tab, for members and guests alike. Tapping
/// it opens the release notes.
class AppVersionTile extends ConsumerWidget {
  const AppVersionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedVersionProvider).asData?.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
        title: Text(_versionLabel(installed)),
        subtitle: const Text("See what's new"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push(AppRoutes.releaseNotes),
      ),
    );
  }
}

/// Every release's version, date and notes, newest first, with the member's
/// own version marked.
class ReleaseNotesScreen extends ConsumerWidget {
  const ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedVersionProvider).asData?.value;
    final releases = ref.watch(releaseNotesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Release notes')),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _versionLabel(installed),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...releases.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The release notes could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(releaseNotesProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: (list) => list.isEmpty
                ? [const Text('No release notes yet.')]
                : [
                    for (final release in list)
                      _ReleaseCard(
                        release: release,
                        isInstalled:
                            installed != null &&
                            release.isInstalled(installed.version),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.isInstalled});

  final Release release;
  final bool isInstalled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  release.version,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isInstalled) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Your version'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            if (release.date.isNotEmpty)
              Text(
                release.date,
                style: textTheme.bodySmall?.copyWith(
                  color: AppTheme.mediumText,
                ),
              ),
            const SizedBox(height: 8),
            for (final note in release.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(note)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
