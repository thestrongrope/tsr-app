import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/models/scheduled_notification.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/repositories/class_scheduled_notifications_repository.dart';
import 'package:the_strong_rope/features/classes/screens/class_send_notification_screen.dart';

class _RefusedLinkRepository extends ClassScheduledNotificationsRepository {
  int calls = 0;
  @override
  Future<ClassScheduledNotification> create(
    int classId,
    Map<String, dynamic> data,
  ) async {
    calls++;
    throw const ApiException(
      'action_link must be an https:// link or an in-app path',
      422,
    );
  }
}

void main() {
  const cls = ClassModel(
    id: 42,
    code: 'C42',
    name: 'Class',
    level: 1,
    gender: 1,
    status: 'A',
  );
  late DateTime now;
  late _RefusedLinkRepository repository;
  setUp(() {
    now = DateTime(2030, 1, 1, 12);
    repository = _RefusedLinkRepository();
  });
  Future<void> prepare(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classDetailProvider(42).overrideWith((ref) => cls),
          deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Kolkata'),
          classScheduledNotificationsProvider(
            42,
          ).overrideWith((ref) async => const ScheduledNotificationsPayload()),
          classScheduledNotificationsRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
        child: MaterialApp(
          home: ClassSendNotificationScreen(classId: 42, clock: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Lesson');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Read chapter two',
    );
    await tester.ensureVisible(find.text('Date'));
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Time'));
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('a selected time that has passed is refused before sending', (
    tester,
  ) async {
    await prepare(tester);
    now = now.add(const Duration(days: 3));
    await tester.ensureVisible(find.text('Schedule Notification'));
    await tester.tap(find.text('Schedule Notification'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a moment in the future'), findsOneWidget);
    expect(repository.calls, 0);
  });
  testWidgets('server link refusal is shown and the form stays open', (
    tester,
  ) async {
    await prepare(tester);
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'javascript:bad()',
    );
    await tester.ensureVisible(find.text('Schedule Notification'));
    await tester.tap(find.text('Schedule Notification'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Schedule'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(
      find.text('action_link must be an https:// link or an in-app path'),
      findsOneWidget,
    );
    expect(find.byType(ClassSendNotificationScreen), findsOneWidget);
  });
}
