import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/html_text.dart';

class ArticleCard extends StatelessWidget {
  final String title;
  final String excerpt;
  final String date;
  final String categoryName;
  final List<String> tags; // Or additional categories
  final bool isBookmarked;
  final VoidCallback? onBookmark; // If null, hide button
  final VoidCallback onTap;
  final String readingTime;

  const ArticleCard({
    super.key,
    required this.title,
    required this.excerpt,
    required this.date,
    required this.categoryName,
    this.tags = const [],
    this.isBookmarked = false,
    this.onBookmark,
    required this.onTap,
    this.readingTime = '5 min read',
  });

  Color _getCategoryColor(String categoryName) {
    return AppConstants.articleCategories[categoryName]?.color ??
        AppTheme.primaryGreen;
  }

  IconData _getCategoryIcon(String categoryName) {
    return AppConstants.articleCategories[categoryName]?.icon ?? Icons.article;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(categoryName);
    final categoryIcon = _getCategoryIcon(categoryName);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Category and Bookmark
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          readingTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onBookmark != null)
                    IconButton(
                      onPressed: onBookmark,
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: AppTheme.primaryGreen,
                      ),
                      iconSize: 20,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              // Summary
              if (excerpt.isNotEmpty)
                Text(
                  htmlToPlainText(excerpt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 16),

              // Tags (if available) or Categories
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (tags.isNotEmpty) const SizedBox(height: 16),

              // Footer Row with Date and Arrow
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ),
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
