import 'package:hive_ce/hive.dart';

part 'bookmark.g.dart';

@HiveType(typeId: 2)
class Bookmark extends HiveObject {
  @HiveField(0)
  int articleId;

  @HiveField(1)
  String title;

  @HiveField(2)
  String excerpt;

  @HiveField(3)
  String? featuredImageUrl;

  @HiveField(4)
  DateTime bookmarkedAt;

  @HiveField(5)
  List<String> categories;

  Bookmark({
    required this.articleId,
    required this.title,
    required this.excerpt,
    this.featuredImageUrl,
    required this.bookmarkedAt,
    required this.categories,
  });
}
