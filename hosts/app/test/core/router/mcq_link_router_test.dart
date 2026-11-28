import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/router/app_router.dart';
import 'package:the_strong_rope/core/router/deep_link_provider.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';

class _FakeState implements GoRouterState {
  _FakeState(this.matchedLocation) : uri = Uri.parse(matchedLocation);

  @override
  final String matchedLocation;

  @override
  final Uri uri;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An MCQ link survives sign-in, the new-member profile step and a cold start
/// (#861), and a bad MCQ id does not crash the quiz screen.
void main() {
  const link = '/mcq/AbCd1234';

  const incomplete = User(
    id: 1,
    token: 1,
    email: 'a@example.com',
    name: 'New Member',
    roleId: 0,
  );
  const complete = User(
    id: 1,
    token: 1,
    email: 'a@example.com',
    name: 'Member',
    roleId: 0,
    gender: 1,
    ageRange: 2,
    mobile: '123',
    country: 'India',
    state: 'MH',
    city: 'Mumbai',
    language: 1,
    zip: '400001',
  );
  final permissions = PermissionsState(
    payload: const PermissionsPayload(
      version: 4,
      permissions: [],
      scopes: PermissionScopes(),
      issuedAt: '',
    ),
  );

  late ProviderContainer container;
  late Ref ref;

  setUp(() {
    container = ProviderContainer();
    Ref? captured;
    container.read(
      Provider((r) {
        captured = r;
        return null;
      }),
    );
    ref = captured!;
  });
  tearDown(() => container.dispose());

  String? redirect(AuthState auth, PermissionsState perms, String location) =>
      handleRedirect(ref, auth, perms, _FakeState(location));

  test('cold start: the link is kept while auth loads', () {
    final to = redirect(
      const AuthState(status: AuthStatus.loading),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.splash);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('cold start: another location is not kept', () {
    redirect(
      const AuthState(status: AuthStatus.loading),
      PermissionsState(),
      '/profile',
    );
    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  test('cold start, signed out: asked to sign in, not sent home', () {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      AppRoutes.splash,
    );
    expect(to, AppRoutes.login);
  });

  test('cold start, signed in: opens the link', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.splash,
    );
    expect(to, link);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  test('a signed-out member who taps the link is sent to sign in', () {
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.login);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('a new member is sent to the profile first, link kept', () {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: incomplete),
      permissions,
      AppRoutes.login,
    );
    expect(to, AppRoutes.profileCompletion);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('once the profile is complete the member lands on the MCQ', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.profileCompletion,
    );
    expect(to, link);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  test('profile completion with no saved link goes home', () {
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.profileCompletion,
    );
    expect(to, AppRoutes.home);
  });

  test('profile completion leaves a saved link that is not an MCQ link', () {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink('/profile');
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.profileCompletion,
    );
    expect(to, AppRoutes.home);
  });

  testWidgets('a malformed MCQ id shows not found, not a crash', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/quizzes/abc',
      routes: [
        GoRoute(
          path: '/quizzes/:quizId',
          builder: buildQuizTakingPage,
          routes: [GoRoute(path: 'result', builder: buildQuizResultPage)],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Page not found'), findsOneWidget);
    router.go('/quizzes/abc/result');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });
}
