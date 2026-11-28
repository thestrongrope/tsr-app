import 'package:hive_ce/hive.dart';
import '../../../core/constants/app_constants.dart';
import '../models/bookmark.dart';
import '../models/article.dart';

class BookmarkService {
  static const String _boxName = AppConstants.bookmarksBoxKey;

  /// Get the bookmarks box
  Box get _box => Hive.box(_boxName);

  /// Check if an article is bookmarked
  bool isBookmarked(int articleId) {
    return _box.values.cast<Bookmark>().any(
      (bookmark) => bookmark.articleId == articleId,
    );
  }

  /// Add an article to bookmarks
  Future<void> addBookmark(Article article, List<String> categoryNames) async {
    // Remove existing bookmark if any
    await removeBookmark(article.id);

    final bookmark = Bookmark(
      articleId: article.id,
      title: article.title,
      excerpt: article.excerpt,
      featuredImageUrl: article.featuredImageUrl,
      bookmarkedAt: DateTime.now(),
      categories: categoryNames,
    );

    await _box.add(bookmark);
  }

  /// Remove an article from bookmarks
  Future<void> removeBookmark(int articleId) async {
    final existingKey = _box.keys.cast<dynamic>().firstWhere(
      (key) => (_box.get(key) as Bookmark).articleId == articleId,
      orElse: () => null,
    );

    if (existingKey != null) {
      await _box.delete(existingKey);
    }
  }

  /// Get all bookmarks
  List<Bookmark> getAllBookmarks() {
    return _box.values.cast<Bookmark>().toList()
      ..sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
  }

  /// Get bookmarks count
  int getBookmarksCount() {
    return _box.length;
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    await _box.clear();
  }
}
