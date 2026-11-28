import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_config.dart';

/// Keeps the screen the app is on under a guide link that arrives while the
/// app is open (#1138). The operating system hands the router a new location,
/// which replaces the screens; a guide should open on top of them, so that
/// going back returns to where the member was.
///
/// Wired as the router's `onEnter`. A link that starts the app, or arrives
/// while the app is still on its splash, sign-in or registration screens, is
/// let through: there is nothing under it to keep, and the redirect that
/// follows signs the member in and brings them back to it.
class GuideLinkEntry {
  /// True between blocking a guide link and the push that replaces it, so the
  /// push itself is let through instead of being blocked again.
  bool _pushing = false;

  static const _entryScreens = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.profileCompletion,
  };

  OnEnterResult call(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    GoRouter router,
  ) {
    if (!AppRoutes.isGuideLink(next.uri.path)) return const Allow();
    if (_pushing) {
      _pushing = false;
      return const Allow();
    }
    // The first location of a run has no screen before it: the router then
    // reports it as both the current and the next.
    if (current.uri == next.uri) return const Allow();
    if (_entryScreens.contains(current.matchedLocation)) return const Allow();

    _pushing = true;
    return Block.then(() => router.push(next.uri.toString()));
  }
}
