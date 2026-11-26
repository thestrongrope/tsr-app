import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';
import 'package:the_strong_rope/features/auth/presentation/login_screen.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';

/// An auth notifier that holds a fixed state and touches no network or Firebase.
class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _app({required String location, required AuthState auth}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [GoRoute(path: '/login', builder: (_, _) => const LoginScreen())],
  );
  return ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => _FixedAuth(auth))],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// What the login screen says in its error snackbar (#428, finding 3).
///
/// `thestrongrope://app` is an exported deep link, so anyone can open
/// `/login?error=<anything>`. The screen must show only the error the auth
/// state holds, never text that arrived in a URL: otherwise a crafted link puts
/// a fake "Account suspended, WhatsApp +91…" message in the app's own voice.
void main() {
  const crafted =
      'Account suspended. WhatsApp +91-0000000000 to restore access';

  testWidgets('text in a link is not shown as an error', (tester) async {
    await tester.pumpWidget(
      _app(
        location: '/login?error=${Uri.encodeComponent(crafted)}',
        auth: const AuthState(status: AuthStatus.unauthenticated),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(crafted), findsNothing);
  });

  testWidgets('an error the auth state holds is still shown', (tester) async {
    await tester.pumpWidget(
      _app(
        location: '/login',
        auth: const AuthState(
          status: AuthStatus.error,
          error: 'Sign in failed. Try again.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in failed. Try again.'), findsOneWidget);
  });
}
