import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/notifications/models/user_notification.dart';
import 'package:the_strong_rope/features/notifications/presentation/user_notifications_screen.dart';
import 'package:the_strong_rope/features/notifications/providers/notification_target.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

import '../../support/content_width.dart';

/// Serves the given rows and never reaches the network.
class _FakeNotifier extends UserNotificationsNotifier {
  _FakeNotifier(
    this.items, {
    this.isSavedCopy = false,
    this.read,
    this.failMarking = false,
  });

  final bool failMarking;

  final List<UserNotification> items;
  final List<int>? read;
  final bool isSavedCopy;

  @override
  UserNotificationsState build() => UserNotificationsState(
    notifications: items,
    hasMore: false,
    isSavedCopy: isSavedCopy,
  );

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}

  @override
  Future<void> fetchUnreadCount() async {}

  @override
  Future<bool> markAsRead(int notificationId) async {
    if (failMarking) return false;
    read?.add(notificationId);
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications)
          n.id == notificationId ? n.copyWith(isRead: true) : n,
      ],
    );
    return true;
  }

  @override
  Future<bool> markAllAsRead() async {
    if (failMarking) return false;
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications) n.copyWith(isRead: true),
      ],
    );
    return true;
  }
}

UserNotification _row(
  String title,
  String? link, {
  List<NotificationClass> classes = const [],
  bool isRead = false,
}) => UserNotification(
  isRead: isRead,
  id: title.hashCode,
  title: title,
  body: 'Invented body for $title',
  actionLink: link,
  sentAt: DateTime.utc(2026, 10, 20, 10),
  classes: classes,
);

