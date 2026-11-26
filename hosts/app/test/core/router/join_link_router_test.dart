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

/// A join link opens the class in the app (#815-#817). The operating system
/// hands Flutter only the path of an https link (the host is matched by the
/// manifest and entitlements), so the router sees `/join/<code>`.
void main() {
  const link = '/join/AbCd123456';

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

  test('join, MCQ and article links are app links; nothing else is', () {
    expect(AppRoutes.isAppLink('/join/AbCd123456'), isTrue);
    expect(AppRoutes.isAppLink('/mcq/AbCd1234'), isTrue);
    expect(AppRoutes.isAppLink('/articles/hello'), isTrue);
    expect(AppRoutes.isAppLink('/articles'), isFalse);
    expect(AppRoutes.isAppLink('/videos/abc'), isFalse);
    expect(AppRoutes.isAppLink('/home'), isFalse);
    expect(AppRoutes.isAppLink('/join'), isFalse);
  });

  test('a join link is public, so a signed-out person sees the class', () {
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      link,
    );
    expect(to, isNull);
  });

  test('cold start: the join link is kept while auth loads', () {
    final to = redirect(
      const AuthState(status: AuthStatus.loading),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.splash);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('cold start, signed out: the class is shown, not Home', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      AppRoutes.splash,
    );
    expect(to, link);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  test('cold start, signed in: opens the class', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.splash,
    );
    expect(to, link);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  test('after sign-in the same class is shown', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.login,
    );
    expect(to, link);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  test(
    'a new member lands on the class once the profile is complete',
    () async {
      container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
      final to = redirect(
        const AuthState(status: AuthStatus.authenticated, user: complete),
        permissions,
        AppRoutes.profileCompletion,
      );
      expect(to, link);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
  );

  testWidgets('the join route reaches the join screen', (tester) async {
    final router = GoRouter(
      initialLocation: link,
      routes: [
        GoRoute(
          path: AppRoutes.joinLink,
          builder: (_, state) => Text('join ${state.pathParameters['code']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('join AbCd123456'), findsOneWidget);
  });
}
