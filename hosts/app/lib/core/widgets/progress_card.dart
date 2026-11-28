import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A card showing progress items with linear indicators.
/// Used for syllabus progress, course completion, etc.
class ProgressCard extends StatelessWidget {
  final String title;
  final List<ProgressItem> items;
  final VoidCallback? onViewAll;
  final int maxItems;

  const ProgressCard({
    super.key,
    required this.title,
    required this.items,
    this.onViewAll,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...items
                .take(maxItems)
                .map((item) => _ProgressItemWidget(item: item)),
          ],
        ),
      ),
    );
  }
}

/// A single progress item
class ProgressItem {
  final String title;
  final double progress; // 0.0 to 1.0
  final Color? color;
  final String? subtitle;

  const ProgressItem({
    required this.title,
    required this.progress,
    this.color,
    this.subtitle,
  });
}

class _ProgressItemWidget extends StatelessWidget {
  final ProgressItem item;

  const _ProgressItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? AppTheme.primaryGreen;
    final percentage = (item.progress * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.lightText,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: item.progress,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
