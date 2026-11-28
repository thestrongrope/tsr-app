import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class SocialAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const SocialAuthButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.isLoading = false,
    this.height,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // This widget switches between the icon and a loading indicator.
    final iconWidget = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : icon;

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: iconWidget,
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        // Colors
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        // Let the button handle its own disabled state colors automatically.
        // Or you can be explicit like this:
        // disabledBackgroundColor: backgroundColor.withOpacity(0.5),
        // disabledForegroundColor: foregroundColor.withOpacity(0.5),

        // Shadow
        shadowColor: onPressed != null && !isLoading
            ? backgroundColor.withValues(alpha: 0.3)
            : Colors.transparent,
        elevation: onPressed != null && !isLoading ? 8 : 0,

        // Sizing and Shape
        minimumSize: Size.fromHeight(height ?? AppConstants.buttonHeight),
        padding:
            padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppConstants.defaultBorderRadius,
          ),
        ),
      ),
    );
  }

  // --- Factory Constructors for common button types ---

  factory SocialAuthButton.google({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return SocialAuthButton(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata_rounded, size: 28), // Simplified icon
      label: label,
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }

  factory SocialAuthButton.apple({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return SocialAuthButton(
      onPressed: onPressed,
      icon: const Icon(Icons.apple, size: 22), // Simplified icon
      label: label,
      backgroundColor: AppTheme.darkText,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }
}
