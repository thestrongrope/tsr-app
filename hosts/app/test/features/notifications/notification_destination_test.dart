import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/router/app_router.dart';
import 'package:the_strong_rope/core/services/notification_service.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/notifications/models/user_notification.dart';
import 'package:the_strong_rope/features/notifications/providers/notification_target.dart';

const _none = NotificationDestination.none();

NotificationDestination _link(String link) =>
    NotificationDestination.link(link);

UserNotification _row(String? link, {List<int> classes = const []}) =>
    UserNotification(
      id: 1,
      title: 'Invented title',
      body: 'Invented body',
      actionLink: link,
      sentAt: DateTime.utc(2026, 10, 20, 10),
      classes: [
        for (final id in classes) NotificationClass(id: id, name: 'C$id'),
      ],
    );

void main() {
  group('a tapped push', () {
    final cases = <String, (Map<String, dynamic>, NotificationDestination)>{
      'admin announcement': (
        {'type': 'admin_announcement'},
        _link('/notifications'),
      ),
      'quiz released': (
        {'type': 'quiz_released', 'quiz_id': '7'},
        _link('/quizzes/7'),
      ),
      'quiz released, no id': (
        {'type': 'quiz_released'},
        _link('/notifications'),
      ),
      'quiz released, bad id': (
        {'type': 'quiz_released', 'quiz_id': 'x'},
        _link('/notifications'),
      ),
      'class reminder': (
        {'type': 'class_reminder', 'class_id': '5'},
        _link('/classes/5/dashboard'),
      ),
      'class reminder, no class': (
        {'type': 'class_reminder'},
        _link('/classes'),
      ),
      'after-class reminder opens a new record': (
        {'type': 'conduction_reminder', 'class_id': '5'},
        _link('/classes/5/conduction/add'),
      ),
      'after-class reminder, no class': (
        {'type': 'conduction_reminder'},
        _link('/classes'),
      ),
      'class announcement': (
        {'type': 'class_announcement', 'class_id': '5'},
        _link('/classes/5/dashboard'),
      ),
      'class announcement, no class': (
        {'type': 'class_announcement'},
        _link('/notifications'),
      ),
      'pending forms, one class': (
        {'type': 'cc_reminder', 'class_ids': '8'},
        _link('/classes/8/conduction'),
      ),
      'pending forms, several classes': (
        {'type': 'cc_reminder', 'class_ids': '8,9'},
        const NotificationDestination.chooseClass([8, 9]),
      ),
      'pending forms, repeated and junk ids': (
        {'type': 'cc_reminder', 'class_ids': '8, 8,x,'},
        _link('/classes/8/conduction'),
      ),
      'pending forms, no classes': ({'type': 'cc_reminder'}, _none),
      'pending forms, only odd ids': (
        {'type': 'cc_reminder', 'class_ids': '-5,+5,0x10,0'},
        _none,
      ),
      'quiz announcement': ({'type': 'quiz_announcement'}, _link('/home/quiz')),
      'quiz announcement with its link': (
        {'type': 'quiz_announcement', 'action_link': '/home/quiz'},
        _link('/home/quiz'),
      ),
      'a signed class id is not a class': (
        {'type': 'class_reminder', 'class_id': '-5'},
        _link('/classes'),
      ),
      'a plus-signed class id is not a class': (
        {'type': 'conduction_reminder', 'class_id': '+5'},
        _link('/classes'),
      ),
      'a hex class id is not a class': (
        {'type': 'class_announcement', 'class_id': '0x10'},
        _link('/notifications'),
      ),
      'a padded quiz id is not a quiz': (
        {'type': 'quiz_released', 'quiz_id': ' 7'},
        _link('/notifications'),
      ),
      'class id zero is not a class': (
        {'type': 'class_reminder', 'class_id': '0'},
        _link('/classes'),
      ),
      'a number where text belongs is ignored': (
        {'type': 'conduction_reminder', 'class_id': 5},
        _link('/classes'),
      ),
      'a list where text belongs is ignored': (
        {
          'type': 'cc_reminder',
          'class_ids': [8, 9],
        },
        _none,
      ),
      'a type that is not text is ignored': ({'type': 3}, _none),
      'unknown type': ({'type': 'something_new'}, _none),
      'no type': (<String, dynamic>{}, _none),
      'allowed action link wins': (
        {'type': 'admin_announcement', 'action_link': '/articles/a-b'},
        _link('/articles/a-b'),
      ),
      'refused action link falls back to the type': (
        {
          'type': 'class_reminder',
          'class_id': '5',
          'action_link': 'https://evil.example/x',
        },
        _link('/classes/5/dashboard'),
      ),
      'empty action link is absent': (
        {'type': 'admin_announcement', 'action_link': ''},
        _link('/notifications'),
      ),
    };

    cases.forEach((name, c) {
      test(name, () => expect(pushDestination(c.$1), c.$2));
    });
  });

  group('a notification in the list', () {
    test('a link opens it', () {
      expect(
        historyDestination(_row('/classes/5/dashboard')),
        _link('/classes/5/dashboard'),
      );
    });

    test('a refused link shows the text', () {
      expect(historyDestination(_row('https://example.com/x')), _none);
    });

    test('a refused link shows the text even when classes are present', () {
      expect(
        historyDestination(_row('https://example.com/x', classes: [8])),
        _none,
      );
    });

    test('no link and no classes shows the text', () {
      expect(historyDestination(_row(null)), _none);
    });

    test('one class opens its conduction records', () {
      expect(
        historyDestination(_row(null, classes: [8])),
        _link('/classes/8/conduction'),
      );
    });

    test('a class id that is not positive is left out', () {
      expect(
        historyDestination(_row(null, classes: [0, -3, 8])),
        _link('/classes/8/conduction'),
      );
    });

    test('several classes need the chooser', () {
      expect(
        historyDestination(_row(null, classes: [8, 9])),
        const NotificationDestination.chooseClass([8, 9]),
      );
    });

    test('push and list agree on the same pending-forms reminder', () {
      expect(
        historyDestination(_row(null, classes: [8, 9])),
        pushDestination({'type': 'cc_reminder', 'class_ids': '8,9'}),
      );
    });
  });

  group('a tapped notification opens through the shared opener', () {
    NotificationTap tap(Map<String, dynamic> data) =>
        NotificationTap(data: data, title: 'Pushed title', body: 'Pushed body');

    Future<List<String>> pump(
      WidgetTester tester, {
      required _FakeSource source,
      NotificationTarget target = NotificationTarget.open,
      List<ClassModel>? classes,
      ValueNotifier<bool>? starting,
      bool settle = true,
    }) async {
      final checked = <String>[];
      // '/' is the splash screen; a started app rests on Home.
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/',
        refreshListenable: starting,
        redirect: (_, state) {
          final onSplash = state.matchedLocation == '/';
          if (starting?.value ?? false) return onSplash ? null : '/';
          return onSplash ? '/home' : null;
        },
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('splash')),
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/classes/:id/conduction',
            builder: (_, state) =>
                Text('conduction ${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/classes/:id/conduction/add',
            builder: (_, state) => Text('add ${state.pathParameters['id']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationTapSourceProvider.overrideWithValue(source),
            notificationTargetCheckerProvider.overrideWithValue((link) async {
              checked.add(link);
              return target;
            }),
            if (classes != null)
              classesProvider.overrideWith(
                (ref) => _FixedClasses(ClassesState(classes: classes)),
              ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(notificationTapProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      if (settle) await tester.pumpAndSettle();
      return checked;
    }

    testWidgets('a cold-start tap waits for the app to leave the splash', (
      tester,
    ) async {
      final starting = ValueNotifier(true);
      final source = _FakeSource()
        ..pending = tap({'type': 'conduction_reminder', 'class_id': '5'});
      final checked = await pump(
        tester,
        source: source,
        starting: starting,
        settle: false,
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('splash'), findsOneWidget);
      expect(checked, isEmpty);

      starting.value = false;
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('add 5'), findsOneWidget);
      expect(checked, ['/classes/5/conduction/add']);
    });

    testWidgets('the chooser names a pushed class by its cached code', (
      tester,
    ) async {
      final source = _FakeSource()
        ..pending = tap({'type': 'cc_reminder', 'class_ids': '8,9'});
      await pump(tester, source: source, classes: [_class(8, 'GA-08')]);

      expect(find.text('GA-08'), findsOneWidget);
      expect(find.text('Class 9'), findsOneWidget);
      expect(find.text('Class 8'), findsNothing);
    });

    testWidgets('a tap that arrived before the listener is replayed', (
      tester,
    ) async {
      final source = _FakeSource()
        ..pending = tap({'type': 'conduction_reminder', 'class_id': '5'});
      final checked = await pump(tester, source: source);

      expect(find.text('add 5'), findsOneWidget);
      expect(checked, ['/classes/5/conduction/add']);
      expect(source.pending, isNull);
    });

    testWidgets('a tap while the app runs opens its target', (tester) async {
      final source = _FakeSource();
      await pump(tester, source: source);

      source.controller.add(tap({'type': 'cc_reminder', 'class_ids': '8'}));
      await tester.pumpAndSettle();

      expect(find.text('conduction 8'), findsOneWidget);
    });

    testWidgets('a gone target shows the push text and the reason', (
      tester,
    ) async {
      final source = _FakeSource()
        ..pending = tap({'type': 'cc_reminder', 'class_ids': '8'});
      await pump(tester, source: source, target: NotificationTarget.gone);

      expect(find.text('conduction 8'), findsNothing);
      expect(find.text('Pushed title'), findsOneWidget);
      expect(find.text('Pushed body'), findsOneWidget);
      expect(find.text('This is no longer available.'), findsOneWidget);
    });

    testWidgets('a class with no access says so and shows the text', (
      tester,
    ) async {
      final source = _FakeSource()
        ..pending = tap({'type': 'cc_reminder', 'class_ids': '8'});
      await pump(tester, source: source, target: NotificationTarget.noAccess);

      expect(find.text('You do not have access to this.'), findsOneWidget);
      expect(find.text('Pushed body'), findsOneWidget);
    });

    testWidgets('a pending-forms push for several classes shows the chooser', (
      tester,
    ) async {
      final source = _FakeSource()
        ..pending = tap({'type': 'cc_reminder', 'class_ids': '8,9'});
      final checked = await pump(tester, source: source);

      expect(find.text('Choose a class'), findsOneWidget);
      expect(find.text('Class 8'), findsOneWidget);
      expect(checked, isEmpty);

      await tester.tap(find.text('Class 9'));
      await tester.pumpAndSettle();

      expect(find.text('conduction 9'), findsOneWidget);
      expect(checked, ['/classes/9/conduction']);
    });

    testWidgets('a push with nothing to open shows its text', (tester) async {
      final source = _FakeSource()..pending = tap({'type': 'something_new'});
      final checked = await pump(tester, source: source);

      expect(find.text('Pushed body'), findsOneWidget);
      expect(checked, isEmpty);
    });
  });
}

class _FixedClasses extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClasses(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClassModel _class(int id, String code) => ClassModel(
  id: id,
  code: code,
  name: 'Invented $id',
  level: 1,
  levelName: 'L1',
  gender: 1,
  status: 'A',
);

class _FakeSource implements NotificationTapSource {
  final controller = StreamController<NotificationTap>.broadcast();
  NotificationTap? pending;

  @override
  Stream<NotificationTap> get taps => controller.stream;

  @override
  NotificationTap? takePendingTap() {
    final tap = pending;
    pending = null;
    return tap;
  }
}
