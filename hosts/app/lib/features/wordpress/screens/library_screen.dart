import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/tsr_providers.dart';
import '../widgets/library_latest_articles.dart';
import '../widgets/library_publications.dart';
import '../widgets/library_video_hero.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The Library tab's starting screen: the latest articles, a featured video
/// and the publications, with a shortcut to each full list.
///
/// Each section loads on its own, so a slow or failed request never hides the
/// rest of the library.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with RefreshableMixin {
  @override
  Future<void> onRefresh() async {
    try {
      await Future.wait([
        ref.refresh(tsrYouTubeProvider(LibraryVideoHero.videosArgs).future),
        ref.refresh(
          tsrArticlesProvider(LibraryLatestArticles.articlesArgs).future,
        ),
        ref.refresh(tsrPublicationsProvider.future),
      ]);
      showRefreshSuccess('Library refreshed');
    } catch (e) {
      debugPrint('Library refresh failed: $e');
      showRefreshError('Failed to refresh the library');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
      child: Column(
        children: [
          const _LibraryHeader(),
          Expanded(
            child: RefreshableContent(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const _LibraryShortcuts(),
                        const SizedBox(height: AppTheme.sectionSpacing),
                        const LibraryLatestArticles(),
                        const SizedBox(height: AppTheme.sectionSpacing),
                        const LibraryVideoHero(),
                        const SizedBox(height: AppTheme.sectionSpacing),
                        const LibraryPublications(),
                        // Clear the floating tab bar.
                        SizedBox(height: withTabBarInset(context).bottom),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      color: AppTheme.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Library',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.darkText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              'Articles, lectures and books',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three ways into the full lists, so a member who knows what they want
/// does not have to scroll the feed.
class _LibraryShortcuts extends StatelessWidget {
  const _LibraryShortcuts();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spacingMD,
      ),
      child: Row(
        children: [
          ActionChip(
            key: const ValueKey('libraryShortcut:articles'),
            avatar: const Icon(Icons.article_rounded, size: 18),
            label: const Text('Articles'),
            onPressed: () => context.push(AppRoutes.articles),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          ActionChip(
            key: const ValueKey('libraryShortcut:videos'),
            avatar: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text('Videos'),
            onPressed: () => context.push(AppRoutes.videos),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          ActionChip(
            key: const ValueKey('libraryShortcut:publications'),
            avatar: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Publications'),
            onPressed: () => context.push(AppRoutes.publications),
          ),
        ],
      ),
    );
  }
}
