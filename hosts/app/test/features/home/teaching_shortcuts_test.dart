import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/teaching_shortcuts.dart';

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

class _FixedClasses extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClasses(super.state);

  int loads = 0;

  @override
  Future<void> loadClasses({bool allowSaved = true}) async => loads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClassModel _class(int id, String name, {String? role = 'conducting'}) =>
    ClassModel(
      id: id,
      code: 'C$id',
      name: name,
      level: 1,
      gender: 1,
      status: 'active',
      role: role,
    );

const _teacherPermissions = [
  'sessions:create:taught',
  'notifications:send:taught',
];

Widget _wrap({
  List<ClassModel>? classes,
  bool isLoading = false,
  String? error,
  _FixedClasses? notifier,
  List<String> permissions = _teacherPermissions,
  List<int> taught = const [],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      classesProvider.overrideWith(
        (ref) =>
            notifier ??
            _FixedClasses(
              ClassesState(
                classes: classes,
                isLoading: isLoading,
                error: error,
              ),
            ),
      ),
      permissionsProvider.overrideWith(
        (ref) =>
            _FixedPermissions(permissions, PermissionScopes(taught: taught)),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: TeachingShortcuts()),
          ),
          GoRoute(
            path: '/classes/:classId/conduction/add',
            builder: (_, s) =>
                Scaffold(body: Text('form ${s.pathParameters['classId']}')),
          ),
          GoRoute(
            path: '/classes/:classId/notifications/send',
            builder: (_, s) =>
                Scaffold(body: Text('announce ${s.pathParameters['classId']}')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a teacher of one class opens the form in one tap', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(classes: [_class(7, 'Alpha')], taught: [7]));
    await tester.pumpAndSettle();
    expect(find.text('Record conduction'), findsOneWidget);
    expect(find.text('Class announcement'), findsOneWidget);

    await tester.tap(find.text('Record conduction'));
    await tester.pumpAndSettle();
    expect(find.text('form 7'), findsOneWidget);
  });

  testWidgets('several classes ask which one, for either shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(classes: [_class(1, 'Alpha'), _class(2, 'Beta')], taught: [1, 2]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class announcement'));
    await tester.pumpAndSettle();
    expect(find.text('Class announcement: which class?'), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('announce 2'), findsOneWidget);
  });

  testWidgets('a class without the permission is not offered', (tester) async {
    // Teaches 1 and 2, but holds the grant for class 1 only.
    await tester.pumpWidget(
      _wrap(classes: [_class(1, 'Alpha'), _class(2, 'Beta')], taught: [1]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record conduction'));
    await tester.pumpAndSettle();
    // Only one class is reachable, so no picker and straight to the form.
    expect(find.text('form 1'), findsOneWidget);
  });

  testWidgets('each shortcut follows its own permission', (tester) async {
    await tester.pumpWidget(
      _wrap(
        classes: [_class(1, 'Alpha')],
        permissions: const ['sessions:create:taught'],
        taught: [1],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Record conduction'), findsOneWidget);
    expect(find.text('Class announcement'), findsNothing);
  });

  testWidgets('no teaching class shows no shortcut', (tester) async {
    await tester.pumpWidget(
      _wrap(
        classes: [
          _class(1, 'Alpha', role: null),
          _class(2, 'Beta', role: 'managing'),
        ],
        permissions: const ['sessions:create:all', 'notifications:send:all'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Record conduction'), findsNothing);
    expect(find.text('Class announcement'), findsNothing);
  });

  testWidgets('while loading, a tap says so and opens nothing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        classes: [_class(1, 'Alpha'), _class(2, 'Beta')],
        isLoading: true,
        taught: [1, 2],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record conduction'));
    await tester.pumpAndSettle();
    expect(find.text('Loading your classes...'), findsOneWidget);
    expect(find.text('Record conduction: which class?'), findsNothing);
    expect(find.text('form 1'), findsNothing);
  });

  testWidgets('a failed load shows the error with Retry and opens nothing', (
    tester,
  ) async {
    final notifier = _FixedClasses(const ClassesState(error: 'No connection'));
    await tester.pumpWidget(_wrap(notifier: notifier, taught: [1, 2]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class announcement'));
    await tester.pumpAndSettle();
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Class announcement: which class?'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(notifier.loads, 1);
  });

  testWidgets('a class that stopped being eligible is not opened', (
    tester,
  ) async {
    final notifier = _FixedClasses(
      ClassesState(classes: [_class(1, 'Alpha'), _class(2, 'Beta')]),
    );
    await tester.pumpWidget(_wrap(notifier: notifier, taught: [1, 2]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record conduction'));
    await tester.pumpAndSettle();
    notifier.state = ClassesState(classes: [_class(1, 'Alpha')]);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(
      find.text('That class is no longer available for this action.'),
      findsOneWidget,
    );
    expect(find.text('form 2'), findsNothing);
  });
}
