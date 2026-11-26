import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';
import 'repository_provider.dart';

final selectedCategoryProvider = StateProvider<int?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// Categories are cached for longer - keepAlive to avoid refetching
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.read(wpRepositoryProvider);
  return repo.getCategories();
});

// Articles use autoDispose since they depend on filters
final articlesProvider = FutureProvider.autoDispose
    .family<
      List<Article>,
      ({int page, int perPage, int? categoryId, String? q})
    >((ref, args) async {
      final repo = ref.read(wpRepositoryProvider);
      return repo.getArticles(
        page: args.page,
        perPage: args.perPage,
        categoryId: args.categoryId,
        q: args.q,
      );
    });

final articleDetailProvider = FutureProvider.family<Article, int>((
  ref,
  id,
) async {
  final repo = ref.read(wpRepositoryProvider);
  return repo.getArticle(id);
});

// Offline providers
final offlineArticlesProvider = FutureProvider<List<Article>>((ref) async {
  final repo = ref.read(wpRepositoryProvider);
  return repo.getOfflineArticles();
});

final isOfflineSavedProvider = FutureProvider.family<bool, int>((ref, id) {
  final repo = ref.read(wpRepositoryProvider);
  return repo.isOfflineSaved(id);
});

// Bookmark providers
final bookmarkServiceProvider = Provider<BookmarkService>((ref) {
  return BookmarkService();
});

final isBookmarkedProvider = StateProvider.family<bool, int>((ref, articleId) {
  final bookmarkService = ref.read(bookmarkServiceProvider);
  return bookmarkService.isBookmarked(articleId);
});

final bookmarksProvider = StateProvider<List<Bookmark>>((ref) {
  final bookmarkService = ref.read(bookmarkServiceProvider);
  return bookmarkService.getAllBookmarks();
});
