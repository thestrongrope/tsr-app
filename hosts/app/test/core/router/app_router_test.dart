import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/router/app_router.dart';
import 'package:the_strong_rope/core/router/deep_link_provider.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:riverpod/legacy.dart';

class FakeGoRouterState implements GoRouterState {
  FakeGoRouterState({required this.matchedLocation, Uri? uri})
    : uri = uri ?? Uri.parse(matchedLocation);

  @override
  final String matchedLocation;

  @override
  final Uri uri;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Router redirect - Guest mode', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Ref getRef() {
      // Create a dummy provider that captures Ref
      Ref? capturedRef;
      final provider = Provider((ref) {
        capturedRef = ref;
        return null;
      });
      container.read(provider);
      return capturedRef!;
    }

    test('guest at splash redirects to home', () {
      final ref = getRef();
      const authState = AuthState(status: AuthStatus.guest);
      final permissionsState = PermissionsState();
      final routerState = FakeGoRouterState(matchedLocation: AppRoutes.splash);

      final redirect = handleRedirect(
        ref,
        authState,
        permissionsState,
        routerState,
      );

      expect(redirect, equals(AppRoutes.home));
    });

    test('guest at /login is allowed (returns null)', () {
      final ref = getRef();
      const authState = AuthState(status: AuthStatus.guest);
      final permissionsState = PermissionsState();
      final routerState = FakeGoRouterState(matchedLocation: AppRoutes.login);

      final redirect = handleRedirect(
        ref,
        authState,
        permissionsState,
        routerState,
      );

      expect(redirect, isNull);
    });

    test(
      'guest at /release-notes is allowed (version row is for everyone)',
      () {
        final ref = getRef();
        const authState = AuthState(status: AuthStatus.guest);
        final permissionsState = PermissionsState();
        final routerState = FakeGoRouterState(
          matchedLocation: AppRoutes.releaseNotes,
        );

        final redirect = handleRedirect(
          ref,
          authState,
          permissionsState,
          routerState,
        );

        expect(redirect, isNull);
      },
    );

    test(
      'guest at /register is allowed (returns null, not redirected to home)',
      () {
        final ref = getRef();
        const authState = AuthState(status: AuthStatus.guest);
        final permissionsState = PermissionsState();
        final routerState = FakeGoRouterState(
          matchedLocation: AppRoutes.register,
        );

        final redirect = handleRedirect(
          ref,
          authState,
          permissionsState,
          routerState,
        );

        expect(redirect, isNull);
      },
    );

    test(
      'guest accessing /profile saves pending deep link and redirects to /login',
      () {
        final ref = getRef();
        const authState = AuthState(status: AuthStatus.guest);
        final permissionsState = PermissionsState();
        final routerState = FakeGoRouterState(
          matchedLocation: AppRoutes.profile,
        );

        final redirect = handleRedirect(
          ref,
          authState,
          permissionsState,
          routerState,
        );

        expect(redirect, equals(AppRoutes.login));
        expect(
          container.read(pendingDeepLinkProvider),
          equals(AppRoutes.profile),
        );
      },
    );

    test('guest accessing /home is allowed', () {
      final ref = getRef();
      const authState = AuthState(status: AuthStatus.guest);
      final permissionsState = PermissionsState();
      final routerState = FakeGoRouterState(matchedLocation: AppRoutes.home);

      final redirect = handleRedirect(
        ref,
        authState,
        permissionsState,
        routerState,
      );

      expect(redirect, isNull);
    });

    test('guest accessing public articles is allowed', () {
      final ref = getRef();
      const authState = AuthState(status: AuthStatus.guest);
      final permissionsState = PermissionsState();
      final routerState = FakeGoRouterState(
        matchedLocation: AppRoutes.articles,
      );

      final redirect = handleRedirect(
        ref,
        authState,
        permissionsState,
        routerState,
      );

      expect(redirect, isNull);
    });

    test('guest accessing publications is allowed', () {
      final ref = getRef();
      const authState = AuthState(status: AuthStatus.guest);
      final permissionsState = PermissionsState();
      final routerState = FakeGoRouterState(
        matchedLocation: AppRoutes.publications,
      );

      final redirect = handleRedirect(
        ref,
        authState,
        permissionsState,
        routerState,
      );

      expect(redirect, isNull);
    });

    // Signed out, or a failed sign-in: browsed as a guest (#555).
    for (final status in [AuthStatus.unauthenticated, AuthStatus.error]) {
      String? redirectAt(String location) => handleRedirect(
        getRef(),
        AuthState(status: status),
        PermissionsState(),
        FakeGoRouterState(matchedLocation: location),
      );

      test('${status.name} at splash goes to home, not login', () {
        expect(redirectAt(AppRoutes.splash), equals(AppRoutes.home));
      });

      test('${status.name} browses home and public content', () {
        expect(redirectAt(AppRoutes.home), isNull);
        expect(redirectAt(AppRoutes.videos), isNull);
        expect(redirectAt(AppRoutes.publications), isNull);
      });

      test('${status.name} opens every tab; Classes and Me invite sign-in', () {
        expect(redirectAt(AppRoutes.library), isNull);
        expect(redirectAt(AppRoutes.classes), isNull);
        expect(redirectAt(AppRoutes.me), isNull);
      });

      test('${status.name} inside a class is asked to sign in', () {
        expect(redirectAt('/classes/10/dashboard'), equals(AppRoutes.login));
      });

      test('${status.name} at /profile is asked to sign in, then sent on', () {
        expect(redirectAt(AppRoutes.profile), equals(AppRoutes.login));
        expect(
          container.read(pendingDeepLinkProvider),
          equals(AppRoutes.profile),
        );
      });
    }
  });

  group('Router redirect - permission guards', () {
    late ProviderContainer container;

    // Class 10 is a gents class (gender 1), class 20 a ladies class (gender 2).
    const gentsClass = ClassModel(
      id: 10,
      code: 'G10',
      name: 'Gents',
      level: 1,
      gender: 1,
      status: 'A',
    );
    const ladiesClass = ClassModel(
      id: 20,
      code: 'L20',
      name: 'Ladies',
      level: 1,
      gender: 2,
      status: 'A',
    );

    setUp(() {
      container = ProviderContainer(
        overrides: [
          classesProvider.overrideWith(
            (ref) => _FixedClassesNotifier(
              const ClassesState(classes: [gentsClass, ladiesClass]),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Ref getRef() {
      Ref? capturedRef;
      final provider = Provider((ref) {
        capturedRef = ref;
        return null;
      });
      container.read(provider);
      return capturedRef!;
    }

    const testUser = User(
      id: 1,
      token: 1,
      email: 'test@example.com',
      name: 'Test User',
      roleId: 0,
      gender: 1,
    );

    String? redirectFor(PermissionsPayload payload, String location) {
      return handleRedirect(
        getRef(),
        const AuthState(status: AuthStatus.authenticated, user: testUser),
        PermissionsState(payload: payload),
        FakeGoRouterState(matchedLocation: location),
      );
    }

    PermissionsPayload held(
      List<String> permissions, {
      PermissionScopes scopes = const PermissionScopes(),
    }) => PermissionsPayload(
      version: 4,
      permissions: permissions,
      scopes: scopes,
      issuedAt: '',
    );

    // A refresh (pull-down, app resume) reloads permissions while the member
    // is in the app. Going to the splash screen and back would reset the tabs
    // (#561), so the permissions they have hold until the new ones arrive.
    String? whileRefreshing(String location, {PermissionsPayload? payload}) =>
        handleRedirect(
          getRef(),
          const AuthState(status: AuthStatus.authenticated, user: testUser),
          PermissionsState(isLoading: true, payload: payload),
          FakeGoRouterState(matchedLocation: location),
        );

    test('a permissions refresh keeps the member where they are', () {
      expect(whileRefreshing('/library', payload: held(const [])), isNull);
      expect(whileRefreshing('/classes', payload: held(const [])), isNull);
    });

    test('a refresh still applies the guards, with the permissions held', () {
      expect(
        whileRefreshing('/admin', payload: held(const [])),
        equals(AppRoutes.home),
      );
    });

    test('with no permissions yet, loading waits on the splash screen', () {
      expect(whileRefreshing('/library'), equals(AppRoutes.splash));
      expect(whileRefreshing(AppRoutes.splash), isNull);
      expect(
        whileRefreshing(AppRoutes.splash, payload: held(const [])),
        isNull,
        reason: 'signing in waits on splash even with permissions cached',
      );
    });

    // Each guard: the permission, a path under it, and the held scope that
    // reaches class 10 (allowed) versus one that does not (refused).
    final guards = <String, String>{
      'sessions:create': '/classes/10/conduction',
      'mcqs:manage': '/classes/10/mcq/manage',
      'notifications:send': '/classes/10/notifications/send',
      'classes:update': '/classes/10/manage',
      'class-students:read': '/classes/10/students',
    };

    for (final path in ['/classes/10/notifications/scheduled', '/classes/10/scheduled-events']) {
      test('$path requires scoped notifications:send', () {
        expect(redirectFor(const PermissionsPayload.member(), path), AppRoutes.classes);
        expect(redirectFor(held(['notifications:send:own'], scopes: const PermissionScopes(own: [10])), path), isNull);
        expect(redirectFor(held(['notifications:send:own'], scopes: const PermissionScopes(own: [99])), path), AppRoutes.classes);
      });
    }

    guards.forEach((permission, path) {
      test('$path: allowed with $permission:own on class 10', () {
        final payload = held([
          '$permission:own',
        ], scopes: const PermissionScopes(own: [10]));
        expect(redirectFor(payload, path), isNull);
      });

      test('$path: refused when class 10 is not in own', () {
        final payload = held([
          '$permission:own',
        ], scopes: const PermissionScopes(own: [99]));
        expect(redirectFor(payload, path), equals(AppRoutes.classes));
      });

      test('$path: refused for a member who holds nothing', () {
        expect(
          redirectFor(const PermissionsPayload.member(), path),
          equals(AppRoutes.classes),
        );
      });

      test('$path: gender admin reaches their own gender, not the other', () {
        final payload = held([
          '$permission:gender',
        ], scopes: const PermissionScopes(gender: 1));
        expect(redirectFor(payload, path), isNull);
        expect(
          redirectFor(payload, path.replaceFirst('/10/', '/20/')),
          equals(AppRoutes.classes),
        );
      });

      test('$path: super admin reaches any class', () {
        expect(redirectFor(held(['$permission:all']), path), isNull);
      });
    });

    test('the MCQ copy screen needs mcqs:copy as well as mcqs:manage', () {
      const path = '/classes/10/mcq/manage/5/copy';
      const scopes = PermissionScopes(own: [10], assigned: [10]);
      expect(
        redirectFor(held(['mcqs:manage:own'], scopes: scopes), path),
        equals(AppRoutes.classes),
      );
      expect(
        redirectFor(
          held(['mcqs:manage:own', 'mcqs:copy:assigned'], scopes: scopes),
          path,
        ),
        isNull,
      );
    });

    test('/admin: refused without an admin module, allowed with broadcast', () {
      expect(
        redirectFor(const PermissionsPayload.member(), AppRoutes.admin),
        equals(AppRoutes.home),
      );
      expect(
        redirectFor(held(['notifications:broadcast:all']), AppRoutes.admin),
        isNull,
      );
    });

    test('/admin agrees with the Manage tab for every kind of member', () {
      final members = <PermissionsPayload>[
        const PermissionsPayload.member(),
        held(['notifications:broadcast:all']),
        held(['reports:read:gender']),
        held(['notifications:send:gender', 'classes:read:gender']),
        PermissionsPayload(
          version: 5,
          permissions: const [],
          issuedAt: '',
          revision: '0123456789abcdef',
          navigation: const PermissionsNavigation(classes: false, manage: true),
        ),
      ];
      for (final payload in members) {
        final manageTab = Capabilities.of(
          payload: payload,
          classes: null,
        ).showManageTab;
        expect(
          redirectFor(payload, AppRoutes.admin) == null,
          manageTab,
          reason: 'router and tab disagree for ${payload.permissions}',
        );
      }
    });

    test('a class route agrees with the permission the screen checks', () {
      const classes = [gentsClass, ladiesClass];
      final payload = held([
        'classes:update:gender',
      ], scopes: const PermissionScopes(gender: 2));
      final state = PermissionsState(payload: payload);
      for (final cls in classes) {
        final screenAllows = state.can(
          'classes:update',
          classId: cls.id,
          classGender: cls.gender,
        );
        expect(
          redirectFor(payload, '/classes/${cls.id}/manage') == null,
          screenAllows,
          reason: 'class ${cls.id}',
        );
      }
    });

    test('a class route is not refused while the class list is loading', () {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          classesProvider.overrideWith(
            (ref) => _FixedClassesNotifier(const ClassesState()),
          ),
        ],
      );
      final genderAdmin = held([
        'classes:update:gender',
      ], scopes: const PermissionScopes(gender: 2));
      expect(redirectFor(genderAdmin, '/classes/20/manage'), isNull);
      expect(
        redirectFor(const PermissionsPayload.member(), '/classes/20/manage'),
        equals(AppRoutes.classes),
        reason: 'a member who holds nothing is still refused',
      );
    });

    test('the retired page.class.* guards no longer redirect', () {
      final payload = held(const []);
      expect(redirectFor(payload, '/class-dashboard'), isNull);
      expect(redirectFor(payload, AppRoutes.classRegistration), isNull);
    });

    test('/admin: a class admin (class permissions only) is refused', () {
      final payload = held([
        'sessions:create:own',
        'mcqs:manage:own',
        'notifications:send:own',
      ], scopes: const PermissionScopes(own: [10]));
      expect(redirectFor(payload, AppRoutes.admin), equals(AppRoutes.home));
    });

    test('/admin: a gender admin (no broadcast) is refused', () {
      final payload = held([
        'notifications:send:gender',
        'classes:read:gender',
      ], scopes: const PermissionScopes(gender: 2));
      expect(redirectFor(payload, AppRoutes.admin), equals(AppRoutes.home));
      expect(
        redirectFor(payload, AppRoutes.adminNotifications),
        equals(AppRoutes.home),
      );
    });

    test('/admin/notifications and history: broadcast only', () {
      final broadcaster = held(['notifications:broadcast:all']);
      for (final path in [
        AppRoutes.adminNotifications,
        AppRoutes.sendNotification,
        AppRoutes.notificationHistory,
      ]) {
        expect(redirectFor(broadcaster, path), isNull);
      }
      // Syllabus-only admin has a dashboard, but not the notification screens.
      final syllabusOnly = held(['syllabus:update:all']);
      expect(
        redirectFor(syllabusOnly, AppRoutes.adminNotifications),
        equals(AppRoutes.admin),
      );
    });

    test('/admin/syllabus: needs syllabus:update', () {
      expect(
        redirectFor(held(['syllabus:update:all']), AppRoutes.adminSyllabus),
        isNull,
      );
      expect(
        redirectFor(
          held(['notifications:broadcast:all']),
          AppRoutes.adminSyllabus,
        ),
        equals(AppRoutes.admin),
      );
      expect(
        redirectFor(const PermissionsPayload.member(), AppRoutes.adminSyllabus),
        equals(AppRoutes.home),
      );
    });

    test(
      'the leaderboard and registrations need a permission of their own',
      () {
        // reports:read gets a member to the reports, not to these two.
        final reportsOnly = held(['reports:read:gender']);
        expect(
          redirectFor(reportsOnly, AppRoutes.adminQuranLeaderboard),
          equals(AppRoutes.adminReports),
        );
        expect(
          redirectFor(reportsOnly, AppRoutes.adminRegistrations),
          equals(AppRoutes.adminReports),
        );
        expect(
          redirectFor(
            held(['reports:read:gender', 'quran-leaderboard:read:gender']),
            AppRoutes.adminQuranLeaderboard,
          ),
          isNull,
        );
        expect(
          redirectFor(
            held(['reports:read:gender', 'registrations:read:gender']),
            AppRoutes.adminRegistrations,
          ),
          isNull,
        );
      },
    );

    test('teachers need teachers:read, for the list and for a teacher', () {
      final teachersOnly = held(['teachers:read:gender']);
      for (final path in [AppRoutes.adminTeachers, '/admin/teachers/7']) {
        expect(redirectFor(teachersOnly, path), isNull, reason: path);
        expect(
          redirectFor(held(['reports:read:gender']), path),
          equals(AppRoutes.admin),
          reason: path,
        );
        expect(
          redirectFor(held(['teachers:lookup:assigned']), path),
          equals(AppRoutes.home),
          reason: 'a coordinator holds no dashboard module',
        );
      }
      expect(redirectFor(teachersOnly, AppRoutes.admin), isNull);
    });

    test('donors need donors:read, and it is a module of its own (#421)', () {
      final finance = held(['donors:read:all']);
      expect(redirectFor(finance, AppRoutes.admin), isNull);
      expect(redirectFor(finance, AppRoutes.adminDonors), isNull);
      expect(
        redirectFor(held(['reports:read:gender']), AppRoutes.adminDonors),
        equals(AppRoutes.admin),
      );
      expect(
        redirectFor(held(['teachers:lookup:assigned']), AppRoutes.adminDonors),
        equals(AppRoutes.home),
        reason: 'a coordinator holds no dashboard module',
      );
    });

    test('deletion requests need deletion-requests:manage (#416)', () {
      final manager = held(['deletion-requests:manage:all']);
      expect(redirectFor(manager, AppRoutes.admin), isNull);
      expect(redirectFor(manager, AppRoutes.adminDeletionRequests), isNull);
      expect(
        redirectFor(
          held(['reports:read:gender']),
          AppRoutes.adminDeletionRequests,
        ),
        equals(AppRoutes.admin),
      );
      expect(
        redirectFor(
          held(['teachers:lookup:assigned']),
          AppRoutes.adminDeletionRequests,
        ),
        equals(AppRoutes.home),
        reason: 'a coordinator holds no dashboard module',
      );
    });

    test('the MCQ copy picker needs mcqs:copy', () {
      final copier = held([
        'mcqs:copy:gender',
      ], scopes: const PermissionScopes(gender: 1));
      expect(redirectFor(copier, AppRoutes.admin), isNull);
      expect(redirectFor(copier, AppRoutes.adminMcqCopy), isNull);
      expect(
        redirectFor(held(['reports:read:gender']), AppRoutes.adminMcqCopy),
        equals(AppRoutes.admin),
      );
      expect(
        redirectFor(held(['mcqs:manage:own']), AppRoutes.adminMcqCopy),
        equals(AppRoutes.home),
        reason: 'managing a class is not copying',
      );
    });

    test('the quiz admin needs quiz:admin', () {
      final admin = held(['quiz:admin:all']);
      expect(redirectFor(admin, AppRoutes.admin), isNull);
      expect(redirectFor(admin, AppRoutes.adminQuiz), isNull);
      expect(
        redirectFor(held(['reports:read:gender']), AppRoutes.adminQuiz),
        equals(AppRoutes.admin),
      );
      expect(
        redirectFor(held(['quiz:reset:all']), AppRoutes.adminQuiz),
        equals(AppRoutes.home),
        reason: 'delete-all alone is not the quiz admin',
      );
    });

    test('standard MCQs need standard-mcqs:update', () {
      final updater = held(['standard-mcqs:update:all']);
      expect(redirectFor(updater, AppRoutes.admin), isNull);
      expect(redirectFor(updater, AppRoutes.adminStandardMcqs), isNull);
      expect(
        redirectFor(held(['reports:read:gender']), AppRoutes.adminStandardMcqs),
        equals(AppRoutes.admin),
      );
      expect(
        redirectFor(
          held(['teachers:lookup:assigned']),
          AppRoutes.adminStandardMcqs,
        ),
        equals(AppRoutes.home),
        reason: 'a coordinator holds no dashboard module',
      );
    });
  });
}

class _FixedClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
