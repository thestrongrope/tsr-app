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

/// A parent-invite link opens the invite in the app (#1122). The operating
/// system hands Flutter the path of the https link, so the router sees
/// `/link/<code>`. Unlike a join or article link it is not public: accepting
/// needs an account, so a signed-out person signs in and comes back to it.
void main() {
  const link = '/link/AbCd123456';

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

  Future<void> drain() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  test('an invite link names one invite and is not public', () {
    expect(AppRoutes.isParentInviteLink(link), isTrue);
    expect(AppRoutes.isParentInviteLink('/link'), isFalse);
    expect(AppRoutes.isParentInviteLink('/link/'), isFalse);
    expect(AppRoutes.isParentInviteLink('/parent/links'), isFalse);
    expect(AppRoutes.isAppLink(link), isTrue);
    expect(AppRoutes.isPublicRoute(link), isFalse);
  });

  test('cold start: the invite link is kept while auth loads', () {
    final to = redirect(
      const AuthState(status: AuthStatus.loading),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.splash);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('cold start, signed out: asked to sign in, the invite is kept', () {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      AppRoutes.splash,
    );
    expect(to, AppRoutes.login);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('signed out inside the app: sent to sign in, the invite is kept', () {
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.login);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('after sign-in the same invite is shown', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.login,
    );
    expect(to, link);
    await drain();
  });

  test('cold start, signed in: opens the invite', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.splash,
    );
    expect(to, link);
    await drain();
  });

  test(
    'a new member lands on the invite once the profile is complete',
    () async {
      container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
      final to = redirect(
        const AuthState(status: AuthStatus.authenticated, user: complete),
        permissions,
        AppRoutes.profileCompletion,
      );
      expect(to, link);
      await drain();
    },
  );
}
