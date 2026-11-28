import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/user_message.dart';

/// A failed screen or section: what went wrong in plain words, and Retry
/// when it can be tried again (#720). [error] is the caught object; the
/// words come from [userMessage], so a raw exception never reaches the
/// member.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;

  /// Reloads whatever failed. Without it there is no button.
  final VoidCallback? onRetry;

  /// For a short strip on a busy screen: the message and Retry, no icon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = Text(
      userMessage(error),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
    );

    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              message,
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppTheme.errorRed),
            const SizedBox(height: AppTheme.spacingMD),
            message,
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingMD),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
