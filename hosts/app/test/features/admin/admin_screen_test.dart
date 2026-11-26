import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/widgets/permissions_stale_notice.dart';
import 'package:the_strong_rope/core/widgets/skeleton_box.dart';
import 'package:the_strong_rope/features/admin/screens/admin_screen.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions, {PermissionScopes? scopes}) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: scopes ?? const PermissionScopes(),
        issuedAt: '',
      ),
    );
  }
}

class _Navigated extends PermissionsNotifier {
  _Navigated(List<String> permissions, {required bool manage}) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 5,
        permissions: permissions,
        issuedAt: '',
        revision: '0123456789abcdef',
        navigation: PermissionsNavigation(classes: false, manage: manage),
      ),
    );
  }
}

class _Unanswered extends PermissionsNotifier {
  _Unanswered() {
    state = const PermissionsState(unconfirmed: true, error: 'offline');
  }

  int fetches = 0;

  @override
  Future<void> fetchAndSave() async => fetches++;
}

Future<void> _pump(WidgetTester tester, Widget screen, PermissionsNotifier p) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [permissionsProvider.overrideWith((ref) => p)],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => screen)],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('with no answer yet the error view shows, and Retry asks again', (
    tester,
  ) async {
    final permissions = _Unanswered();
    await _pump(tester, const AdminScreen(), permissions);
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('No administrative modules'), findsNothing);

    await tester.tap(find.text('Retry'));
    expect(permissions.fetches, 1);
  });

  testWidgets('a stale copy keeps the tools and shows the notice', (
    tester,
  ) async {
    final permissions = _FixedPermissions(const ['syllabus:update:all']);
    permissions.state = permissions.state.copyWith(
      stale: true,
      error: 'offline',
    );
    await _pump(tester, const AdminScreen(), permissions);
    await tester.pumpAndSettle();

    expect(find.text('Syllabus Management'), findsOneWidget);
    expect(find.text(PermissionsStaleNotice.message), findsOneWidget);
  });

  testWidgets(
    'the server hiding Manage wins over a tool the copy still holds',
    (tester) async {
      await _pump(
        tester,
        const AdminScreen(),
        _Navigated(const ['syllabus:update:all'], manage: false),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No administrative modules'), findsOneWidget);
      expect(find.text('Syllabus Management'), findsNothing);
    },
  );

  testWidgets('the server showing Manage with no tool left shows the message', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _Navigated(const <String>[], manage: true),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No administrative modules'), findsOneWidget);
  });

  testWidgets('the server showing Manage lists the tools the copy holds', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _Navigated(const ['syllabus:update:all'], manage: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Syllabus Management'), findsOneWidget);
    expect(find.text('Donors'), findsNothing);
  });

  const superAdmin = [
    'notifications:broadcast:all',
    'syllabus:update:all',
    'notifications:send:all',
    'sessions:create:all',
  ];

  testWidgets('super admin sees every module on the admin screen', (
    tester,
  ) async {
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Syllabus Management'), findsOneWidget);
  });

  testWidgets('only whoever may read reports sees the This week row, first', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'reports:read:gender']),
    );
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('This week')).dy,
      lessThan(tester.getTopLeft(find.text('Notifications')).dy),
    );

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsNothing);
  });

  testWidgets('only whoever may manage deactivated classes sees that card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'deactivated-classes:manage:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deactivated Classes'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Deactivated Classes'), findsNothing);
  });

  testWidgets('only whoever may admin the quiz sees that card', (tester) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'quiz:admin:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quiz admin'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'quiz:reset:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quiz admin'), findsNothing, reason: 'reset is not admin');
  });

  testWidgets('only whoever may read the access log sees that card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['audit-log:read:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access log'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Access log'), findsNothing);
  });

  testWidgets('only whoever may update the Standard MCQs sees that card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['standard-mcqs:update:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update MCQs'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Update MCQs'), findsNothing);
  });

  testWidgets('only whoever may copy MCQs sees the Copy MCQ card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['mcqs:copy:gender']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy MCQ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'mcqs:manage:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy MCQ'), findsNothing, reason: 'manage is not copy');
  });

  testWidgets('only whoever may manage guides sees that card', (tester) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['guides:manage:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guides'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Guides'), findsNothing);
  });

  testWidgets('only whoever may manage WhatsApp reminders sees that card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'whatsapp:manage:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp Reminders'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp Reminders'), findsNothing);
  });

  testWidgets('only whoever holds teachers:read sees the Teachers card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([...superAdmin, 'teachers:read:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Teachers'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Teachers'), findsNothing);
  });

  testWidgets('Finance, holding only donors:read, gets the Donors card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['donors:read:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Donors'), findsOneWidget);
    expect(find.textContaining('No administrative modules'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Donors'), findsNothing);
  });

  testWidgets('whoever manages deletion requests gets the queue card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['deletion-requests:manage:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deletion requests'), findsOneWidget);
    expect(find.textContaining('No administrative modules'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Deletion requests'), findsNothing);
  });

  testWidgets('a ladies admin has no broadcast module', (tester) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions([
        'notifications:send:gender',
        'sessions:create:gender',
        'classes:read:gender',
      ], scopes: const PermissionScopes(gender: 2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Syllabus Management'), findsNothing);
  });

  testWidgets('syllabus-only admin sees syllabus but not notifications', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['syllabus:update:all']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Syllabus Management'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
  });

  testWidgets('tools sit under labelled groups, empty groups are hidden', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['reports:read:gender', 'donors:read:all']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monitoring'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Communication'), findsNothing);
    expect(find.text('Administration'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Reports')).dy,
      lessThan(tester.getTopLeft(find.text('Donors')).dy),
    );
  });

  testWidgets('a member with no admin module sees an empty message', (
    tester,
  ) async {
    await _pump(tester, const AdminScreen(), _FixedPermissions(const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('No administrative modules'), findsOneWidget);
  });

  testWidgets('while permissions load the hub shows a skeleton', (
    tester,
  ) async {
    final loading = _FixedPermissions(const []);
    loading.state = const PermissionsState(isLoading: true);
    await _pump(tester, const AdminScreen(), loading);
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('a failed load shows a message and Retry', (tester) async {
    final failed = _FixedPermissions(const []);
    failed.state = const PermissionsState(error: 'boom');
    await _pump(tester, const AdminScreen(), failed);
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('only whoever holds feedback:review sees the Feedback card', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminScreen(),
      _FixedPermissions(['feedback:review:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text('Review submitted member feedback'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const AdminScreen(), _FixedPermissions(superAdmin));
    await tester.pumpAndSettle();
    expect(find.text('Feedback'), findsNothing);
  });
}
