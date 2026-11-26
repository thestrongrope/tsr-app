import 'package:flutter/material.dart';
// removed unused import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/content_renderer.dart';
import '../../../core/widgets/tab_bar_inset.dart';

class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({super.key, required this.articleId});
  final int articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArticle = ref.watch(articleDetailProvider(articleId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: asyncArticle.when(
        data: (a) => _ArticleView(
          articleId: articleId,
          title: a.title,
          date: a.date,
          content: a.content,
          link: a.link,
        ),
        loading: () => const _ArticleLoadingView(),
        error: (e, st) => _ArticleErrorView(
          onRetry: () => ref.invalidate(articleDetailProvider(articleId)),
        ),
      ),
    );
  }
}

class _ArticleLoadingView extends StatelessWidget {
  const _ArticleLoadingView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppTheme.backgroundLight,
          elevation: 0,
          pinned: true,
          leading: _BackButton(),
        ),
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _ArticleErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ArticleErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppTheme.backgroundLight,
          elevation: 0,
          pinned: true,
          leading: _BackButton(),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
                const SizedBox(height: 16),
                Text(
                  'Failed to load article',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
        onPressed: () => Navigator.of(context).pop(),
        color: AppTheme.darkText,
      ),
    );
  }
}

class _ArticleView extends ConsumerStatefulWidget {
  const _ArticleView({
    required this.articleId,
    required this.title,
    required this.date,
    required this.content,
    required this.link,
  });

  final int articleId;
  final String title;
  final DateTime date;
  final String content;
  final String link;

  @override
  ConsumerState<_ArticleView> createState() => _ArticleViewState();
}

class _ArticleViewState extends ConsumerState<_ArticleView> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > 50; // Threshold
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBookmarked = ref.watch(isBookmarkedProvider(widget.articleId));

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // AppBar matching All Articles style: transparent, dark icons, no glass
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.darkText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Bookmark button
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: isBookmarked ? AppTheme.primaryGreen : AppTheme.darkText,
              ),
              onPressed: () => _toggleBookmark(ref),
            ),
            // Link button
            IconButton(
              icon: const Icon(
                Icons.open_in_new,
                size: 20,
                color: AppTheme.darkText,
              ),
              onPressed: () => launchUrlString(
                widget.link,
                mode: LaunchMode.externalApplication,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        // Article Content
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with gradient accent
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.withValues(alpha: 0.08),
                        AppTheme.primaryGreen.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and reading time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat.yMMMd().format(widget.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: AppTheme.mediumText,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _calculateReadingTime(widget.content),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.mediumText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Article content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: ContentRenderer(htmlContent: widget.content),
                ),
              ],
            ),
          ),
        ),
        const TabBarInsetSliver(),
      ],
    );
  }

  String _calculateReadingTime(String content) {
    // Strip HTML tags for word count
    final text = content.replaceAll(RegExp(r'<[^>]*>'), '');
    final wordCount = text.split(RegExp(r'\s+')).length;
    final minutes = (wordCount / 200).ceil(); // Average reading speed
    return '$minutes min read';
  }

  Future<void> _toggleBookmark(WidgetRef ref) async {
    final bookmarkService = ref.read(bookmarkServiceProvider);
    final isBookmarked = ref.read(isBookmarkedProvider(widget.articleId));

    if (isBookmarked) {
      await bookmarkService.removeBookmark(widget.articleId);
    } else {
      // Create a minimal article object for bookmarking
      final article = await ref.read(
        articleDetailProvider(widget.articleId).future,
      );
      await bookmarkService.addBookmark(article, ['General']);
    }

    ref.read(isBookmarkedProvider(widget.articleId).notifier).state =
        !isBookmarked;
    ref.invalidate(bookmarksProvider);
  }
}
