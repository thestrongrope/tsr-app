import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/tsr_providers.dart';
import '../widgets/article_card.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Article Detail Screen for TSR Web API articles
/// Displays markdown content from the TSR docs site
class TsrArticleDetailScreen extends ConsumerWidget {
  const TsrArticleDetailScreen({super.key, required this.articleSlug});
  final String articleSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArticle = ref.watch(tsrArticleDetailProvider(articleSlug));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkText),
          onPressed: () => _goBack(context),
        ),
        title: const SizedBox.shrink(),
        actions: [
          asyncArticle.maybeWhen(
            data: (article) => IconButton(
              icon: const Icon(
                Icons.share_outlined,
                size: 24,
                color: AppTheme.darkText,
              ),
              onPressed: () => _shareArticle(article.title, article.slug),
              tooltip: 'Share article',
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: asyncArticle.when(
        data: (article) => _TsrArticleView(
          title: article.title,
          categories: article.categories,
          author: article.author,
          publishedDate: article.publishedDate,
          tags: article.tags,
          content: article.content,
          readingTime: article.readingTime,
          slug: article.slug,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _isGone(e)
            ? const _ArticleGone()
            : AppErrorView(
                error: e,
                onRetry: () =>
                    ref.invalidate(tsrArticleDetailProvider(articleSlug)),
              ),
      ),
    );
  }

  static bool _isGone(Object error) =>
      error is ApiException && error.statusCode == 404;

  /// Back to the page before, or to the Library when this article was opened
  /// by a link and is the only screen.
  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.library);
    }
  }

  void _shareArticle(String title, String slug) {
    // Use SharePlus.instance.share with ShareParams (new API)
    SharePlus.instance.share(
      ShareParams(
        text:
            '$title\n\nRead more at: https://thestrongrope.com/articles/$slug',
      ),
    );
  }
}

/// An article link whose article was removed (#1121): say so, offer the list.
class _ArticleGone extends StatelessWidget {
  const _ArticleGone();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 40, color: AppTheme.mediumText),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'This article is no longer available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.articles),
              child: const Text('See all articles'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TsrArticleView extends StatelessWidget {
  const _TsrArticleView({
    required this.title,
    this.categories = const [],
    this.author,
    this.publishedDate,
    required this.tags,
    required this.content,
    this.readingTime = 5,
    required this.slug,
  });

  final String title;
  final List<String> categories;
  final String? author;
  final String? publishedDate;
  final List<String> tags;
  final String content;
  final int readingTime;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter out "admin" from author display if present
    final showAuthor =
        author != null &&
        author!.isNotEmpty &&
        !author!.toLowerCase().contains('admin');

    return SingleChildScrollView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Chips
          if (categories.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .take(3)
                  .map(
                    (category) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppTheme.darkText,
              fontWeight: FontWeight.bold,
              height: 1.3,
              fontSize: 28, // Matches the reference image style
            ),
          ),
          const SizedBox(height: 16),

          // Metadata Row (Author, Date, Reading Time)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Author (only if not admin)
                if (showAuthor) ...[
                  const CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.primaryGreen,
                    child: Icon(Icons.person, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    author!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.mediumText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],

                // Date
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppTheme.mediumText,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(publishedDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
                const SizedBox(width: 16),

                // Reading Time
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppTheme.mediumText,
                ),
                const SizedBox(width: 6),
                Text(
                  '$readingTime min read',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // HTML Content
          Html(
            data: content.replaceAll(
              RegExp(r'Reading Time:\s*\d+\s*minute(s)?', caseSensitive: false),
              '',
            ),
            style: {
              "body": Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                color: AppTheme.darkText,
                fontSize: FontSize(16.0),
                lineHeight: LineHeight(1.6),
                fontFamily: 'Inter',
              ),
              "p": Style(margin: Margins.only(bottom: 16)),
              "h1": Style(
                fontSize: FontSize(24.0),
                fontWeight: FontWeight.bold,
                margin: Margins.only(top: 24, bottom: 12),
              ),
              "h2": Style(
                fontSize: FontSize(20.0),
                fontWeight: FontWeight.bold,
                margin: Margins.only(top: 24, bottom: 12),
              ),
              "li": Style(margin: Margins.only(bottom: 8)),
              "img": Style(
                width: Width(100, Unit.percent),
                height: Height.auto(),
                margin: Margins.symmetric(vertical: 16),
              ),
              "blockquote": Style(
                margin: Margins.symmetric(horizontal: 0, vertical: 16),
                padding: HtmlPaddings.only(left: 16),
                border: Border(
                  left: BorderSide(color: AppTheme.primaryGreen, width: 4),
                ),
                color: AppTheme.mediumText,
                fontStyle: FontStyle.italic,
              ),
            },
            onLinkTap: (url, context, attributes) async {
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
          const SizedBox(height: 32),

          // Divider
          const Divider(),
          const SizedBox(height: 16),

          // Tags Section
          if (tags.isNotEmpty) ...[
            Text(
              'Tags',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.mediumText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Related Articles
          _RelatedArticlesSection(
            category: categories.isNotEmpty ? categories.first : null,
            currentSlug: slug,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      // Basic check if it matches YYYY-MM-DD to reformat to DD/MM/YYYY
      // If it's already formatted, just return it
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateStr)) {
        final date = DateTime.parse(dateStr);
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }
}

class _RelatedArticlesSection extends ConsumerWidget {
  final String? category;
  final String currentSlug;

  const _RelatedArticlesSection({this.category, required this.currentSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (category == null) return const SizedBox.shrink();

    final articlesAsync = ref.watch(
      tsrArticlesProvider((
        limit: 3,
        offset: 0,
        category: category,
        search: null,
      )),
    );

    return articlesAsync.when(
      data: (response) {
        final articles = response.articles
            .where((a) => a.slug != currentSlug)
            .take(3)
            .toList();

        if (articles.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Related Articles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 16),
            ...articles.map(
              (article) => ArticleCard(
                title: article.title,
                excerpt: article.excerpt,
                date: article.publishedDate ?? '',
                categoryName: category!,
                onTap: () => context.push('/articles/${article.slug}'),
              ),
            ),
            const SizedBox(height: 48),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
