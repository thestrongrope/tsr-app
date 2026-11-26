import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/html_text.dart';

import 'package:riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/tsr_article.dart';
import '../providers/tsr_providers.dart';
import '../services/tsr_web_service.dart';
import '../services/content_cache_service.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// State notifier for managing articles list with pagination
class AllArticlesNotifier extends StateNotifier<AllArticlesState> {
  AllArticlesNotifier(this._service, this._cacheService)
    : super(const AllArticlesState());

  final TsrWebService _service;
  final ContentCacheService _cacheService;
  static const int _pageSize = 20;

  Future<void> loadArticles({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (refresh) {
      state = state.copyWith(
        articles: [],
        offset: 0,
        hasMore: true,
        error: null,
      );
    }

    // Try to load from cache first (only for first page without filters)
    if (state.offset == 0 && !state.hasActiveFilters) {
      final cached = await _cacheService.getCachedArticles('all');
      if (cached != null && cached.isNotEmpty && !refresh) {
        state = state.copyWith(
          articles: cached,
          offset: cached.length,
          hasMore: cached.length >= _pageSize,
          isLoading: false,
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Convert multi-select to comma-separated string for API
      final categoryParam = state.selectedCategories.isNotEmpty
          ? state.selectedCategories.join(',')
          : null;
      final tagParam = state.selectedTags.isNotEmpty
          ? state.selectedTags.join(',')
          : null;

      final response = await _service.getArticles(
        limit: _pageSize,
        offset: state.offset,
        category: categoryParam,
        tag: tagParam,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      );

      final newArticles = [...state.articles, ...response.articles];
      state = state.copyWith(
        articles: newArticles,
        offset: state.offset + response.articles.length,
        hasMore: response.pagination.hasMore,
        isLoading: false,
      );

      // Cache the first page of unfiltered results
      if (state.offset == response.articles.length && !state.hasActiveFilters) {
        await _cacheService.cacheArticles('all', newArticles);
        // Lazy-cache top article details for offline reading
        unawaited(
          _cacheService.prefetchArticleDetails(
            newArticles,
            fetchDetail: _service.getArticle,
          ),
        );
      }
    } catch (e) {
      // On error, try to load from cache as fallback
      if (state.articles.isEmpty) {
        final cached = await _cacheService.getCachedArticles('all');
        if (cached != null && cached.isNotEmpty) {
          state = state.copyWith(
            articles: cached,
            offset: cached.length,
            hasMore: false,
            isLoading: false,
            error: e,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery != query) {
      state = state.copyWith(
        searchQuery: query,
        articles: [],
        offset: 0,
        hasMore: true,
      );
      loadArticles();
    }
  }

  void setCategories(List<String> categories) {
    if (!_listEquals(state.selectedCategories, categories)) {
      state = state.copyWith(
        selectedCategories: categories,
        articles: [],
        offset: 0,
        hasMore: true,
      );
      loadArticles();
    }
  }

  void toggleCategory(String category) {
    final current = List<String>.from(state.selectedCategories);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    setCategories(current);
  }

  void setTags(List<String> tags) {
    if (!_listEquals(state.selectedTags, tags)) {
      state = state.copyWith(
        selectedTags: tags,
        articles: [],
        offset: 0,
        hasMore: true,
      );
      loadArticles();
    }
  }

  void toggleTag(String tag) {
    final current = List<String>.from(state.selectedTags);
    if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.add(tag);
    }
    setTags(current);
  }

  void clearFilters() {
    state = const AllArticlesState();
    loadArticles();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class AllArticlesState {
  final List<TsrArticle> articles;
  final bool isLoading;
  final Object? error;
  final int offset;
  final bool hasMore;
  final String searchQuery;
  final List<String> selectedCategories;
  final List<String> selectedTags;

  const AllArticlesState({
    this.articles = const [],
    this.isLoading = false,
    this.error,
    this.offset = 0,
    this.hasMore = true,
    this.searchQuery = '',
    this.selectedCategories = const [],
    this.selectedTags = const [],
  });

  AllArticlesState copyWith({
    List<TsrArticle>? articles,
    bool? isLoading,
    Object? error,
    int? offset,
    bool? hasMore,
    String? searchQuery,
    List<String>? selectedCategories,
    List<String>? selectedTags,
  }) {
    return AllArticlesState(
      articles: articles ?? this.articles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedCategories.isNotEmpty ||
      selectedTags.isNotEmpty;
}

final allArticlesProvider =
    StateNotifierProvider<AllArticlesNotifier, AllArticlesState>((ref) {
      final service = ref.watch(tsrWebServiceProvider);
      final cacheService = ref.watch(contentCacheServiceProvider);
      return AllArticlesNotifier(service, cacheService);
    });

class AllArticlesScreen extends ConsumerStatefulWidget {
  const AllArticlesScreen({super.key});

  @override
  ConsumerState<AllArticlesScreen> createState() => _AllArticlesScreenState();
}

class _AllArticlesScreenState extends ConsumerState<AllArticlesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allArticlesProvider.notifier).loadArticles();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(allArticlesProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(allArticlesProvider.notifier).loadArticles();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allArticlesProvider);
    final categoriesAsync = ref.watch(tsrCategoriesProvider);

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          leadingWidth: 56,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.darkText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Articles',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              Text(
                'Explore Islamic knowledge',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
            ],
          ),
          actions: [
            if (state.hasActiveFilters)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.filter_alt_off,
                    size: 20,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                onPressed: () {
                  _searchController.clear();
                  ref.read(allArticlesProvider.notifier).clearFilters();
                },
                tooltip: 'Clear filters',
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Search and Filter Section
            Container(
              color: AppTheme.backgroundLight,
              // Reduced bottom padding to tighten gap between chips and the list
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search articles...',
                        hintStyle: TextStyle(color: AppTheme.lightText),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppTheme.mediumText,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppTheme.mediumText,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(allArticlesProvider.notifier)
                                      .setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (value) {
                        ref
                            .read(allArticlesProvider.notifier)
                            .setSearchQuery(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SizedBox(
                    height: 50,
                    child: categoriesAsync.when(
                      data: (categories) => ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: categories.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isSelected = state.selectedCategories.isEmpty;
                            return ChoiceChip(
                              label: const Text('All'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  ref
                                      .read(allArticlesProvider.notifier)
                                      .setCategories([]);
                                }
                              },
                              selectedColor: AppTheme.primaryGreen,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.darkText,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXL,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : AppTheme.dividerColor,
                                ),
                              ),
                              showCheckmark: false,
                            );
                          }
                          final category = categories[index - 1];
                          final isSelected = state.selectedCategories.contains(
                            category.slug,
                          );
                          return ChoiceChip(
                            label: Text(category.title),
                            selected: isSelected,
                            onSelected: (selected) {
                              ref
                                  .read(allArticlesProvider.notifier)
                                  .setCategories(
                                    selected ? [category.slug] : [],
                                  );
                            },
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.darkText,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : AppTheme.dividerColor,
                              ),
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            // Articles List
            Expanded(
              child: state.error != null && state.articles.isEmpty
                  ? AppErrorView(error: state.error!, onRetry: _retry)
                  : state.articles.isEmpty && !state.isLoading
                  ? _buildEmptyView()
                  : _withSavedCopyNotice(
                      state.error,
                      RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(allArticlesProvider.notifier)
                              .loadArticles(refresh: true);
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          // Slightly reduced top padding to bring list closer to chips
                          padding: withTabBarInset(
                            context,
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          ),
                          itemCount:
                              state.articles.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.articles.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _ArticleListTile(
                              article: state.articles[index],
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _retry() =>
      ref.read(allArticlesProvider.notifier).loadArticles(refresh: true);

  /// The saved copy stays on screen; the plain message and Retry sit under it.
  Widget _withSavedCopyNotice(Object? error, Widget list) {
    if (error == null) return list;
    return Column(
      children: [
        Expanded(child: list),
        AppErrorView(error: error, onRetry: _retry, compact: true),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: AppTheme.mediumText),
          const SizedBox(height: 16),
          Text(
            'No articles found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }
}

/// Multi-select bottom sheet
class _MultiSelectBottomSheet extends StatefulWidget {
  final String label;
  final List<String> selectedValues;
  final List<(String, String)> items;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectBottomSheet({
    required this.label,
    required this.selectedValues,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_MultiSelectBottomSheet> createState() =>
      _MultiSelectBottomSheetState();
}

class _MultiSelectBottomSheetState extends State<_MultiSelectBottomSheet> {
  late List<String> _selectedValues;

  @override
  void initState() {
    super.initState();
    _selectedValues = List.from(widget.selectedValues);
  }

  void _toggleItem(String value) {
    setState(() {
      if (_selectedValues.contains(value)) {
        _selectedValues.remove(value);
      } else {
        _selectedValues.add(value);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedValues.clear();
    });
  }

  void _applySelection() {
    Navigator.pop(context);
    widget.onChanged(_selectedValues);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select ${widget.label}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      if (_selectedValues.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_selectedValues.length} selected',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.primaryGreen),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedValues.isNotEmpty)
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(
                      'Clear all',
                      style: TextStyle(color: AppTheme.primaryGreen),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Options list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = _selectedValues.contains(item.$1);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.dividerColor,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    item.$2,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.darkText,
                    ),
                  ),
                  onTap: () => _toggleItem(item.$1),
                );
              },
            ),
          ),
          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applySelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedValues.isEmpty
                      ? 'Show all'
                      : 'Apply (${_selectedValues.length} selected)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleListTile extends StatelessWidget {
  final TsrArticle article;

  const _ArticleListTile({required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      elevation: 0,
      child: InkWell(
        onTap: () => context.push('/articles/${article.slug}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories
              if (article.categories.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: article.categories
                      .take(2)
                      .map(
                        (cat) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSM,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (article.categories.isNotEmpty) const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              // Excerpt
              if (article.excerpt.isNotEmpty)
                Text(
                  htmlToPlainText(article.excerpt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),
              // Meta info
              Row(
                children: [
                  if (article.author != null) ...[
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.lightText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      article.author!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.schedule, size: 14, color: AppTheme.lightText),
                  const SizedBox(width: 4),
                  Text(
                    '${article.readingTime} min read',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.lightText),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.lightText,
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
