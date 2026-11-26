import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Wraps the whole app: a slim strip above [child] while the device has no
/// network. The strip takes the status-bar inset itself and removes it from
/// [child] so content sits below the banner, not under it.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  static const message =
      'You are offline. Saved information is shown where there is any.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final banner = offline
        ? Semantics(
            liveRegion: true,
            container: true,
            child: Material(
              color: AppTheme.darkText,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD,
                    vertical: AppTheme.spacingXS,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Flexible(
                        child: Text(
                          message,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    // Below the banner the status bar is already covered, so the child must
    // not add its own top inset. The wrapper is always present so the child's
    // state survives the banner coming and going.
    final body = MediaQuery.removePadding(
      context: context,
      removeTop: offline,
      child: child,
    );

    return Column(
      children: [
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: SizedBox(width: double.infinity, child: banner),
        ),
        Expanded(child: body),
      ],
    );
  }
}
