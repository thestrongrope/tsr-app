import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/widgets/bottom_nav_scaffold.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions, PermissionScopes scopes) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: scopes,
        issuedAt: '',
      ),
    );
  }
}

/// Everyone holds classes:read at scope `enrolled`; what makes the Classes tab
/// relevant is having a class in one of the scope lists, or reading a gender's
/// or every class.
const _everyone = ['classes:read:enrolled', 'profile:read:self'];

/// Attends a class (#643).
const _studentScopes = PermissionScopes(enrolled: [412]);

/// Holds an admin module (reports) and reads its gender's classes, so Manage
/// and Classes both show.
const _manager = ['reports:read:gender', 'classes:read:gender'];

/// The class list Home shows, without a network.
class _FixedClasses extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClasses(List<ClassModel>? classes)
    : super(ClassesState(classes: classes));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _aClass = ClassModel(
  id: 1,
  code: 'C1',
  name: 'Alpha',
  level: 1,
  gender: 1,
  status: 'active',
);

/// The tab scaffold with stand-in screens: a start and one screen inside, per
/// tab, so the tests see which screen each tab shows.
GoRouter _router() {
  StatefulShellBranch tab(String name) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/$name',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/$name/inner'),
            child: Text('$name start'),
          ),
        ),
        routes: [
          GoRoute(
            path: 'inner',
            builder: (context, state) => Text('$name inner'),
          ),
        ],
      ),
    ],
  );

  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            BottomNavScaffold(navigationShell: shell),
        branches: [
          tab('home'),
          tab('library'),
          tab('classes'),
          tab('manage'),
          tab('me'),
        ],
      ),
    ],
  );
}

