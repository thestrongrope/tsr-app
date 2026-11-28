import 'package:flutter/foundation.dart';
import 'package:riverpod/legacy.dart';

/// Provider to store the intended destination when an unauthenticated user
/// tries to access a protected route.
///
/// Flow:
/// 1. User opens deep link to `/profile/edit` (protected)
/// 2. Auth guard saves `/profile/edit` to this provider
/// 3. User is redirected to `/login`
/// 4. After successful login, router checks this provider
/// 5. If set, redirects to stored path and clears the provider
///
/// This enables the "redirect back to intended destination" pattern.
final pendingDeepLinkProvider =
    StateNotifierProvider<PendingDeepLinkNotifier, String?>((ref) {
      return PendingDeepLinkNotifier();
    });

class PendingDeepLinkNotifier extends StateNotifier<String?> {
  PendingDeepLinkNotifier() : super(null);

  /// Store a pending deep link path.
  void setPendingLink(String path) {
    debugPrint('🔗 Storing pending deep link: $path');
    state = path;
  }

  /// Get the pending deep link without consuming it.
  /// Use this in redirect logic to avoid state mutation during build.
  String? get pendingLink => state;

  /// Consume and clear the pending deep link.
  /// Returns the stored path if any, then clears it.
  /// IMPORTANT: Do not call this during widget build phase!
  /// Use after navigation completes.
  String? consumePendingLink() {
    final pending = state;
    if (pending != null) {
      debugPrint('🔗 Consuming pending deep link: $pending');
      // Delay state modification to avoid build-phase mutation error
      Future(() {
        state = null;
      });
    }
    return pending;
  }

  /// Clear any pending deep link without returning it.
  void clear() {
    if (state != null) {
      debugPrint('🔗 Clearing pending deep link: $state');
      // Delay state modification to avoid build-phase mutation error
      Future(() {
        state = null;
      });
    }
  }
}
