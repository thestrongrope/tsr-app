import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/html_text.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../wordpress/providers/tsr_providers.dart';
import '../../../wordpress/models/tsr_article.dart';
import '../../../../core/widgets/widgets.dart';

class LatestArticles extends ConsumerWidget {
  const LatestArticles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (limit: 5, offset: 0, category: null, search: null);
    final articlesAsync = ref.watch(tsrArticlesProvider(args));
    final isEmpty = articlesAsync.asData?.value.articles.isEmpty ?? false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: AppSectionHeader(
            title: 'Latest Articles',
            actionLabel: 'View all',
            onAction: () => context.push('/articles'),
          ),
        ),
        const SizedBox(height: 12),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: AppEmptySection(
              icon: Icons.article_outlined,
              message: 'No articles yet',
              actionLabel: 'Browse articles',
              onAction: () => context.push('/articles'),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: articlesAsync.when(
              data: (response) => ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: response.articles.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) =>
                    _ArticleCard(article: response.articles[index]),
              ),
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) =>
                    const SkeletonBox(width: 280, height: 220),
              ),
              error: (error, stack) => AppErrorView(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(tsrArticlesProvider(args)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final TsrArticle article;

  const _ArticleCard({required this.article});

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '';
    }

    try {
      // Parse the date string (it might be in ISO format or other formats)
      final dateTime = DateTime.parse(dateString);
      // Format it as "MMM d, yyyy" (e.g., "Jan 24, 2026")
      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) {
      // If parsing fails, return the original string or empty
      return dateString.split(' ').first; // Try to extract just the date part
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/articles/${article.slug}'),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categories
            if (article.categories.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  article.categories.first,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Title
            Text(
              article.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Excerpt
            if (article.excerpt.isNotEmpty)
              Expanded(
                child: Text(
                  htmlToPlainText(article.excerpt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Date
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppTheme.mediumText,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(article.publishedDate),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
