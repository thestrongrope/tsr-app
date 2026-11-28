import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class AppSnackBar {
  static void showComingSoon(
    BuildContext context, {
    String? message,
    Color? backgroundColor,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message ?? 'Coming Soon!',
      backgroundColor: backgroundColor ?? AppTheme.darkText,
      icon: Icons.construction_rounded,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: AppTheme.errorRed,
      icon: Icons.error_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: AppTheme.successGreen,
      icon: Icons.check_circle_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: AppTheme.primaryGreen,
      icon: Icons.info_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: AppTheme.warningOrange,
      icon: Icons.warning_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    Duration? duration,
  }) {
    // Safety check: only show snackbar if context is still mounted
    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    // Clear any existing snackbars
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        // Explicitly allow auto-dismiss after [duration]. Flutter's SnackBar
        // defaults `persist` to true whenever an action is present, which would
        // otherwise keep the snackbar on screen forever.
        persist: false,
        duration: duration ?? const Duration(seconds: 3),
        margin: const EdgeInsets.all(AppConstants.defaultPadding),
        elevation: 4,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white70,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }
}
