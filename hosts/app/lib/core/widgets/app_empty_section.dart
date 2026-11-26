import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_card.dart';

/// What a content section shows when it has nothing yet: an icon, a short
/// message and one action link to the screen that fills it.
class AppEmptySection extends StatelessWidget {
  const AppEmptySection({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;

  /// The action link; both or neither. Leave them out when no screen the
  /// member can reach fills this section.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(AppTheme.spacing2XL),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 36, color: AppTheme.accentGold),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkText,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
