import 'package:flutter/material.dart';

/// Simplified SliverAppBar helper — glass/blur removed.
class GlassSliverAppBar extends StatelessWidget {
  final Widget? leading;
  final List<Widget>? actions;
  final bool isPinned;
  final bool isFloating;
  final VoidCallback? onBackPressed;

  const GlassSliverAppBar({
    super.key,
    this.leading,
    this.actions,
    this.isPinned = true,
    this.isFloating = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: isPinned,
      floating: isFloating,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      leading:
          leading ??
          (onBackPressed != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: onBackPressed,
                )
              : null),
      actions: actions,
    );
  }
}
