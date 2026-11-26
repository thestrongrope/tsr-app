import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/permissions_provider.dart';
import '../theme/app_theme.dart';

/// A strip with Retry, shown while what the app knows about the member's access
/// is the last answer the server gave and the latest check failed. Nothing
/// while the copy is confirmed.
class PermissionsStaleNotice extends ConsumerWidget {
  const PermissionsStaleNotice({super.key});

  static const message = 'What you can see may be out of date.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionsProvider);
    if (!state.stale) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: AppTheme.darkText,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingXS,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: state.isLoading
                    ? null
                    : () =>
                          ref.read(permissionsProvider.notifier).fetchAndSave(),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
