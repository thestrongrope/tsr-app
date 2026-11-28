import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_manage.dart';
import 'package:the_strong_rope/features/mcq_manage/providers/mcq_manage_provider.dart';
import 'package:the_strong_rope/features/mcq_manage/screens/mcq_manage_list_screen.dart';

/// The Copy action on a quiz follows `mcqs:copy` on the class, as the server
/// does (#676): managing the class's MCQs is not enough.
void main() {
  const gentsClass = ClassModel(
    id: 10,
    code: 'CLS-10',
    name: 'Fiqh',
    level: 2,
    gender: 1,
    status: 'A',
  );
  final quiz = McqManageQuiz(
    id: 5,
    code: 'Q 1',
    name: 'Wudu',
    classId: 10,
    createdAt: DateTime(2026, 10, 1),
  );

  Future<void> pump(
    WidgetTester tester,
    List<String> permissions,
    PermissionScopes scopes,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionsProvider.overrideWith(
            (ref) => _FixedPermissions(permissions, scopes),
          ),
          classesProvider.overrideWith(
            (ref) =>
                _FakeClassesNotifier(const ClassesState(classes: [gentsClass])),
          ),
          mcqManageListProvider(10).overrideWith(
            (ref) async => McqManageListResponse(
              total: 1,
              page: 1,
              pageSize: 20,
              hasNext: false,
              items: [quiz],
            ),
          ),
        ],
        child: const MaterialApp(home: McqManageListScreen(classId: 10)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a manager without the copy permission sees no Copy', (
    tester,
  ) async {
    await pump(tester, const [
      'mcqs:manage:own',
    ], const PermissionScopes(own: [10]));
    expect(find.text('Scores'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('copy permission on the class shows Copy', (tester) async {
    await pump(tester, const [
      'mcqs:manage:all',
      'mcqs:copy:all',
    ], const PermissionScopes());
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a gender admin sees Copy for a class of their gender', (
    tester,
  ) async {
    await pump(tester, const [
      'mcqs:manage:all',
      'mcqs:copy:gender',
    ], const PermissionScopes(gender: 1));
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a gender admin sees no Copy on the other gender', (
    tester,
  ) async {
    await pump(tester, const [
      'mcqs:manage:all',
      'mcqs:copy:gender',
    ], const PermissionScopes(gender: 2));
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('copy assigned to another class does not show Copy', (
    tester,
  ) async {
    await pump(tester, const [
      'mcqs:manage:all',
      'mcqs:copy:assigned',
    ], const PermissionScopes(assigned: [99]));
    expect(find.text('Copy'), findsNothing);
  });
}

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

class _FakeClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FakeClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
