import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/search/models/search_result.dart';
import 'package:the_strong_rope/features/search/providers/search_provider.dart';

// A search result opened from /search (#557). /search is a root route; the class
// dashboard lives in the Classes branch of the tab shell, so pushing it from
// there adds a second copy of the shell to the root navigator and Flutter
// asserts on the duplicate key. The person cards are root routes, so they push.
// This mirrors app_router.dart's shape, because the real route tree cannot be
// built in a test.

SearchResult _result(String target) => SearchResult(
  kind: SearchKind.classRecord,
  id: 1,
  title: 'x',
  subtitle: '',
  target: target,
);

GoRouter _router(void Function(BuildContext, WidgetRef) onSearchBuilt) =>
    GoRouter(
      initialLocation: '/home',
      // The app has an onEnter hook and a top-level redirect, as here. With the
      // hook, a `go` has not taken effect by the time the next line runs.
      onEnter: (_, _, _, _) => const Allow(),
      redirect: (_, _) => null,
      routes: [
        GoRoute(
          path: '/search',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              onSearchBuilt(context, ref);
              return const Text('search');
            },
          ),
        ),
        GoRoute(
          path: '/students/:token',
          builder: (_, state) =>
              Text('student ${state.pathParameters['token']}'),
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
                  path: '/classes',
                  builder: (_, _) => const Text('classes'),
                  routes: [
                    GoRoute(
                      path: ':id/dashboard',
                      builder: (_, state) =>
                          Text('dashboard ${state.pathParameters['id']}'),
                    ),
                  ],
                ),
              ],
            ),
            // As in the app, a Me screen is a sibling of Me, not nested in it.
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/me', builder: (_, _) => const Text('me')),
                GoRoute(path: '/about', builder: (_, _) => const Text('about')),
              ],
            ),
          ],
        ),
      ],
    );

Future<(GoRouter, BuildContext, WidgetRef)> _onSearch(
  WidgetTester tester,
) async {
  late BuildContext context;
  late WidgetRef ref;
  final router = _router((c, r) {
    context = c;
    ref = r;
  });
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  router.push('/search');
  await tester.pumpAndSettle();
  return (router, context, ref);
}

void main() {
  testWidgets('a class result opens the class', (tester) async {
    final (_, context, ref) = await _onSearch(tester);

    await ref.read(searchOpenProvider)(
      context,
      _result('/classes/408/dashboard'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('dashboard 408'), findsOneWidget);
  });

  testWidgets('a Me screen opens with Me behind it, so back returns there', (
    tester,
  ) async {
    final (router, context, ref) = await _onSearch(tester);

    await ref.read(searchOpenProvider)(context, _result('/about'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('about'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('me'), findsOneWidget);
    expect(find.text('about'), findsNothing);
  });

  testWidgets('a person card opens over search and back returns to it', (
    tester,
  ) async {
    final (router, context, ref) = await _onSearch(tester);

    await ref.read(searchOpenProvider)(context, _result('/students/101'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('student 101'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('search'), findsOneWidget);
  });
}
