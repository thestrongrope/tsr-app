import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/permissions/capabilities.dart';
import '../../../../core/permissions/capabilities_home.dart';
import '../../../../core/router/route_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reports/providers/reports_provider.dart';

/// A coordinator's way into the weekly review (#615): how many classes need
/// attention this week, and a tap to the This week screen in Manage. Shown only
/// to whoever holds `reports:read`, and not at all while the review loads or
/// when it cannot: Home must never be the place a failed report shows up.
class ThisWeekCard extends ConsumerWidget {
  const ThisWeekCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capabilitiesProvider).mayOpenThisWeek) {
      return const SizedBox.shrink();
    }
    final flagged = ref
        .watch(thisWeekProvider(null))
        .asData
        ?.value
        .summary
        .flagged;
    if (flagged == null) return const SizedBox.shrink();

    final label = switch (flagged) {
      0 => 'This week: all clear',
      1 => 'This week: 1 class needs attention',
      _ => 'This week: $flagged classes need attention',
    };
    final needsAttention = flagged > 0;
    final colour = needsAttention
        ? AppTheme.warningStrong
        : AppTheme.successGreen;
    // While classes need attention this is the attention banner: a tinted
    // fill, a coloured rim, an alert icon and the count, so it reads as a
    // notice and not as one more navigation row.
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.screenPadding,
        right: AppTheme.screenPadding,
        top: AppTheme.spacingMD,
      ),
      child: Material(
        color: colour.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          side: BorderSide(color: colour, width: needsAttention ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(
            needsAttention
                ? Icons.notification_important_rounded
                : Icons.task_alt_rounded,
            color: colour,
          ),
          title: Text(
            label,
            style: const TextStyle(
              color: AppTheme.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.adminThisWeek),
        ),
      ),
    );
  }
}
