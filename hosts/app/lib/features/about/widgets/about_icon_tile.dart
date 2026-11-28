import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A rounded square holding an icon, the lead of the About screens' cards.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.size = defaultSize,
    this.background = AppTheme.lightGreen,
    this.foreground = AppTheme.primaryGreen,
  });

  static const double defaultSize = 40;
  static const double largeSize = 56;

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Icon(icon, color: foreground, size: size * 0.5),
    );
  }
}
