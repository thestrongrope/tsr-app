import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../models/tsr_article.dart';
import '../providers/tsr_providers.dart';

/// The Library's article feed: the newest few articles as cards. "View all"
/// opens the complete article list.
class LibraryLatestArticles extends ConsumerWidget {
  const LibraryLatestArticles({super.key});

  static const ({int limit, int offset, String? category, String? search})
  articlesArgs = (limit: 5, offset: 0, category: null, search: null);

  static const int _shownCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(tsrArticlesProvider(articlesArgs));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: AppSectionHeader(
            title: 'Latest Articles',
            actionLabel: 'View all',
            onAction: () => context.push(AppRoutes.articles),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: articlesAsync.when(
            data: (response) {
              final shown = response.articles.take(_shownCount).toList();
              if (shown.isEmpty) {
                return AppEmptySection(
                  icon: Icons.article_outlined,
                  message: 'No articles yet',
                  actionLabel: 'Browse articles',
                  onAction: () => context.push(AppRoutes.articles),
                );
              }
              return Column(
                children: [
                  for (final article in shown) ...[
                    _ArticleCard(article: article),
                    if (article != shown.last)
                      const SizedBox(height: AppTheme.spacingMD),
                  ],
                ],
              );
            },
            loading: () => const Column(
              children: [
                SkeletonBox(height: 110),
                SizedBox(height: AppTheme.spacingMD),
                SkeletonBox(height: 110),
              ],
            ),
            error: (error, stack) => AppErrorView(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(tsrArticlesProvider(articlesArgs)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final TsrArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _formatDate(article.publishedDate);
    final meta = [
      if (date.isNotEmpty) date,
      '${article.readingTime} min read',
    ].join(' · ');

    return SizedBox(
      width: double.infinity,
      child: AppSurfaceCard(
        onTap: () => context.push(
          AppRoutes.articleDetail.replaceFirst(':slug', article.slug),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.categories.isNotEmpty) ...[
              Text(
                article.categories.first,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacingXS),
            ],
            Text(
              article.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.darkText,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mediumText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.split(' ').first;
  return DateFormat('MMM d, yyyy').format(parsed);
}
