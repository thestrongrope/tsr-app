import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/permission_grants.dart';
import 'package:the_strong_rope/features/admin/providers/permission_grants_provider.dart';
import 'package:the_strong_rope/features/admin/screens/permission_grants_screen.dart';

const _transfer = PermissionInfo(
  name: 'students:transfer:all',
  description: 'Transfer students between classes',
  reach: 'In every class and for every member',
);
const _quiz = PermissionInfo(
  name: 'quiz:admin:all',
  description: 'Administer the quiz competition',
  reach: 'In every class and for every member',
);

MemberPermissions _view({List<GrantedPermission>? granted}) =>
    MemberPermissions(
      member: const MemberRef(token: 300, name: 'Ali Member'),
      fromRole: const [
        PermissionInfo(
          name: 'reports:read:all',
          description: 'Read every report',
          reach: 'In every class and for every member',
        ),
      ],
      granted:
          granted ??
          const [
            GrantedPermission(
              id: 7,
              info: _transfer,
              reason: 'Covers the transfers desk',
              grantedBy: 'Sara Super',
              grantedAt: '2026-10-01T10:00:00',
            ),
          ],
      grantable: const [_quiz],
    );

void main() {
  group('parsing', () {
    test('the member view keeps role and granted permissions apart', () {
      final view = MemberPermissions.fromJson({
        'member': {'token': 300, 'name': 'Ali Member'},
        'fromRole': [
          {'name': 'reports:read:all', 'description': 'Read', 'reach': 'All'},
        ],
        'granted': [
          {
            'id': 7,
            'name': 'students:transfer:all',
            'description': 'Transfer',
            'reach': 'All',
            'reason': null,
            'grantedBy': null,
            'grantedAt': '2026-10-01T10:00:00',
          },
        ],
        'grantable': [],
      });

      expect(view.member.name, 'Ali Member');
      expect(view.fromRole.single.name, 'reports:read:all');
      expect(view.granted.single.id, 7);
      expect(view.granted.single.reason, isNull);
      expect(view.granted.single.info.name, 'students:transfer:all');
    });
  });

  group('member screen', () {
    late List<Map<String, Object?>> grants;
    late List<Map<String, Object?>> revokes;
    Object? failWith;
    var views = 0;

    setUp(() {
      grants = [];
      revokes = [];
      failWith = null;
      views = 0;
    });

    Widget wrap() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        memberPermissionsProvider.overrideWith((ref, token) async {
          views++;
          return _view();
        }),
        grantPermissionProvider.overrideWithValue(({
          required int token,
          required String permission,
          required String reason,
        }) async {
          grants.add({
            'token': token,
            'permission': permission,
            'reason': reason,
          });
          if (failWith != null) throw failWith!;
        }),
        revokePermissionProvider.overrideWithValue(({
          required int id,
          required String reason,
        }) async {
          revokes.add({'id': id, 'reason': reason});
          if (failWith != null) throw failWith!;
        }),
      ],
      child: const MaterialApp(home: MemberPermissionsScreen(token: 300)),
    );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
    }

    testWidgets(
      'role and granted permissions are shown apart, with who and why',
      (tester) async {
        await open(tester);

        expect(find.text('Ali Member'), findsOneWidget);
        expect(find.text('From their role'), findsOneWidget);
        expect(find.text('Read every report'), findsOneWidget);
        expect(find.text('Granted to them'), findsOneWidget);
        expect(find.text('Transfer students between classes'), findsOneWidget);
        expect(
          find.textContaining('Covers the transfers desk'),
          findsOneWidget,
        );
        expect(find.textContaining('Sara Super'), findsOneWidget);
        // Only a grant can be revoked here, not what the role gives.
        expect(find.widgetWithText(TextButton, 'Revoke'), findsOneWidget);
      },
    );

    testWidgets(
      'a grant cannot be made without a reason, then is, and the view reloads',
      (tester) async {
        await open(tester);

        await tester.tap(
          find.widgetWithText(FilledButton, 'Grant a permission'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administer the quiz competition'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('In every class and for every member'),
          findsWidgets,
        );
        final grant = find.widgetWithText(FilledButton, 'Grant');
        expect(tester.widget<FilledButton>(grant).onPressed, isNull);

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        expect(
          tester.widget<FilledButton>(grant).onPressed,
          isNull,
          reason: 'blank is not a reason',
        );

        await tester.enterText(find.byType(TextField), 'Runs the quiz cycle');
        await tester.pump();
        await tester.tap(grant);
        await tester.pumpAndSettle();

        expect(grants, [
          {
            'token': 300,
            'permission': 'quiz:admin:all',
            'reason': 'Runs the quiz cycle',
          },
        ]);
        expect(views, 2, reason: 'the member view is read again');
      },
    );

    testWidgets('a failed grant says so and leaves the view as it was', (
      tester,
    ) async {
      failWith = const ApiException(
        'The member already holds that permission',
        409,
      );
      await open(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Grant a permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Administer the quiz competition'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Because');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Grant'));
      await tester.pumpAndSettle();

      expect(
        find.text('The member already holds that permission'),
        findsOneWidget,
      );
      expect(views, 1, reason: 'nothing reloaded');
      expect(find.text('Transfer students between classes'), findsOneWidget);
    });

    testWidgets('a revoke needs a reason', (tester) async {
      await open(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Revoke');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Desk closed');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(revokes, [
        {'id': 7, 'reason': 'Desk closed'},
      ]);
      expect(views, 2);
    });
  });

  group('search screen', () {
    testWidgets('searches from two characters and lists names only', (
      tester,
    ) async {
      final asked = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            memberSearchProvider.overrideWithValue((q) async {
              asked.add(q);
              return const [MemberRef(token: 300, name: 'Ali Member')];
            }),
          ],
          child: const MaterialApp(home: PermissionGrantsScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(asked, isEmpty);

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(asked, ['ali']);
      expect(find.text('Ali Member'), findsOneWidget);
    });
  });
}