Future<GoRouter> _pumpTabs(
  WidgetTester tester, {
  List<String> permissions = _everyone,
  PermissionScopes scopes = _studentScopes,
  List<ClassModel>? classes,
}) async {
  final router = _router();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        unreadNotificationCountProvider.overrideWithValue(0),
        permissionsProvider.overrideWith(
          (ref) => _FixedPermissions(permissions, scopes),
        ),
        classesProvider.overrideWith((ref) => _FixedClasses(classes)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(GlassBottomNavBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  Finder tab(String label) => find.descendant(
    of: find.byType(GlassBottomNavBar),
    matching: find.text(label),
  );

  testWidgets('a student sees four tabs, no Manage', (tester) async {
    await _pumpTabs(tester);
    for (final label in ['Home', 'Library', 'Classes', 'Me']) {
      expect(tab(label), findsOneWidget);
    }
    expect(tab('Manage'), findsNothing);
  });

  group('the floating tab bar (#998)', () {
    testWidgets('shows on a screen inside a tab, not only its start', (
      tester,
    ) async {
      await _pumpTabs(tester);
      await tester.tap(find.text('home start'));
      await tester.pumpAndSettle();

      expect(find.text('home inner'), findsOneWidget);
      expect(find.byType(GlassBottomNavBar), findsOneWidget);
    });

    testWidgets('a guest sees only Home, Library and Me', (tester) async {
      await _pumpTabs(
        tester,
        permissions: const [],
        scopes: const PermissionScopes(),
      );
      final bar = tester.widget<GlassBottomNavBar>(
        find.byType(GlassBottomNavBar),
      );
      expect(
        [for (final d in bar.destinations) d.label],
        ['Home', 'Library', 'Me'],
      );
    });
  });

  group('the Classes tab is for people with classes (#643)', () {
    Future<void> expectClassesTab(
      WidgetTester tester, {
      required bool shown,
      List<String> permissions = _everyone,
      PermissionScopes scopes = const PermissionScopes(),
    }) async {
      await _pumpTabs(tester, permissions: permissions, scopes: scopes);
      expect(tab('Classes'), shown ? findsOneWidget : findsNothing);
      for (final label in ['Home', 'Library', 'Me']) {
        expect(tab(label), findsOneWidget);
      }
    }

    testWidgets('a subscriber with no class does not see it', (tester) async {
      await expectClassesTab(tester, shown: false);
    });

    testWidgets('a member with classes in the list sees it, whatever the '
        'permissions copy says', (tester) async {
      await _pumpTabs(
        tester,
        permissions: const [],
        scopes: const PermissionScopes(),
        classes: const [_aClass],
      );
      expect(tab('Classes'), findsOneWidget);
    });

    testWidgets('a member with no classes in the list and none in the '
        'permissions has no Classes tab', (tester) async {
      await _pumpTabs(
        tester,
        permissions: const [],
        scopes: const PermissionScopes(),
        classes: const [],
      );
      expect(tab('Classes'), findsNothing);
    });

    testWidgets('someone who attends a class sees it', (tester) async {
      await expectClassesTab(
        tester,
        shown: true,
        scopes: const PermissionScopes(enrolled: [412]),
      );
    });

    testWidgets('a teacher sees it, and so does a class MCQ admin', (
      tester,
    ) async {
      await expectClassesTab(
        tester,
        shown: true,
        permissions: [..._everyone, 'classes:read:own'],
        scopes: const PermissionScopes(taught: [7]),
      );
      await expectClassesTab(
        tester,
        shown: true,
        permissions: [..._everyone, 'classes:read:own'],
        scopes: const PermissionScopes(own: [9]),
      );
    });

    testWidgets('a coordinator with an assigned class sees it', (tester) async {
      await expectClassesTab(
        tester,
        shown: true,
        permissions: [..._everyone, 'classes:read:assigned'],
        scopes: const PermissionScopes(assigned: [5]),
      );
    });

    testWidgets('a gender admin and the super admin see it', (tester) async {
      await expectClassesTab(
        tester,
        shown: true,
        permissions: [..._everyone, 'classes:read:gender'],
        scopes: const PermissionScopes(gender: 1),
      );
      await expectClassesTab(
        tester,
        shown: true,
        permissions: [..._everyone, 'classes:read:all'],
      );
    });

    testWidgets('a coordinator with nothing assigned does not see it', (
      tester,
    ) async {
      await expectClassesTab(
        tester,
        shown: false,
        permissions: [..._everyone, 'classes:read:assigned'],
      );
    });

    testWidgets('finance, with no class, has Manage but not Classes', (
      tester,
    ) async {
      await _pumpTabs(
        tester,
        permissions: [..._everyone, 'donors:read:all'],
        scopes: const PermissionScopes(),
      );
      expect(tab('Manage'), findsOneWidget);
      expect(tab('Classes'), findsNothing);
    });

    testWidgets('a guest, with no permissions fetched, does not see it', (
      tester,
    ) async {
      await _pumpTabs(
        tester,
        permissions: const [],
        scopes: const PermissionScopes(),
      );
      expect(tab('Classes'), findsNothing);
      expect(tab('Home'), findsOneWidget);
    });

    testWidgets('the tabs keep their order and Me stays last', (tester) async {
      await _pumpTabs(
        tester,
        permissions: [..._everyone, 'donors:read:all'],
        scopes: const PermissionScopes(),
      );
      final order = ['Home', 'Library', 'Manage', 'Me'];
      final xs = [for (final l in order) tester.getTopLeft(tab(l)).dx];
      expect(xs, [...xs]..sort());
    });
  });

  testWidgets('someone who holds an admin module sees Manage before Me', (
    tester,
  ) async {
    await _pumpTabs(tester, permissions: _manager);

    expect(tab('Manage'), findsOneWidget);
    expect(
      tester.getTopLeft(tab('Manage')).dx,
      lessThan(tester.getTopLeft(tab('Me')).dx),
    );
    expect(
      tester.getTopLeft(tab('Classes')).dx,
      lessThan(tester.getTopLeft(tab('Manage')).dx),
    );
  });

  testWidgets('Manage opens its own stack, which keeps its place', (
    tester,
  ) async {
    await _pumpTabs(tester, permissions: _manager);
    await _tapTab(tester, 'Manage');
    await tester.tap(find.text('manage start'));
    await tester.pumpAndSettle();
    expect(find.text('manage inner'), findsOneWidget);

    await _tapTab(tester, 'Home');
    await _tapTab(tester, 'Manage');
    expect(find.text('manage inner'), findsOneWidget);
  });

  testWidgets('Me is the tab it was, with or without Manage', (tester) async {
    await _pumpTabs(tester);
    await _tapTab(tester, 'Me');
    expect(find.text('me start'), findsOneWidget);
    expect(
      tester
          .widget<GlassBottomNavBar>(find.byType(GlassBottomNavBar))
          .selectedIndex,
      3,
    );

    await _pumpTabs(tester, permissions: _manager);
    await _tapTab(tester, 'Me');
    expect(find.text('me start'), findsOneWidget);
    expect(
      tester
          .widget<GlassBottomNavBar>(find.byType(GlassBottomNavBar))
          .selectedIndex,
      4,
    );
  });

  testWidgets('losing every admin permission on Manage goes Home', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        unreadNotificationCountProvider.overrideWithValue(0),
        permissionsProvider.overrideWith(
          (ref) =>
              _FixedPermissions(_manager, const PermissionScopes(gender: 1)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = _router();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Manage');
    expect(find.text('manage start'), findsOneWidget);

    final notifier =
        container.read(permissionsProvider.notifier) as _FixedPermissions;
    notifier.state = const PermissionsState(
      payload: PermissionsPayload.member(),
    );
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/home');
    expect(tab('Manage'), findsNothing);
  });

  testWidgets('a tab shows where it was last left', (tester) async {
    await _pumpTabs(tester);
    await _tapTab(tester, 'Library');
    await tester.tap(find.text('library start'));
    await tester.pumpAndSettle();

    await _tapTab(tester, 'Home');
    expect(find.text('home start'), findsOneWidget);

    await _tapTab(tester, 'Library');
    expect(find.text('library inner'), findsOneWidget);
  });

  testWidgets('tapping the open tab returns to its start', (tester) async {
    await _pumpTabs(tester);
    await _tapTab(tester, 'Classes');
    await tester.tap(find.text('classes start'));
    await tester.pumpAndSettle();
    expect(find.text('classes inner'), findsOneWidget);

    await _tapTab(tester, 'Classes');
    expect(find.text('classes start'), findsOneWidget);
  });

  testWidgets('back from a tab start goes Home; inside a tab it pops first', (
    tester,
  ) async {
    final router = await _pumpTabs(tester);
    await _tapTab(tester, 'Me');
    await tester.tap(find.text('me start'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('me start'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/home');
  });

  testWidgets('a link to a screen in a tab shows it in that tab', (
    tester,
  ) async {
    final router = await _pumpTabs(tester);
    router.go('/classes/inner');
    await tester.pumpAndSettle();

    expect(find.text('classes inner'), findsOneWidget);
    final bar = tester.widget<GlassBottomNavBar>(
      find.byType(GlassBottomNavBar),
    );
    expect(bar.selectedIndex, 2);
  });

  testWidgets('losing every class while on Classes goes Home (#643)', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        unreadNotificationCountProvider.overrideWithValue(0),
        permissionsProvider.overrideWith(
          (ref) => _FixedPermissions(_everyone, _studentScopes),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = _router();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Classes');
    expect(find.text('classes start'), findsOneWidget);

    final notifier =
        container.read(permissionsProvider.notifier) as _FixedPermissions;
    notifier.state = const PermissionsState(
      payload: PermissionsPayload.member(),
    );
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/home');
    expect(tab('Classes'), findsNothing);
  });
}
