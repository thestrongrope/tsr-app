import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A modern information card with a title and list of key-value items.
/// Used for displaying class schedules, details, etc.
/// Styled with Container, soft shadow, and AppTheme.radius2XL (24) to match
/// the PerformanceOverview and QuickAction cards across the dashboard.
/// With an [onTap] the card shows a chevron; without one it looks inert.
class InfoCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<InfoItem> items;
  final VoidCallback? onTap;
  final Widget? trailing;

  const InfoCard({
    super.key,
    required this.title,
    this.icon,
    required this.items,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius2XL),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.cardPaddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: AppTheme.primaryGreen, size: 24),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: AppTheme.darkText,
                            ),
                      ),
                    ),
                    ?trailing,
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.mediumText,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...items.asMap().entries.map((entry) {
                  final isLast = entry.key == items.length - 1;
                  return _InfoItemWidget(item: entry.value, isLast: isLast);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single info item to be displayed in an InfoCard
class InfoItem {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const InfoItem({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });
}

class _InfoItemWidget extends StatelessWidget {
  final InfoItem item;
  final bool isLast;

  const _InfoItemWidget({required this.item, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 18, color: AppTheme.mediumText),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: item.icon != null ? 80 : 100,
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.mediumText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: item.valueColor ?? AppTheme.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
