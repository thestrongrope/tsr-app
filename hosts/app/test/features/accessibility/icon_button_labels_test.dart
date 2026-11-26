import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/class_dashboard_screen.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_list_screen.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/home_header.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/my_classes_widget.dart';
import 'package:the_strong_rope/features/notifications/models/user_notification.dart';
import 'package:the_strong_rope/features/notifications/presentation/user_notifications_screen.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

// A screen-reader user can tell what every icon button does (#739): pump the
// main screens and fail on any tappable control that has no spoken label.

const _classId = 10;

const _class = ClassModel(
  id: _classId,
  code: 'CLS-10',
  name: 'Fiqh Basics',
  level: 2,
  levelName: 'Level 2 - Secondary',
  gender: 1,
  status: 'A',
  teacherName: 'Ustadh Ali',
  teacherMobile: '+919876543210',
  role: 'conducting',
  // A schedule makes the dashboard show its reminder-settings icon button.
  schedules: [ClassSchedule(day: 1, hour: 18, minute: 0)],
);

class _FakeClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FakeClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeNotifier extends UserNotificationsNotifier {
  @override
  UserNotificationsState build() => UserNotificationsState(
    notifications: [
      UserNotification(
        id: 1,
        title: 'Class note',
        body: 'Invented body',
        sentAt: DateTime.utc(2026, 10, 20, 10),
      ),
    ],
    hasMore: false,
  );

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}

  @override
  Future<void> fetchUnreadCount() async {}
}

/// Kept in memory: Hive's file I/O never completes inside a widget test.
class _MemoryStore extends ConductionQueueStore {
  @override
  List<QueuedConduction> read(int token) => const [];

  @override
  Future<void> write(int token, List<QueuedConduction> items) async {}
}

final _classesOverride = classesProvider.overrideWith(
  (ref) => _FakeClassesNotifier(const ClassesState(classes: [_class])),
);

/// Every tappable node in the semantics tree that has nothing to announce.
List<String> _unlabelled(WidgetTester tester) {
  final missing = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final tappable = data.hasAction(SemanticsAction.tap);
    final textField = data.flagsCollection.isTextField;
    final spoken = '${data.label}${data.tooltip}'.trim();
    if (tappable && !textField && spoken.isEmpty) {
      missing.add('node ${node.id} at ${node.rect}');
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return missing;
}

Future<void> _expectLabelled(WidgetTester tester, Widget app) async {
  final semantics = tester.ensureSemantics();
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  expect(_unlabelled(tester), isEmpty);
  semantics.dispose();
}

Widget _routed(Widget screen, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => screen)],
      ),
    ),
  );
}

void main() {
  testWidgets('Home header', (tester) async {
    await _expectLabelled(
      tester,
      _routed(
        const Scaffold(body: HomeHeader(currentUser: null)),
        overrides: [unreadNotificationCountProvider.overrideWithValue(2)],
      ),
    );
  });

  testWidgets('Home classes', (tester) async {
    await _expectLabelled(
      tester,
      _routed(
        const Scaffold(body: MyClassesWidget()),
        overrides: [_classesOverride],
      ),
    );
  });

  testWidgets('My classes', (tester) async {
    await _expectLabelled(
      tester,
      _routed(const ClassDashboardScreen(), overrides: [_classesOverride]),
    );
  });

  testWidgets('Class dashboard', (tester) async {
    await _expectLabelled(
      tester,
      _routed(
        const Scaffold(body: ClassDashboardContent(classModel: _class)),
        overrides: [_classesOverride],
      ),
    );
  });

  testWidgets('Conduction list', (tester) async {
    await _expectLabelled(
      tester,
      _routed(
        const ConductionListScreen(classId: _classId),
        overrides: [
          recentActionsMemberProvider.overrideWithValue(100),
          conductionQueueStoreProvider.overrideWithValue(_MemoryStore()),
          conductionSessionsProvider(_classId).overrideWith(
            (ref) async => ConductionListResponse(
              sessions: [
                ConductionSession(
                  id: 1,
                  conductedOn: DateTime(2026, 10, 20),
                  conducted: true,
                  editable: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });

  testWidgets('Conduction form', (tester) async {
    await _expectLabelled(
      tester,
      _routed(
        const ConductionFormScreen(classId: _classId),
        overrides: [
          syllabusTopicsProvider(
            _classId,
          ).overrideWith((ref) async => const {}),
          conductionFormDataProvider(_classId).overrideWith(
            (ref) async => const ConductionFormData(
              classInfo: ConductionClass(
                id: _classId,
                code: 'C1',
                name: 'Class',
                level: 2,
              ),
            ),
          ),
        ],
      ),
    );
  });

  testWidgets('Notifications inbox', (tester) async {
    await _expectLabelled(
      tester,
      _routed(
        const UserNotificationsScreen(),
        overrides: [userNotificationsProvider.overrideWith(_FakeNotifier.new)],
      ),
    );
  });
}
