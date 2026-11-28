import 'package:flutter/material.dart';
// removed unused import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/category_tabs_widget.dart';
import '../widgets/article_card.dart';

import '../models/article.dart';
import '../providers/providers.dart';
import '../../../core/widgets/tab_bar_inset.dart';

class ArticlesListScreen extends ConsumerStatefulWidget {
  const ArticlesListScreen({super.key});

  @override
  ConsumerState<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends ConsumerState<ArticlesListScreen> {
  final _scrollController = ScrollController();
  int _page = 1;
  final int _perPage = 10;
  final List<Article> _articles = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final selected = ref.read(selectedCategoryProvider);
    final q = ref.read(searchQueryProvider);
    setState(() => _isLoadingMore = true);
    final result = await ref
        .read(
          articlesProvider((
            page: _page + 1,
            perPage: _perPage,
            categoryId: selected,
            q: q,
          )).future,
        )
        .catchError((_) => <Article>[]);
    if (!mounted) return;
    setState(() {
      _page += 1;
      _hasMore = result.isNotEmpty;
      _articles.addAll(result);
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedCategoryProvider);
    final q = ref.watch(searchQueryProvider);

    final asyncArticles = ref.watch(
      articlesProvider((
        page: 1,
        perPage: _perPage,
        categoryId: selected,
        q: q,
      )),
    );
    final asyncCategories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles'),
        automaticallyImplyLeading: false, // Remove back button
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final text = await showSearch<String?>(
                context: context,
                delegate: _ArticlesSearchDelegate(initial: q),
              );
              if (text != null) {
                ref.read(searchQueryProvider.notifier).state = text;
              }
            },
          ),
        ],
        bottom: asyncCategories.when(
          data: (categories) => PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: CategoryTabsWidget(
              categories: categories.map((c) => c.name).toList(),
              selectedCategory: selected != null
                  ? categories
                        .firstWhere(
                          (c) => c.id == selected,
                          orElse: () => categories.first,
                        )
                        .name
                  : null,
              onCategorySelected: (categoryName) {
                if (categoryName == null) {
                  ref.read(selectedCategoryProvider.notifier).state = null;
                } else {
                  final category = categories.firstWhere(
                    (c) => c.name == categoryName,
                  );
                  ref.read(selectedCategoryProvider.notifier).state =
                      category.id;
                }
                setState(() {
                  _page = 1;
                  _articles.clear();
                  _hasMore = true;
                });
              },
            ),
          ),
          loading: () => const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, st) => const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: SizedBox(height: 48),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _page = 1;
            _articles.clear();
            _hasMore = true;
          });
          ref.invalidate(
            articlesProvider((
              page: 1,
              perPage: _perPage,
              categoryId: selected,
              q: q,
            )),
          );
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header Section
            asyncCategories.when(
              data: (categories) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected == null
                                ? 'Latest Articles'
                                : '${categories.firstWhere((c) => c.id == selected, orElse: () => categories.first).name} Articles',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          asyncArticles.when(
                            data: (articles) => Text(
                              '${articles.length} articles available',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.mediumText),
                            ),
                            loading: () => Text(
                              'Loading articles...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.mediumText),
                            ),
                            error: (e, st) => Text(
                              'Error loading articles',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (e, st) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            asyncArticles.when(
              data: (articles) {
                final List<Article> list = _articles.isEmpty
                    ? articles
                    : [...articles, ..._articles];
                return SliverPadding(
                  padding: withTabBarInset(
                    context,
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  sliver: SliverList.builder(
                    itemCount: list.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= list.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final a = list[i];
                      return _ArticleCard(
                        article: a,
                        onTap: () =>
                            context.push('/home/articles/detail/${a.id}'),
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
                child: Center(child: Text('Failed to load articles')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends ConsumerWidget {
  const _ArticleCard({required this.article, required this.onTap});
  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat.yMMMd().format(article.date);
    final bookmarkService = ref.read(bookmarkServiceProvider);
    final isBookmarked = ref.watch(isBookmarkedProvider(article.id));
    final asyncCategories = ref.watch(categoriesProvider);

    return asyncCategories.when(
      data: (categories) {
        final categoryName = article.categories.isNotEmpty
            ? categories
                  .firstWhere(
                    (c) => article.categories.contains(c.id),
                    orElse: () => categories.first,
                  )
                  .name
            : 'General';

        final tagNames = article.categories.isNotEmpty
            ? categories
                  .where((c) => article.categories.contains(c.id))
                  .map((c) => c.name)
                  .take(3)
                  .toList()
            : <String>[];

        return ArticleCard(
          title: article.title,
          excerpt: article.excerpt,
          date: date,
          categoryName: categoryName,
          tags: tagNames,
          isBookmarked: isBookmarked,
          onTap: onTap,
          onBookmark: () async {
            if (isBookmarked) {
              await bookmarkService.removeBookmark(article.id);
            } else {
              await bookmarkService.addBookmark(article, [categoryName]);
            }
            ref.read(isBookmarkedProvider(article.id).notifier).state =
                !isBookmarked;
            ref.invalidate(bookmarksProvider);
          },
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _ArticlesSearchDelegate extends SearchDelegate<String?> {
  _ArticlesSearchDelegate({String? initial}) {
    query = initial ?? '';
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
  Widget buildSuggestions(BuildContext context) => const SizedBox.shrink();
}
