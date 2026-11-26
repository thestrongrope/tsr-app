import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Copy link on a released MCQ (#864): offered only when the server sent a
/// link and the member may manage that class's MCQs.
void main() {
  const gentsClass = ClassModel(
    id: 10,
    code: 'CLS-10',
    name: 'Fiqh',
    level: 2,
    gender: 1,
    status: 'A',
  );
  const link = 'https://account.thestrongrope.com/mcq/AbCd1234';

  McqManageQuiz quiz({String? link}) => McqManageQuiz(
    id: 5,
    code: 'AbCd1234',
    name: 'Wudu',
    classId: 10,
    createdAt: DateTime(2026, 10, 1),
    publishedAt: link == null ? null : DateTime(2026, 10, 2),
    link: link,
  );

  Future<void> pump(
    WidgetTester tester, {
    required McqManageQuiz item,
    List<String> permissions = const ['mcqs:manage:all'],
    PermissionScopes scopes = const PermissionScopes(),
  }) async {
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
              items: [item],
            ),
          ),
        ],
        child: const MaterialApp(home: McqManageListScreen(classId: 10)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a released MCQ offers Copy link', (tester) async {
    await pump(tester, item: quiz(link: link));
    expect(find.text('Copy link'), findsOneWidget);
  });

  testWidgets('an unreleased MCQ offers no link', (tester) async {
    await pump(tester, item: quiz());
    expect(find.text('Copy link'), findsNothing);
  });

  testWidgets('no mcqs:manage on the class: no Copy link', (tester) async {
    await pump(
      tester,
      item: quiz(link: link),
      permissions: const ['mcqs:manage:assigned'],
      scopes: const PermissionScopes(assigned: [99]),
    );
    expect(find.text('Copy link'), findsNothing);
  });

  testWidgets('copying puts the link on the clipboard and says so', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, item: quiz(link: link));
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, link);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('a failed copy says so and shows the link', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, item: quiz(link: link));
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(find.text('Could not copy the link'), findsOneWidget);
    expect(find.text(link), findsOneWidget);
    expect(find.text('Link copied'), findsNothing);
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
