import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/html_text.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../utils/video_utils.dart';
import '../models/tsr_article.dart';
import '../providers/tsr_providers.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Content Hub Screen - Replaces Articles Screen
/// Includes Articles from TSR Web API and YouTube videos
class ContentHubScreen extends ConsumerStatefulWidget {
  const ContentHubScreen({super.key});

  @override
  ConsumerState<ContentHubScreen> createState() => _ContentHubScreenState();
}

class _ContentHubScreenState extends ConsumerState<ContentHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _articlesScrollController = ScrollController();

  // Pagination state
  int _articlesOffset = 0;
  final int _articlesLimit = 20;
  final List<TsrArticle> _allArticles = [];
  bool _isLoadingMore = false;
  bool _hasMoreArticles = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _articlesScrollController.addListener(_onArticlesScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _articlesScrollController.dispose();
    super.dispose();
  }

  void _onArticlesScroll() {
    if (!_hasMoreArticles || _isLoadingMore) return;
    if (_articlesScrollController.position.pixels >=
        _articlesScrollController.position.maxScrollExtent - 300) {
      _loadMoreArticles();
    }
  }

  Future<void> _loadMoreArticles() async {
    final selectedCategory = ref.read(selectedTsrCategoryProvider);
    final searchQuery = ref.read(tsrSearchQueryProvider);

    setState(() => _isLoadingMore = true);

    try {
      final result = await ref.read(
        tsrArticlesProvider((
          limit: _articlesLimit,
          offset: _articlesOffset + _articlesLimit,
          category: selectedCategory,
          search: searchQuery.isNotEmpty ? searchQuery : null,
        )).future,
      );

      if (!mounted) return;
      setState(() {
        _articlesOffset += _articlesLimit;
        _hasMoreArticles = result.pagination.hasMore;
        _allArticles.addAll(result.articles);
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _resetPagination() {
    setState(() {
      _articlesOffset = 0;
      _allArticles.clear();
      _hasMoreArticles = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Knowledge Hub'),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.article_outlined), text: 'Articles'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Videos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildArticlesTab(), _buildYouTubeTab()],
      ),
    );
  }

  Widget _buildArticlesTab() {
    final selectedCategory = ref.watch(selectedTsrCategoryProvider);
    final searchQuery = ref.watch(tsrSearchQueryProvider);

    final asyncArticles = ref.watch(
      tsrArticlesProvider((
        limit: _articlesLimit,
        offset: 0,
        category: selectedCategory,
        search: searchQuery.isNotEmpty ? searchQuery : null,
      )),
    );

    final asyncCategories = ref.watch(tsrCategoriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        _resetPagination();
        ref.invalidate(tsrArticlesProvider);
        ref.invalidate(tsrCategoriesProvider);
      },
      child: CustomScrollView(
        controller: _articlesScrollController,
        slivers: [
          // Category Filter Chips
          asyncCategories.when(
            data: (categories) => SliverToBoxAdapter(
              child: _buildCategoryChips(categories, selectedCategory),
            ),
            loading: () =>
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
            error: (e, st) =>
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ),

          // Search Query Display
          if (searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Results for "$searchQuery"',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(tsrSearchQueryProvider.notifier).state = '';
                        _resetPagination();
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),

          // Articles List
          asyncArticles.when(
            data: (response) {
              final articles = _allArticles.isEmpty
                  ? response.articles
                  : [...response.articles, ..._allArticles];

              if (articles.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState('No articles found'),
                );
              }

              return SliverPadding(
                padding: withTabBarInset(context, const EdgeInsets.all(16)),
                sliver: SliverList.builder(
                  itemCount: articles.length + (_hasMoreArticles ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= articles.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _TsrArticleCard(
                      article: articles[index],
                      onTap: () => context.push(
                        '/home/articles/detail/${articles[index].slug}',
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState('Failed to load articles', () {
                ref.invalidate(tsrArticlesProvider);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<TsrCategory> categories, String? selected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // All Categories chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (isSelected) {
                ref.read(selectedTsrCategoryProvider.notifier).state = null;
                _resetPagination();
              },
              selectedColor: AppTheme.lightGreen,
              checkmarkColor: AppTheme.primaryGreen,
            ),
          ),
          // Category chips
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category.title),
                selected: selected == category.slug,
                onSelected: (isSelected) {
                  ref.read(selectedTsrCategoryProvider.notifier).state =
                      isSelected ? category.slug : null;
                  _resetPagination();
                },
                selectedColor: AppTheme.lightGreen,
                checkmarkColor: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubeTab() {
    final asyncVideos = ref.watch(tsrYouTubeProvider((limit: 20, offset: 0)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tsrYouTubeProvider);
      },
      child: asyncVideos.when(
        data: (response) {
          if (response.videos.isEmpty) {
            return _buildEmptyState('No videos available');
          }

          return ListView.builder(
            padding: withTabBarInset(context, const EdgeInsets.all(16)),
            itemCount: response.videos.length,
            itemBuilder: (context, index) {
              final video = response.videos[index];
              return _YouTubeVideoCard(
                video: video,
                onTap: () => openTsrVideo(context, video),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _buildErrorState('Failed to load videos', () {
          ref.invalidate(tsrYouTubeProvider);
        }),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) async {
    final query = await showSearch<String?>(
      context: context,
      delegate: _ContentSearchDelegate(
        initialQuery: ref.read(tsrSearchQueryProvider),
      ),
    );
    if (query != null) {
      ref.read(tsrSearchQueryProvider.notifier).state = query;
      _resetPagination();
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppTheme.mediumText),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.mediumText),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Article Card for TSR Web API articles
class _TsrArticleCard extends StatelessWidget {
  const _TsrArticleCard({required this.article, required this.onTap});

  final TsrArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category and Featured Badge
              Row(
                children: [
                  if (article.categories.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Text(
                        article.categories.first,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (article.featured) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Featured',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                article.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Excerpt
              Text(
                htmlToPlainText(article.excerpt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mediumText,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Tags
              if (article.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: article.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (article.tags.isNotEmpty) const SizedBox(height: 12),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (article.author != null)
                    Text(
                      'By ${article.author}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.mediumText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// YouTube Video Card
class _YouTubeVideoCard extends StatelessWidget {
  const _YouTubeVideoCard({required this.video, required this.onTap});

  final TsrYouTubeVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (video.thumbnail != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLG),
                ),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: video.thumbnail!.url,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(height: 180, color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.play_circle_filled,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (video.intro != null)
                    Text(
                      video.intro!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppTheme.mediumText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        video.publishedDateFormatted ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                      if (video.views != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppTheme.mediumText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatViews(video.views!)} views',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }
}

/// Search Delegate for content
class _ContentSearchDelegate extends SearchDelegate<String?> {
  _ContentSearchDelegate({String? initialQuery}) {
    query = initialQuery ?? '';
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () => close(context, query),
      child: const Text('Search'),
    ),
  );

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.search),
          title: Text('Search for "$query"'),
          onTap: () => close(context, query),
        ),
      ],
    );
  }
}
