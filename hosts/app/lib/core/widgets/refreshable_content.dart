import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_snackbar.dart';

/// Generic pull-to-refresh wrapper that can be used with any scrollable content
class RefreshableContent extends ConsumerWidget {
  const RefreshableContent({
    super.key,
    required this.onRefresh,
    required this.child,
    this.backgroundColor,
    this.displacement = 40.0,
    this.strokeWidth = 2.0,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
  });

  /// Function to call when refresh is triggered
  final Future<void> Function() onRefresh;

  /// The scrollable content to wrap
  final Widget child;

  /// Background color of the refresh indicator
  final Color? backgroundColor;

  /// Distance from top where refresh indicator appears
  final double displacement;

  /// Width of the refresh indicator stroke
  final double strokeWidth;

  /// When to trigger the refresh
  final RefreshIndicatorTriggerMode triggerMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      backgroundColor: backgroundColor ?? Theme.of(context).cardColor,
      displacement: displacement,
      strokeWidth: strokeWidth,
      triggerMode: triggerMode,
      child: child,
    );
  }
}

/// Custom refresh indicator with TSR branding
class TSRRefreshIndicator extends StatelessWidget {
  const TSRRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.showRefreshIcon = true,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool showRefreshIcon;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      color: Theme.of(context).primaryColor,
      displacement: 60.0,
      strokeWidth: 3.0,
      child: child,
    );
  }
}

/// Mixin to add refresh functionality to any ConsumerWidget
mixin RefreshableMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Override this to implement custom refresh logic
  Future<void> onRefresh() async {
    // Default implementation - override in concrete classes
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Show refresh success message
  void showRefreshSuccess([String? message]) {
    if (!mounted) return;
    AppSnackBar.showSuccess(
      context,
      message: message ?? 'Content refreshed successfully',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show refresh error message
  void showRefreshError([String? message]) {
    if (!mounted) return;
    AppSnackBar.showError(
      context,
      message: message ?? 'Failed to refresh content',
      duration: const Duration(seconds: 3),
    );
  }
}
