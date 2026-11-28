import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/recent_actions_provider.dart';

/// The screens this member opens most, a tap from Home (#726). Hidden when
/// there is nothing valid to show, which is also the case for a guest: the
/// list fills itself from what the member opens, so there is no screen to link
/// to from an empty state.
class JumpBackInCard extends ConsumerWidget {
  const JumpBackInCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(jumpBackItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.screenPadding,
        right: AppTheme.screenPadding,
        top: AppTheme.spacingMD,
      ),
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Jump back in',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final item in items)
              ListTile(
                dense: true,
                leading: Icon(item.icon),
                title: Text(item.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(item.path),
              ),
          ],
        ),
      ),
    );
  }
}
