import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/router/deep_link_provider.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/classes/screens/join_link_screen.dart';

/// The join link screen (#815-#817): shows the class the link names; a
/// signed-out member signs in and returns to it.
void main() {
  const code = 'AbCd123456';
  const open = JoinPreview(
    name: 'Aqaed Level 1',
    level: 'Miqdad',
    language: 'English',
    gender: 'Gents',
    open: true,
  );

  late ProviderContainer container;
  final opened = <Uri>[];

  Future<void> pump(
    WidgetTester tester, {
    required JoinPreview? preview,
    required AuthStatus status,
    bool fails = false,
  }) async {
    opened.clear();
    final router = GoRouter(
      initialLocation: '/join/$code',
      routes: [
        GoRoute(
          path: '/join/:code',
          builder: (_, state) => JoinLinkScreen(
            code: state.pathParameters['code']!,
            openInBrowser: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
        GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
      ],
    );
    container = ProviderContainer(
      overrides: [
        joinPreviewProvider(code).overrideWith((_) async {
          if (fails) throw Exception('offline');
          return preview;
        }),
        authStateProvider.overrideWith(
          (ref) => _FixedAuth(AuthState(status: status)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a signed-in member sees the class and continues in the browser',
    (tester) async {
      await pump(tester, preview: open, status: AuthStatus.authenticated);
      expect(find.text('Aqaed Level 1'), findsOneWidget);
      expect(find.text('Miqdad · English · Gents'), findsOneWidget);
      await tester.tap(find.text('Continue in the browser'));
      await tester.pump();
      expect(
        opened.single.toString(),
        'https://account.thestrongrope.com/join/$code',
      );
    },
  );

  testWidgets('a signed-out member signs in and the link is kept', (
    tester,
  ) async {
    await pump(tester, preview: open, status: AuthStatus.guest);
    await tester.tap(find.text('Sign in to join'));
    await tester.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);
    expect(container.read(pendingDeepLinkProvider), '/join/$code');
  });

  testWidgets('cancelling sign-in returns to the class', (tester) async {
    await pump(tester, preview: open, status: AuthStatus.guest);
    await tester.tap(find.text('Sign in to join'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Aqaed Level 1'), findsOneWidget);
  });

  testWidgets('a closed class says so and offers no join', (tester) async {
    await pump(
      tester,
      preview: const JoinPreview(
        name: 'Old class',
        level: '',
        language: '',
        gender: '',
        open: false,
      ),
      status: AuthStatus.authenticated,
    );
    expect(find.text('This class is not taking new members.'), findsOneWidget);
    expect(find.text('Continue in the browser'), findsNothing);
  });

  testWidgets('a code that names no class says so, no crash', (tester) async {
    await pump(tester, preview: null, status: AuthStatus.guest);
    expect(find.textContaining('could not find this class'), findsOneWidget);
  });

  testWidgets('a failed load shows an error with Retry', (tester) async {
    await pump(tester, preview: open, status: AuthStatus.guest, fails: true);
    expect(find.text('Retry'), findsOneWidget);
  });
}

/// An auth notifier that holds a fixed state and touches no network.
class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
