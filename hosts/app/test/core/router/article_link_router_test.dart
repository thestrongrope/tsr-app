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

/// A shared article link opens the article in the app (#1121). The operating
/// system hands Flutter the path of the https link, so the router sees
/// `/articles/<slug>`, signed in or not.
void main() {
  const link = '/articles/on-patience';

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

  test('an article link names one article; the list and Home paths do not', () {
    expect(AppRoutes.isArticleLink(link), isTrue);
    expect(AppRoutes.isArticleLink('/articles'), isFalse);
    expect(AppRoutes.isArticleLink('/articles/'), isFalse);
    expect(AppRoutes.isArticleLink('/home/articles/detail/x'), isFalse);
    expect(AppRoutes.isArticleLink('/videos/abc'), isFalse);
  });

  test('cold start: the article link is kept while auth loads', () {
    final to = redirect(
      const AuthState(status: AuthStatus.loading),
      PermissionsState(),
      link,
    );
    expect(to, AppRoutes.splash);
    expect(container.read(pendingDeepLinkProvider), link);
  });

  test(
    'cold start, signed out: the article is shown, not Home or login',
    () async {
      container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
      final to = redirect(
        const AuthState(status: AuthStatus.guest),
        PermissionsState(),
        AppRoutes.splash,
      );
      expect(to, link);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
  );

  test('a signed-out person opening the article in the app sees it', () {
    final to = redirect(
      const AuthState(status: AuthStatus.guest),
      PermissionsState(),
      link,
    );
    expect(to, isNull);
  });

  test('cold start, signed in: opens the article', () async {
    container.read(pendingDeepLinkProvider.notifier).setPendingLink(link);
    final to = redirect(
      const AuthState(status: AuthStatus.authenticated, user: complete),
      permissions,
      AppRoutes.splash,
    );
    expect(to, link);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
}
