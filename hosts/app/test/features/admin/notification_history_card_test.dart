import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/notification_history.dart';
import 'package:the_strong_rope/features/admin/screens/notification_history_screen.dart';

NotificationHistory _sent() => const NotificationHistory(
  notificationId: 7,
  title: 'Invented announcement',
  body: 'Invented body text for the card',
  targetAudienceCriteria: TargetAudienceCriteria(type: 'ALL_USERS'),
  deviceCount: 10,
  successCount: 9,
  failureCount: 1,
  sentAt: '2026-10-20T10:00:00+00:00',
  senderName: 'An Admin',
  senderEmail: 'admin@example.invalid',
);

void main() {
  testWidgets('a sent notification card shows its message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationHistoryCard(notification: _sent())),
      ),
    );

    expect(find.text('Invented announcement'), findsOneWidget);
    expect(find.text('Invented body text for the card'), findsOneWidget);
  });

  testWidgets('tapping the card opens its details, with the sender', (
    tester,
  ) async {
    // Tall, so the lazy sheet builds every section.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationHistoryCard(notification: _sent())),
      ),
    );
    expect(find.text('SENT BY'), findsNothing);

    await tester.tap(find.byType(NotificationHistoryCard));
    await tester.pumpAndSettle();

    expect(find.text('MESSAGE'), findsOneWidget);
    expect(find.text('SENT BY'), findsOneWidget);
    expect(find.text('An Admin'), findsWidgets); // the card shows it too
    expect(find.text('admin@example.invalid'), findsOneWidget);
  });
  sentToTests();
}

NotificationHistory _sentToClass() => const NotificationHistory(
  notificationId: 8,
  title: 'Invented class note',
  body: 'Invented body',
  targetAudienceCriteria: TargetAudienceCriteria(type: 'CLASS'),
  deviceCount: 10,
  successCount: 10,
  failureCount: 0,
  sentAt: '2026-10-20T10:00:00+00:00',
  senderName: 'An Admin',
  senderEmail: 'admin@example.invalid',
  actionLink: '/classes/5/dashboard',
  audienceSummary: 'Students of a class',
  audienceItems: ['C5 Class Five'],
  recipientCount: 12,
);

Future<void> _openSheet(
  WidgetTester tester,
  NotificationHistory notification,
) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NotificationHistoryCard(notification: notification)),
    ),
  );
  await tester.tap(find.byType(NotificationHistoryCard));
  await tester.pumpAndSettle();
}

void sentToTests() {
  testWidgets('the details say who it went to, how many, and where it opens', (
    tester,
  ) async {
    await _openSheet(tester, _sentToClass());

    expect(find.text('SENT TO'), findsOneWidget);
    final audience = find.byKey(const Key('notification-audience'));
    expect(
      find.descendant(of: audience, matching: find.text('Students of a class')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: audience, matching: find.text('C5 Class Five')),
      findsOneWidget,
    );
    expect(find.text('12 people have it in their inbox'), findsOneWidget);
    expect(find.text('Opens /classes/5/dashboard'), findsOneWidget);
  });

  testWidgets('an older server sends no audience, so the type is shown', (
    tester,
  ) async {
    await _openSheet(tester, _sent());

    expect(find.text('SENT TO'), findsOneWidget);
    final audience = find.byKey(const Key('notification-audience'));
    expect(
      find.descendant(of: audience, matching: find.text('ALL_USERS')),
      findsOneWidget,
    );
    expect(find.text('0 people have it in their inbox'), findsOneWidget);
    expect(find.textContaining('Opens'), findsNothing);
  });
}
