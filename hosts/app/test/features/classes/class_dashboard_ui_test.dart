import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/notification_settings_provider.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/class_dashboard_screen.dart';
import 'package:the_strong_rope/features/classes/widgets/class_notification_settings_sheet.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/my_classes_widget.dart';

void main() {
  const testClass = ClassModel(
    id: 10,
    code: 'CLS-10',
    name: 'Fiqh Basics',
    level: 2,
    levelName: 'Level 2 - Secondary',
    gender: 1,
    status: 'A',
    teacherName: 'Ustadh Ali',
    teacherMobile: '+919876543210',
  );

  group('Home class order', () {
    ClassModel cls(int id, String? role) => ClassModel(
      id: id,
      code: 'C$id',
      name: 'n$id',
      level: 1,
      levelName: 'L$id',
      gender: 1,
      status: 'A',
      role: role,
    );

    Future<void> pumpHome(WidgetTester tester, List<ClassModel> classes) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionsProvider.overrideWith(
              (ref) => _FixedPermissions(const [], const PermissionScopes()),
            ),
            classesProvider.overrideWith(
              (ref) => _FakeClassesNotifier(ClassesState(classes: classes)),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MyClassesWidget())),
        ),
      );
      await tester.pumpAndSettle();
    }

    test('orders attended, then conducted, then managed', () {
      final ordered = orderForHome([
        cls(1, 'managing'),
        cls(2, 'conducting'),
        cls(3, 'attending'),
        cls(4, null),
      ]);
      expect(ordered.map((c) => c.id), [3, 4, 2, 1]);
    });

    testWidgets('shows the first two in order and offers the full list', (
      tester,
    ) async {
      await pumpHome(tester, [
        cls(1, 'managing'),
        cls(2, 'conducting'),
        cls(3, 'attending'),
      ]);
      expect(find.text('L3'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('L1'), findsNothing);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Attending'), findsOneWidget);
      expect(find.text('Conducting'), findsOneWidget);
      expect(find.text('Managing'), findsNothing);
    });

    testWidgets('two classes of one kind: one label, no full list', (
      tester,
    ) async {
      await pumpHome(tester, [cls(1, 'conducting'), cls(2, 'conducting')]);
      expect(find.text('Conducting'), findsOneWidget);
      expect(find.text('Attending'), findsNothing);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('no classes says so', (tester) async {
      await pumpHome(tester, []);
      expect(find.text('No Classes Yet'), findsOneWidget);
    });
  });

  testWidgets('Home screen class card shows class level and class code', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith(
            (ref) =>
                _FakeClassesNotifier(const ClassesState(classes: [testClass])),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MyClassesWidget())),
      ),
    );
    await tester.pumpAndSettle();

    // Verifies class level and class code are shown, not class name
    expect(find.text('Level 2 - Secondary'), findsOneWidget);
    expect(find.text('CLS-10'), findsOneWidget);
    expect(find.text('Ustadh Ali'), findsOneWidget);
    expect(find.text('Fiqh Basics'), findsNothing);
  });

  testWidgets(
    'Class dashboard displays class level as title and teacher name followed by number',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classesProvider.overrideWith(
              (ref) => _FakeClassesNotifier(
                const ClassesState(classes: [testClass]),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ClassDashboardContent(classModel: testClass)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header card displays class level as headline, class code in badge
      expect(find.text('Level 2 - Secondary'), findsOneWidget);
      expect(find.text('CLS-10'), findsOneWidget);

      // Class Details info card displays teacher name followed by number
      expect(find.text('Ustadh Ali (+919876543210)'), findsOneWidget);
    },
  );

  testWidgets(
    'Class notification settings sheet shows teacher & class admin in toggle and subtext',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSettingsProvider.overrideWith(
              _FakeNotificationSettingsNotifier.new,
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showClassNotificationSettings(
                    context,
                    ref,
                    hasConductingClasses: true,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify conduction toggle title and subtext
      expect(
        find.text('Class Conduction Reminder (Teacher & Class Admin)'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Reminder for teachers and class admins to log session report 45 minutes after class begins',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Share Join Link shows only when the class has a joinUrl', (
    tester,
  ) async {
    Future<void> pumpDashboard(ClassModel cls) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classesProvider.overrideWith(
              (ref) => _FakeClassesNotifier(ClassesState(classes: [cls])),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ClassDashboardContent(classModel: cls)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A student: the server sends no joinUrl.
    await pumpDashboard(testClass);
    expect(find.text('Share Join Link'), findsNothing);

    // The class teacher: the server sends joinUrl.
    await pumpDashboard(
      testClass.copyWith(
        role: 'conducting',
        joinUrl: 'https://account.thestrongrope.com?c=test-link',
      ),
    );
    expect(find.text('Share Join Link'), findsOneWidget);
  });

  group('the schedule and details cards open the editor (#797)', () {
    const ladiesClass = ClassModel(
      id: 20,
      code: 'CLS-20',
      name: 'Ladies',
      level: 2,
      gender: 2,
      status: 'A',
    );

    var chevrons = 0; // cards showing a chevron before the tap

    // Pumps the dashboard under a router and answers where a tap on [card] went.
    Future<String?> tapCard(
      WidgetTester tester,
      ClassModel cls,
      _FixedPermissions permissions,
      String card,
    ) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      String? went;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: ClassDashboardContent(classModel: cls)),
          ),
          GoRoute(
            path: '/classes/:id/:screen',
            builder: (context, state) {
              went = state.uri.toString();
              return const Scaffold();
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionsProvider.overrideWith((ref) => permissions),
            classesProvider.overrideWith(
              (ref) => _FakeClassesNotifier(ClassesState(classes: [cls])),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      chevrons = find.byIcon(Icons.chevron_right_rounded).evaluate().length;
      await tester.tap(find.text(card));
      await tester.pumpAndSettle();
      return went;
    }

    // A fresh notifier per use: a pumped-away one is disposed.
    _FixedPermissions editor() => _FixedPermissions(const [
      'classes:update:gender',
    ], const PermissionScopes(gender: 2));
    _FixedPermissions teacher() => _FixedPermissions(const [
      'classes:schedule:own',
    ], const PermissionScopes(own: [10]));

    testWidgets('an editor opens details or schedule from its own card', (
      tester,
    ) async {
      expect(
        await tapCard(tester, ladiesClass, editor(), 'Class Schedule'),
        '/classes/20/manage?tab=schedule',
      );
      await tester.pumpWidget(const SizedBox());
      expect(
        await tapCard(tester, ladiesClass, editor(), 'Class Details'),
        '/classes/20/manage',
      );
    });

    testWidgets('the class teacher or MCQ admin opens only the schedule', (
      tester,
    ) async {
      expect(
        await tapCard(tester, testClass, teacher(), 'Class Schedule'),
        '/classes/10/schedule',
      );
      await tester.pumpWidget(const SizedBox());
      expect(
        await tapCard(tester, testClass, teacher(), 'Class Details'),
        '/classes/10/schedule',
      );
    });

    testWidgets('a gender admin of the other gender cannot edit', (
      tester,
    ) async {
      expect(
        await tapCard(tester, testClass, editor(), 'Class Details'),
        isNull,
      );
    });

    testWidgets('without edit permission the cards look inert', (tester) async {
      final student = _FixedPermissions(const [
        'classes:read:enrolled',
      ], const PermissionScopes(enrolled: [10]));
      expect(
        await tapCard(tester, testClass, student, 'Class Details'),
        isNull,
      );
      expect(chevrons, 0);
    });

    testWidgets('whoever can edit sees both cards as tappable', (tester) async {
      await tapCard(tester, testClass, teacher(), 'Class Details');
      expect(chevrons, 2);
    });
  });

  group('staff tiles follow the permission model, per class', () {
    const teacherPermissions = [
      'sessions:create:own',
      'mcqs:manage:own',
      'notifications:send:own',
    ];
    const otherClass = ClassModel(
      id: 11,
      code: 'CLS-11',
      name: 'Other',
      level: 2,
      gender: 1,
      status: 'A',
    );
    const ladiesClass = ClassModel(
      id: 20,
      code: 'CLS-20',
      name: 'Ladies',
      level: 2,
      gender: 2,
      status: 'A',
    );

    Future<void> pumpDashboard(
      WidgetTester tester,
      ClassModel cls,
      _FixedPermissions permissions,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionsProvider.overrideWith((ref) => permissions),
            classesProvider.overrideWith(
              (ref) => _FakeClassesNotifier(ClassesState(classes: [cls])),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ClassDashboardContent(classModel: cls)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'teacher of this class sees both tiles; another class neither',
      (tester) async {
        final teacher = _FixedPermissions(
          teacherPermissions,
          const PermissionScopes(own: [10], taught: [10]),
        );

        await pumpDashboard(tester, testClass, teacher);
        expect(find.text('Class Conduction'), findsOneWidget);
        expect(find.text('MCQ Management'), findsOneWidget);
        expect(find.text('Class Notification'), findsOneWidget);
        expect(find.text('Student Performance'), findsOneWidget);

        await pumpDashboard(tester, otherClass, teacher);
        expect(find.text('Class Conduction'), findsNothing);
        expect(find.text('MCQ Management'), findsNothing);
        expect(find.text('Class Notification'), findsNothing);
        expect(find.text('Student Performance'), findsNothing);
      },
    );

    testWidgets(
      'the list calls the member the conductor but the grant has no '
      'sessions:create: the badge follows the list, the tile the grant',
      (tester) async {
        const conducting = ClassModel(
          id: 10,
          code: 'CLS-10',
          name: 'Fiqh Basics',
          level: 2,
          gender: 1,
          status: 'A',
          role: 'conducting',
        );
        final staleGrant = _FixedPermissions(
          const ['notifications:send:own'],
          const PermissionScopes(own: [10], taught: [10]),
        );

        await pumpDashboard(tester, conducting, staleGrant);

        expect(conducting.isConducting, isTrue);
        expect(find.text('Class Conduction'), findsNothing);
        expect(find.text('Class Notification'), findsOneWidget);
      },
    );

    testWidgets(
      'Class Schedule is for the class\'s teacher and MCQ admin, not for managers',
      (tester) async {
        const tile = 'Set the day and time of your class';
        final mcqAdmin = _FixedPermissions(const [
          'classes:schedule:own',
          'class-students:read:own',
        ], const PermissionScopes(own: [10]));
        await pumpDashboard(tester, testClass, mcqAdmin);
        expect(find.text(tile), findsOneWidget);
        await pumpDashboard(tester, otherClass, mcqAdmin);
        expect(find.text(tile), findsNothing);

        // A fresh scope per persona, or the first one's permissions stick.
        // Whoever may edit the class has the schedule inside Manage Class.
        await tester.pumpWidget(const SizedBox());
        final coordinator = _FixedPermissions(const [
          'classes:update:assigned',
          'class-students:read:assigned',
        ], const PermissionScopes(assigned: [10]));
        await pumpDashboard(
          tester,
          testClass.copyWith(role: 'managing'),
          coordinator,
        );
        expect(find.text('Edit class'), findsOneWidget);
        expect(find.text(tile), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await pumpDashboard(
          tester,
          testClass,
          _FixedPermissions(const [
            'classes:read:enrolled',
          ], const PermissionScopes(enrolled: [10])),
        );
        expect(find.text(tile), findsNothing);
      },
    );

    testWidgets('gender admin sees their gender\'s classes only', (
      tester,
    ) async {
      final gentsAdmin = _FixedPermissions(const [
        'sessions:create:gender',
        'mcqs:manage:all',
        'notifications:send:gender',
      ], const PermissionScopes(gender: 1));

      await pumpDashboard(tester, testClass, gentsAdmin);
      expect(find.text('Class Conduction'), findsOneWidget);
      expect(find.text('Class Notification'), findsOneWidget);

      await pumpDashboard(tester, ladiesClass, gentsAdmin);
      expect(find.text('Class Conduction'), findsNothing);
      expect(find.text('Class Notification'), findsNothing);
    });

    testWidgets('a student sees none of the staff tiles', (tester) async {
      await pumpDashboard(
        tester,
        testClass,
        _FixedPermissions(const [
          'classes:read:enrolled',
        ], const PermissionScopes(enrolled: [10])),
      );
      expect(find.text('Class Conduction'), findsNothing);
      expect(find.text('MCQ Management'), findsNothing);
      expect(find.text('Class Notification'), findsNothing);
      expect(find.text('Student Performance'), findsNothing);
      expect(find.text('Take Quiz'), findsOneWidget);
    });

    testWidgets('a managing class shows the staff view, not the student view', (
      tester,
    ) async {
      final managing = testClass.copyWith(role: 'managing');
      final coordinator = _FixedPermissions(const [
        'sessions:create:assigned',
        'mcqs:manage:assigned',
      ], const PermissionScopes(assigned: [10]));

      await pumpDashboard(tester, managing, coordinator);
      expect(find.text('Class Conduction'), findsOneWidget);
      expect(find.text('Take Quiz'), findsNothing);
      expect(find.text('Performance Overview'), findsNothing);
    });
  });

  testWidgets('Class dashboard has a Guide card that opens the class guide', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: ClassDashboardContent(classModel: testClass),
            ),
          ),
        ),
        GoRoute(
          path: '/classes/:classId/guide',
          builder: (context, state) =>
              Text('guide for ${state.pathParameters['classId']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith(
            (ref) =>
                _FakeClassesNotifier(const ClassesState(classes: [testClass])),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guide'));
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();

    expect(find.text('guide for 10'), findsOneWidget);
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

class _FakeNotificationSettingsNotifier extends Notifier<NotificationSettings>
    implements NotificationSettingsNotifier {
  @override
  NotificationSettings build() {
    return const NotificationSettings(
      classReminderEnabled: true,
      conductionReminderEnabled: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
