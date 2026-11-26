import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final EdgeInsetsGeometry? padding;

  const CustomBackButton({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back_ios_new),
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.white,
        foregroundColor: iconColor ?? AppTheme.darkText,
        padding: padding ?? const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        elevation: 2,
        shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
      ),
      iconSize: size ?? 20,
    );
  }
}
