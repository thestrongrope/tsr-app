import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/scheduled_notification.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/scheduled_notifications_screen.dart';
import 'package:the_strong_rope/features/classes/repositories/class_scheduled_notifications_repository.dart';

class _DeleteRepository extends ClassScheduledNotificationsRepository {
  _DeleteRepository(this.items);
  List<ClassScheduledNotification> items;
  int deletes = 0;
  @override
  Future<ScheduledNotificationsPayload> list(int classId) async =>
      ScheduledNotificationsPayload(items: items);
  @override
  Future<void> delete(int classId, int id) async {
    deletes++;
    items = items.where((item) => item.id != id).toList();
  }
}

void main() {
  Future<void> showList(
    WidgetTester tester, {
    List<ClassScheduledNotification> items = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classScheduledNotificationsProvider(7).overrideWith(
            (ref) async => ScheduledNotificationsPayload(items: items),
          ),
        ],
        child: const MaterialApp(
          home: ScheduledNotificationsScreen(classId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ClassScheduledNotification item({
    String? reason,
    ScheduledNotificationDelivery? delivery,
  }) => ClassScheduledNotification(
    id: 1,
    kind: 'ONCE',
    title: 'Class reminder',
    body: 'Please bring your workbook.',
    actionLink: '/classes/7/dashboard',
    status: 'done',
    createdBy: 1,
    sendAt: '2026-11-10T18:30:00',
    timezone: 'Asia/Kolkata',
    lastRun: ScheduledNotificationRun(
      studentCount: 5,
      deviceCount: delivery == null ? 0 : 3,
      successCount: 0,
      failureCount: 0,
      skippedReason: reason,
      delivery: delivery,
    ),
  );

  testWidgets('empty list explains that nothing is scheduled', (tester) async {
    await showList(tester);
    expect(find.text('Nothing scheduled'), findsOneWidget);
  });

  testWidgets('confirming deletion removes the row after server success', (
    tester,
  ) async {
    final repository = _DeleteRepository([item()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classScheduledNotificationsRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
        child: const MaterialApp(
          home: ScheduledNotificationsScreen(classId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 1);
    expect(find.text('Nothing scheduled'), findsOneWidget);
  });

  testWidgets('shows the message, link, wall clock, zone and nobody outcome', (
    tester,
  ) async {
    await showList(tester, items: [item()]);
    expect(find.text('Please bring your workbook.'), findsOneWidget);
    expect(find.text('/classes/7/dashboard'), findsOneWidget);
    expect(find.textContaining('18:30'), findsOneWidget);
    expect(find.textContaining('Asia/Kolkata'), findsOneWidget);
    expect(
      find.text('Last run sent nothing (no active devices)'),
      findsOneWidget,
    );
  });

  testWidgets('a missed notification stays visible with its reason', (
    tester,
  ) async {
    await showList(tester, items: [item(reason: 'missed_window')]);
    expect(find.textContaining('it missed its 2-hour window'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('shows delivery failures after retries', (tester) async {
    await showList(
      tester,
      items: [
        item(delivery: const ScheduledNotificationDelivery(sent: 2, dead: 1)),
      ],
    );
    expect(find.text('Last run: 2 sent · 1 still failing'), findsOneWidget);
  });

  testWidgets('delete requires confirmation and Cancel retains the row', (
    tester,
  ) async {
    await showList(tester, items: [item()]);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete scheduled notification?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete scheduled notification?'), findsNothing);
    expect(find.text('Class reminder'), findsOneWidget);
  });
}
