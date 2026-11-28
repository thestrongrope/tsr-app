import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/widgets/bottom_nav_scaffold.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

/// Starts with no answer; each fetch waits on [answer] so a test can look at
/// the loading state before it settles.
class _FirstLaunch extends PermissionsNotifier {
  _FirstLaunch(this.answer) {
    state = const PermissionsState(unconfirmed: true);
  }

  final Future<Map<String, dynamic>> Function() answer;
  int fetches = 0;

  @override
  Future<void> fetchAndSave() async {
    fetches++;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final json = await answer();
      state = PermissionsState(payload: PermissionsPayload.fromJson(json));
    } catch (e) {
      state = PermissionsState(unconfirmed: true, error: e.toString());
    }
  }
}

GoRouter _router() => GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          BottomNavScaffold(navigationShell: shell),
      branches: [
        for (final name in ['home', 'library', 'classes', 'manage', 'me'])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: name == 'home' ? '/' : '/$name',
                builder: (_, _) => Text('$name screen'),
              ),
            ],
          ),
      ],
    ),
  ],
);

void main() {
  testWidgets('first launch: loading, then Retry, never a tab bar', (
    tester,
  ) async {
    var attempt = 0;
    final failure = Completer<void>();
    final notifier = _FirstLaunch(() async {
      attempt++;
      if (attempt == 1) {
        await failure.future;
        throw Exception('offline');
      }
      return {
        'version': 5,
        'permissions': <String>[],
        'revision': 'aaaaaaaaaaaaaaaa',
        'navigation': {'classes': false, 'manage': false},
      };
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadNotificationCountProvider.overrideWithValue(0),
          permissionsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );

    unawaited(notifier.fetchAndSave());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GlassBottomNavBar), findsNothing);

    failure.complete();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(GlassBottomNavBar), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(notifier.fetches, 2);
    expect(find.byType(GlassBottomNavBar), findsOneWidget);
  });
}
