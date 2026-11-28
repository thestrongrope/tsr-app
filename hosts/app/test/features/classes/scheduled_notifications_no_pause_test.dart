import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/scheduled_notification.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/scheduled_notifications_screen.dart';

void main() {
  ClassScheduledNotification item(int id, String status, String reason) =>
      ClassScheduledNotification(
        id: id,
        kind: 'ONCE',
        title: 'Item $id',
        body: 'Body',
        status: status,
        createdBy: 1,
        lastRun: reason.isEmpty
            ? null
            : ScheduledNotificationRun(
                studentCount: 0,
                deviceCount: 0,
                successCount: 0,
                failureCount: 0,
                skippedReason: reason,
              ),
      );

  testWidgets('the list offers Delete but no Pause or Resume', (tester) async {
    final payload = ScheduledNotificationsPayload(
      items: [item(1, 'active', ''), item(2, 'done', 'missed_window')],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classScheduledNotificationsProvider(
            7,
          ).overrideWith((ref) async => payload),
        ],
        child: const MaterialApp(
          home: ScheduledNotificationsScreen(classId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Delete'), findsNWidgets(2));
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Resume'), findsNothing);
  });
  testWidgets('a run says how many devices it was queued to, not delivered', (
    tester,
  ) async {
    final queued = ClassScheduledNotification(
      id: 3,
      kind: 'ONCE',
      title: 'Item 3',
      body: 'Body',
      status: 'done',
      createdBy: 1,
      lastRun: ScheduledNotificationRun(
        studentCount: 5,
        deviceCount: 2,
        successCount: 0,
        failureCount: 0,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classScheduledNotificationsProvider(7).overrideWith(
            (ref) async => ScheduledNotificationsPayload(items: [queued]),
          ),
        ],
        child: const MaterialApp(
          home: ScheduledNotificationsScreen(classId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last run: queued to 2 devices'), findsOneWidget);
    expect(find.textContaining('0 sent'), findsNothing);
  });
}