Future<void> _open(
  WidgetTester tester,
  List<UserNotification> rows, {
  bool failMarking = false,
  double width = 400,
  bool isSavedCopy = false,
  NotificationTarget target = NotificationTarget.open,
  List<int>? read,
  List<String>? checked,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const UserNotificationsScreen(),
      ),
      GoRoute(
        path: '/classes/:id/dashboard',
        builder: (context, state) =>
            Text('class dashboard ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/classes/:id/conduction',
        builder: (context, state) =>
            Text('class conduction ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/quizzes/:id',
        builder: (context, state) => Text('quiz ${state.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userNotificationsProvider.overrideWith(
          () => _FakeNotifier(
            rows,
            isSavedCopy: isSavedCopy,
            read: read,
            failMarking: failMarking,
          ),
        ),
        notificationTargetCheckerProvider.overrideWithValue((link) async {
          checked?.add(link);
          return target;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

const _savedLine =
    'Showing saved notifications. Pull to refresh when you are back online.';

FontWeight? _titleWeight(WidgetTester tester, String title) =>
    tester.widget<Text>(find.text(title).first).style?.fontWeight;

void main() {
  for (final size in [tabletLandscape, tabletPortrait]) {
    testWidgets('on a $size tablet the inbox is capped and centred', (
      tester,
    ) async {
      await _open(tester, [_row('Fresh', null)]);
      setWindow(tester, size);
      await tester.pumpAndSettle();

      expectContentCapped(tester);
    });
  }

  testWidgets('unread rows have a dot and a bold title; read rows neither', (
    tester,
  ) async {
    await _open(tester, [_row('Fresh', null), _row('Old', null, isRead: true)]);

    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
    expect(_titleWeight(tester, 'Fresh'), FontWeight.bold);
    expect(_titleWeight(tester, 'Old'), isNot(FontWeight.bold));
  });

  testWidgets('opening an unread notification shows it as read', (
    tester,
  ) async {
    await _open(tester, [_row('Fresh', null)]);

    await tester.tap(find.text('Fresh'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unread-dot')), findsNothing);
    expect(_titleWeight(tester, 'Fresh'), isNot(FontWeight.bold));
  });

  testWidgets('Mark all as read shows every notification as read', (
    tester,
  ) async {
    await _open(tester, [_row('One', null), _row('Two', null)]);
    expect(find.byKey(const Key('unread-dot')), findsNWidgets(2));

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unread-dot')), findsNothing);
  });

  testWidgets('the Unread filter lists only unread notifications', (
    tester,
  ) async {
    await _open(tester, [_row('Fresh', null), _row('Old', null, isRead: true)]);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('a failed mark as read leaves it unread and says so', (
    tester,
  ) async {
    await _open(tester, [_row('Fresh', null)], failMarking: true);

    await tester.tap(find.text('Fresh'));
    await tester.pumpAndSettle();

    expect(find.text('Could not be marked as read'), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });

  testWidgets('a failed Mark all as read says so and keeps the marks', (
    tester,
  ) async {
    await _open(tester, [_row('Fresh', null)], failMarking: true);

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    expect(find.text('Could not be marked as read'), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });

  testWidgets('a saved copy says so at the top of the list', (tester) async {
    await _open(tester, [_row('Class note', null)], isSavedCopy: true);

    expect(find.text(_savedLine), findsOneWidget);
    expect(find.text('Class note'), findsOneWidget);
  });

  testWidgets('fresh notifications carry no saved-copy line', (tester) async {
    await _open(tester, [_row('Class note', null)]);

    expect(find.text(_savedLine), findsNothing);
    expect(find.text('Class note'), findsOneWidget);
  });

  testWidgets('a class notification opens the class and is marked read', (
    tester,
  ) async {
    final read = <int>[];
    await _open(tester, [
      _row('Class note', '/classes/5/dashboard'),
    ], read: read);

    await tester.tap(find.text('Class note'));
    await tester.pumpAndSettle();

    expect(find.text('class dashboard 5'), findsOneWidget);
    expect(read, ['Class note'.hashCode]);
  });

  testWidgets('a reminder for one class opens that class directly', (
    tester,
  ) async {
    final checked = <String>[];
    await _open(tester, [
      _row(
        'Reminder',
        null,
        classes: const [NotificationClass(id: 8, name: 'A1 Alpha')],
      ),
    ], checked: checked);

    await tester.tap(find.text('Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('class conduction 8'), findsOneWidget);
    expect(checked, ['/classes/8/conduction']);
  });

  testWidgets('a reminder for several classes lists them; a pick opens it', (
    tester,
  ) async {
    final checked = <String>[];
    await _open(tester, [
      _row(
        'Reminder',
        null,
        classes: const [
          NotificationClass(id: 8, name: 'A1 Alpha'),
          NotificationClass(id: 9, name: 'B2 Beta'),
        ],
      ),
    ], checked: checked);

    await tester.tap(find.text('Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a class'), findsOneWidget);
    expect(find.text('A1 Alpha'), findsOneWidget);
    expect(checked, isEmpty, reason: 'nothing opens until one is chosen');

    await tester.tap(find.text('B2 Beta'));
    await tester.pumpAndSettle();

    expect(find.text('class conduction 9'), findsOneWidget);
    expect(checked, ['/classes/9/conduction']);
  });

  testWidgets('a reminder class the member cannot reach is not opened', (
    tester,
  ) async {
    final checked = <String>[];
    await _open(
      tester,
      [
        _row(
          'Reminder',
          null,
          classes: const [NotificationClass(id: 8, name: 'A1 Alpha')],
        ),
      ],
      target: NotificationTarget.noAccess,
      checked: checked,
    );

    await tester.tap(find.text('Reminder'));
    await tester.pumpAndSettle();

    expect(checked, ['/classes/8/conduction']);
    expect(find.text('class conduction 8'), findsNothing);
    expect(find.text('You do not have access to this.'), findsOneWidget);
  });

  testWidgets('a quiz notification opens the quiz', (tester) async {
    await _open(tester, [_row('New quiz', '/quizzes/7')]);

    await tester.tap(find.text('New quiz'));
    await tester.pumpAndSettle();

    expect(find.text('quiz 7'), findsOneWidget);
  });

  for (final width in [400.0, 900.0]) {
    final where = width > 600 ? 'dialog' : 'sheet';

    testWidgets('a gone target is not opened; the $where says so and reads', (
      tester,
    ) async {
      await _open(
        tester,
        [_row('New quiz', '/quizzes/7')],
        width: width,
        target: NotificationTarget.gone,
      );

      await tester.tap(find.text('New quiz'));
      await tester.pumpAndSettle();

      expect(find.text('quiz 7'), findsNothing);
      expect(find.text('This is no longer available.'), findsOneWidget);
      expect(find.text('Invented body for New quiz'), findsNWidgets(2));
    });

    testWidgets('a refused target is not opened; the $where says why', (
      tester,
    ) async {
      await _open(
        tester,
        [_row('Class note', '/classes/5/dashboard')],
        width: width,
        target: NotificationTarget.noAccess,
      );

      await tester.tap(find.text('Class note'));
      await tester.pumpAndSettle();

      expect(find.text('class dashboard 5'), findsNothing);
      expect(find.text('You do not have access to this.'), findsOneWidget);
      expect(find.text('Invented body for Class note'), findsNWidgets(2));
    });
  }

  testWidgets('a notification with no usable target shows its full text', (
    tester,
  ) async {
    await _open(tester, [
      _row('No link', null),
      _row('Empty link', ''),
      _row('External link', 'https://example.invalid/page'),
      _row('Login link', '/login?error=hi'),
    ]);

    for (final title in [
      'No link',
      'Empty link',
      'External link',
      'Login link',
    ]) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        find.text('Invented body for $title'),
        findsNWidgets(2),
        reason: '$title shows its full text',
      );
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
      ).pop(); // close the sheet
      await tester.pumpAndSettle();
    }
  });
}
