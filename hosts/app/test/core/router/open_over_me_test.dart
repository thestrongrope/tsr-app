import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/search/models/search_result.dart';
import 'package:the_strong_rope/features/search/providers/search_provider.dart';

// #1178 finding 1: a Me result opened when the router is already on /me.
// Mirrors push_shell_route_from_root_test.dart, including the onEnter hook.

SearchResult _result(String target) => SearchResult(
  kind: SearchKind.classRecord,
  id: 1,
  title: 'x',
  subtitle: '',
  target: target,
);

class _Harness {
  late GoRouter router;
  late BuildContext searchContext;
  late BuildContext meContext;
  late WidgetRef ref;
}

GoRouter _router(String initial, _Harness h) => GoRouter(
  initialLocation: initial,
  onEnter: (_, _, _, _) => const Allow(),
  redirect: (_, _) => null,
  routes: [
    GoRoute(
      path: '/search',
      builder: (_, _) => Consumer(
        builder: (context, ref, _) {
          h.searchContext = context;
          h.ref = ref;
          return const Text('search');
        },
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => Scaffold(body: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/me',
              builder: (_, _) => Consumer(
                builder: (context, ref, _) {
                  h.meContext = context;
                  h.ref = ref;
                  return const Text('me');
                },
              ),
            ),
            GoRoute(
              path: '/send-feedback',
              builder: (_, _) => const Text('feedback'),
            ),
          ],
        ),
      ],
    ),
  ],
);

Future<_Harness> _start(WidgetTester tester, String initial) async {
  final h = _Harness();
  h.router = _router(initial, h);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: h.router)),
  );
  await tester.pumpAndSettle();
  return h;
}

/// A later `go('/me')` must not push anything: a lingering listener would.
Future<void> _expectNoLingeringListener(WidgetTester tester, _Harness h) async {
  h.router.go('/home');
  await tester.pumpAndSettle();
  h.router.go('/me');
  await tester.pumpAndSettle();
  expect(find.text('feedback'), findsNothing, reason: 'listener lingered');
}

void main() {
  const target = '/send-feedback';

  testWidgets('contrast: from another tab, search opens Me screen over Me', (
    tester,
  ) async {
    final h = await _start(tester, '/home');
    h.router.push('/search');
    await tester.pumpAndSettle();

    await h.ref.read(searchOpenProvider)(h.searchContext, _result(target));
    await tester.pumpAndSettle();
    expect(find.text('feedback'), findsOneWidget);

    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('me'), findsOneWidget);
    expect(find.text('feedback'), findsNothing);
    await _expectNoLingeringListener(tester, h);
  });

  testWidgets('search pushed over /me opens the Me screen over Me', (
    tester,
  ) async {
    final h = await _start(tester, '/me');
    h.router.push('/search');
    await tester.pumpAndSettle();

    await h.ref.read(searchOpenProvider)(h.searchContext, _result(target));
    await tester.pumpAndSettle();
    expect(find.text('feedback'), findsOneWidget, reason: 'not on top');

    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('me'), findsOneWidget, reason: 'back did not reach Me');
    await _expectNoLingeringListener(tester, h);
  });
}
