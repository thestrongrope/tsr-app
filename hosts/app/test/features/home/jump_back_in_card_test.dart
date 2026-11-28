import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/home/models/recent_action.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/jump_back_in_card.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';
import 'package:the_strong_rope/features/home/services/recent_actions_store.dart';

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedRecent extends RecentActionsNotifier {
  _FixedRecent(List<RecentAction> events) : super(RecentActionsStore(), null) {
    state = events;
  }
}

ClassModel _class(int id, String name) => ClassModel(
  id: id,
  code: 'C$id',
  name: name,
  level: 1,
  gender: 1,
  status: 'active',
);

RecentAction _visit(RecentActionKind kind, {int? classId}) =>
    RecentAction(kind: kind, classId: classId, at: DateTime.now());

Widget _wrap({
  required List<RecentAction> events,
  List<ClassModel> classes = const [],
  List<String> permissions = const [],
  PermissionScopes scopes = const PermissionScopes(),
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      recentActionsProvider.overrideWith((ref) => _FixedRecent(events)),
      classesProvider.overrideWith(
        (ref) => _FixedClasses(ClassesState(classes: classes)),
      ),
      permissionsProvider.overrideWith(
        (ref) => _FixedPermissions(permissions, scopes),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: JumpBackInCard()),
          ),
          GoRoute(
            path: '/classes/:classId/quizzes',
            builder: (_, state) => Scaffold(
              body: Text('quizzes ${state.pathParameters['classId']}'),
            ),
          ),
          GoRoute(
            path: '/classes/:classId/conduction',
            builder: (_, _) => const Scaffold(body: Text('conduction')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('shows up to four items, named from the live class list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        events: [
          for (var id = 1; id <= 5; id++)
            _visit(RecentActionKind.classQuizzes, classId: id),
        ],
        classes: [for (var id = 1; id <= 5; id++) _class(id, 'Class $id')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jump back in'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(find.text('Class 5: Quizzes'), findsOneWidget);
  });

  testWidgets('drops a class that is no longer in the live list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        events: [
          _visit(RecentActionKind.classQuizzes, classId: 1),
          _visit(RecentActionKind.classQuizzes, classId: 2),
        ],
        classes: [_class(2, 'Still here')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Still here: Quizzes'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('drops an action the permissions no longer allow', (
    tester,
  ) async {
    final events = [
      _visit(RecentActionKind.classConduction, classId: 1),
      _visit(RecentActionKind.thisWeek),
      _visit(RecentActionKind.classQuizzes, classId: 1),
    ];
    final classes = [_class(1, 'Alpha')];

    await tester.pumpWidget(_wrap(events: events, classes: classes));
    await tester.pumpAndSettle();
    expect(find.text('Alpha: Conduction'), findsNothing);
    expect(find.text('This week'), findsNothing);
    expect(find.text('Alpha: Quizzes'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _wrap(
        events: events,
        classes: classes,
        permissions: const ['sessions:create:own', 'reports:read:all'],
        scopes: const PermissionScopes(own: [1]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alpha: Conduction'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('is hidden when there is nothing valid to show', (tester) async {
    await tester.pumpWidget(_wrap(events: const []));
    await tester.pumpAndSettle();
    expect(find.text('Jump back in'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _wrap(events: [_visit(RecentActionKind.classQuizzes, classId: 9)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jump back in'), findsNothing);
  });

  testWidgets('tapping an item opens its screen', (tester) async {
    await tester.pumpWidget(
      _wrap(
        events: [_visit(RecentActionKind.classQuizzes, classId: 4)],
        classes: [_class(4, 'Delta')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delta: Quizzes'));
    await tester.pumpAndSettle();

    expect(find.text('quizzes 4'), findsOneWidget);
  });
}
