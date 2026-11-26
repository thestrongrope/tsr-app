import 'package:flutter/widgets.dart';

import '../models/recent_action.dart';

/// Reports each whitelisted screen the member opens. It only maps a route to a
/// [RecentActionKind]; who is signed in and what is stored are the callback's
/// business. A navigator takes one observer instance, so make one per navigator.
class RecentActionsObserver extends NavigatorObserver {
  RecentActionsObserver(this._onOpened);

  final void Function(RecentActionKind kind, int? classId) _onOpened;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _report(newRoute);
  }

  void _report(Route<dynamic> route) {
    final action = recentActionForRoute(
      route.settings.name,
      route.settings.arguments,
    );
    if (action != null) _onOpened(action.kind, action.classId);
  }
}
