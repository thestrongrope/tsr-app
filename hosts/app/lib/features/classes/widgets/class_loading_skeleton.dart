import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The shape of a class screen while it loads: a heading block and a few
/// rows, so the page does not jump when the content arrives.
class ClassLoadingSkeleton extends StatelessWidget {
  const ClassLoadingSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: withTabBarInset(
          context,
          const EdgeInsets.all(AppTheme.spacingLG),
        ),
        children: [
          const SkeletonBox(height: 96),
          for (var i = 0; i < rows; i++) ...[
            const SizedBox(height: AppTheme.spacingMD),
            const SkeletonBox(height: 56, radius: 12),
          ],
        ],
      ),
    );
  }
}
