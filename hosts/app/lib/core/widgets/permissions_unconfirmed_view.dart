import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/permissions_provider.dart';
import '../theme/app_theme.dart';

/// What a signed-in member sees while the app has no answer yet on what they
/// may do: a spinner while it asks, then Retry if it could not. The app never
/// builds its tabs from a guess.
class PermissionsUnconfirmedView extends ConsumerWidget {
  const PermissionsUnconfirmedView({super.key, this.foreground});

  /// Text and spinner colour; the theme's medium text by default.
  final Color? foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(permissionsProvider).isLoading;
    final color = foreground ?? AppTheme.mediumText;

    if (loading) {
      return Center(child: CircularProgressIndicator(color: color));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We could not check what you can access.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextButton(
              onPressed: () =>
                  ref.read(permissionsProvider.notifier).fetchAndSave(),
              child: Text('Retry', style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
