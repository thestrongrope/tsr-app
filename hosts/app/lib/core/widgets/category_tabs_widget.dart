import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class CategoryTabsWidget extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final bool showAllTab;

  const CategoryTabsWidget({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.showAllTab = true,
  });

  @override
  Widget build(BuildContext context) {
    final allCategories = showAllTab ? ['All', ...categories] : categories;

    return DefaultTabController(
      length: allCategories.length,
      initialIndex: showAllTab
          ? (selectedCategory == null
                ? 0
                : allCategories.contains(selectedCategory!)
                ? allCategories.indexOf(selectedCategory!)
                : 0)
          : (selectedCategory == null
                ? 0
                : categories.indexOf(selectedCategory!)),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppTheme.accentGold,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        onTap: (index) {
          if (showAllTab) {
            if (index == 0) {
              onCategorySelected(null); // All selected
            } else {
              onCategorySelected(allCategories[index]);
            }
          } else {
            onCategorySelected(categories[index]);
          }
        },
        tabs: allCategories.map((category) {
          if (category == 'All') {
            return const Tab(text: 'All');
          }

          final categoryInfo = AppConstants.articleCategories[category];
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (categoryInfo != null) ...[
                  Icon(categoryInfo.icon, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(category),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
