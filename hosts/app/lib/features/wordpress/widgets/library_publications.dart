import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../models/publication.dart';
import '../providers/tsr_providers.dart';
import 'publication_cover.dart';

/// The Library's shelf: the newest publications as book cards. "Browse all"
/// opens the complete list, where language filters and search live.
class LibraryPublications extends ConsumerWidget {
  const LibraryPublications({super.key});

  static const int _shownCount = 3;
  static const double _cardWidth = 156;
  static const double _coverHeight = 144;
  static const double _railHeight = 250;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicationsAsync = ref.watch(tsrPublicationsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: AppSectionHeader(
            title: 'Publications',
            actionLabel: 'Browse all',
            onAction: () => context.push(AppRoutes.publications),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        publicationsAsync.when(
          data: (publications) {
            if (publications.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                child: AppEmptySection(
                  icon: Icons.menu_book_outlined,
                  message: 'No publications yet',
                  actionLabel: 'Browse publications',
                  onAction: () => context.push(AppRoutes.publications),
                ),
              );
            }
            final shown = publications.take(_shownCount).toList();
            return SizedBox(
              height: _railHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppTheme.spacingMD),
                itemBuilder: (context, index) =>
                    _PublicationBookCard(publication: shown[index]),
              ),
            );
          },
          loading: () => SizedBox(
            height: _railHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shownCount,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTheme.spacingMD),
              itemBuilder: (context, index) =>
                  const SkeletonBox(width: _cardWidth, height: _railHeight),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: AppErrorView(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(tsrPublicationsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicationBookCard extends StatelessWidget {
  const _PublicationBookCard({required this.publication});

  final Publication publication;

  Future<void> _open(BuildContext context) async {
    final url = publication.primaryUrl;
    if (url == null) {
      AppSnackBar.showInfo(
        context,
        message: 'This publication has no link yet.',
      );
      return;
    }

    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (e) {
      debugPrint('LibraryPublications open error: $e');
    }

    if (!context.mounted) return;
    AppSnackBar.showError(context, message: 'Could not open this publication.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      publication.language,
      publication.type,
    ].whereType<String>().where((detail) => detail.isNotEmpty).join(' · ');

    return SizedBox(
      width: LibraryPublications._cardWidth,
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PublicationCover(
              publication: publication,
              width: double.infinity,
              height: LibraryPublications._coverHeight,
              radius: 0,
              iconSize: 32,
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    publication.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      details,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
