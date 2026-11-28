import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/home_header.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

// Search from Home (#557): one entry for everyone, signed in or not.

Widget _wrap({dynamic user}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [unreadNotificationCountProvider.overrideWithValue(0)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: HomeHeader(currentUser: user)),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, _) => const Scaffold(body: Text('search screen')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('the header offers search to someone signed out', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search'), findsOneWidget);
  });

  testWidgets('and to someone signed in', (tester) async {
    await tester.pumpWidget(_wrap(user: const _Named('Ali')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('tapping it opens the search screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('search screen'), findsOneWidget);
  });

  test('the search route is open to someone who is not signed in', () {
    expect(AppRoutes.isPublicRoute(AppRoutes.search), isTrue);
    expect(AppRoutes.search, '/search');
  });
}

/// The header reads only `name` from the user.
class _Named {
  const _Named(this.name);
  final String name;
}
