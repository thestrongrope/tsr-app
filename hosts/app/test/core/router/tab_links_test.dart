import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/services/action_link.dart';
import 'package:the_strong_rope/core/widgets/bottom_nav_scaffold.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

// The tab shell with the Library and Me branches shaped as app_router.dart
// declares them: the pages a link opens (/videos, /articles, /publications,
// /notifications, /profile) are siblings of the tab's starting screen, not
// children of it. The real route tree cannot be built in a test (it needs the
// network), so this mirrors its shape.

class _Member extends PermissionsNotifier {
  _Member() {
    state = const PermissionsState(payload: PermissionsPayload.member());
  }
}

GoRouter _router() {
  GoRoute page(String path) =>
      GoRoute(path: path, builder: (_, _) => Text('page $path'));

  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => BottomNavScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [page('/home')]),
          StatefulShellBranch(
            routes: [
              page('/library'),
              page('/articles'),
              page('/videos'),
              page('/publications'),
            ],
          ),
          StatefulShellBranch(routes: [page('/classes')]),
          StatefulShellBranch(routes: [page('/admin')]),
          StatefulShellBranch(
            routes: [page('/me'), page('/profile'), page('/notifications')],
          ),
        ],
      ),
    ],
  );
}

void main() {
  for (final link in [
    '/videos',
    '/articles',
    '/publications',
    '/notifications',
    '/profile',
  ]) {
    testWidgets('a link to $link shows it with the tab bar', (tester) async {
      final router = _router();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWithValue(0),
            permissionsProvider.overrideWith((ref) => _Member()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('page /home'));
      await openActionLink(context, link);
      await tester.pumpAndSettle();

      expect(find.text('page $link'), findsOneWidget);
      expect(find.byType(GlassBottomNavBar), findsOneWidget);

      // The member can leave through the bar, and tapping the open tab goes
      // back to its starting screen.
      final onLibrary = link != '/profile' && link != '/notifications';
      final tab = onLibrary ? 'Library' : 'Me';
      final start = onLibrary ? '/library' : '/me';
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('page $start'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('page /home'), findsOneWidget);
    });
  }
}
