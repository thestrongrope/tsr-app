import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Account deletion, grouped and labelled rather than left as a loose link.
///
/// Required in-app by App Store Review Guideline 5.1.1(v), so it has to be
/// findable. It stays visually subordinate to Sign Out — no filled background,
/// and set apart from the buttons above rather than mixed in with them.
///
/// Giving it this much weight is safe because the control does not delete
/// anything: it routes to a screen that explains the terms and asks for
/// confirmation. The copy here says so, and deliberately does not repeat the
/// 60-day detail that the delete screen already covers.
class DangerZone extends StatelessWidget {
  const DangerZone({super.key, required this.onDelete});

  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.25),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.errorRed,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Request deletion of your account and the personal data attached '
            'to it. Nothing is deleted until you confirm on the next screen.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorRed,
                size: 20,
              ),
              label: const Text(
                'Delete my account',
                style: TextStyle(
                  color: AppTheme.errorRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
