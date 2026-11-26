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

/// As go_router builds it: the matched location has no query, the uri has it.
class _FakeState implements GoRouterState {
  _FakeState(String location)
    : uri = Uri.parse(location),
      matchedLocation = Uri.parse(location).path;

  @override
  final String matchedLocation;

  @override
  final Uri uri;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A guide link opens that level's guide in the app (#1138). The link is
/// `/guide.php?guide=<slug>`, the page the web already serves and the app
/// already shares. It is not public: a signed-out person signs in and comes
/// back to the same guide, and a member who has not finished registering
/// finishes first.
void main() {
  const link = '/guide.php?guide=miqdad';

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

  test('a guide link is the guide page, and is not public', () {
    expect(AppRoutes.isGuideLink('/guide.php'), isTrue);
    expect(AppRoutes.isGuideLink('/guides'), isFalse);
    expect(AppRoutes.isGuideLink('/guide.phps'), isFalse);
    expect(AppRoutes.isAppLink('/guide.php'), isTrue);
    expect(AppRoutes.isPublicRoute('/guide.php'), isFalse);
  });

  test(
    'cold start: the guide link is kept, query included, while auth loads',
    () {
      final to = redirect(
        const AuthState(status: AuthStatus.loading),
        PermissionsState(),
        link,
      );
      expect(to, AppRoutes.splash);
      expect(container.read(pendingDeepLinkProvider), link);
    },
  );

  test('cold start, signed out: asked to sign in, the guide link is kept', () {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      AppRoutes.splash,
    );
    expect(to, AppRoutes.login);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('signed out inside the app: sent to sign in, the guide is kept', () {
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.login);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test('after sign-in the same guide is shown', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.login,
    );
    expect(to, link);
    await drain();
  });

  test('cold start, signed in: opens the guide', () async {
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
    'a member who has not finished registering finishes, then reads',
    () async {
      container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
      const incomplete = User(
        id: 1,
        token: 1,
        email: 'a@example.com',
        name: '',
        roleId: 0,
      );
      final first = redirect(
        const AuthState(status: AuthStatus.authenticated, user: incomplete),
        permissions,
        AppRoutes.login,
      );
      expect(first, AppRoutes.profileCompletion);
      expect(container.read(pendingDeepLinkProvider), link);

      final then = redirect(
        const AuthState(status: AuthStatus.authenticated, user: complete),
        permissions,
        AppRoutes.profileCompletion,
      );
      expect(then, link);
      await drain();
    },
  );
}
