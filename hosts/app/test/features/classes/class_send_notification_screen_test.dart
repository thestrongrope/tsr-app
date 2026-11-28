import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/class_send_notification_screen.dart';

void main() {
  const fakeClass = ClassModel(
    id: 42,
    code: 'CLS-42',
    name: 'Islamic History 101',
    level: 1,
    gender: 1,
    status: 'A',
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [classDetailProvider(42).overrideWith((ref) => fakeClass)],
      child: const MaterialApp(home: ClassSendNotificationScreen(classId: 42)),
    );
  }

  testWidgets(
    'ClassSendNotificationScreen renders class details and form inputs',
    (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify title in app bar
      expect(find.text('Send Class Notification'), findsOneWidget);

      // Verify class info banner displays class level, code and student audience
      expect(find.text('Level 1 - CLS-42'), findsOneWidget);
      expect(
        find.text('Recipients: All enrolled active students in this class.'),
        findsOneWidget,
      );

      // Verify form fields exist
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Message Body *'), findsOneWidget);
      expect(find.text('Action Link (Optional)'), findsOneWidget);

      // Verify submit button
      expect(find.text('Send to Class Students'), findsOneWidget);
    },
  );

  testWidgets(
    'ClassSendNotificationScreen validates required fields on submit',
    (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Scroll to and tap submit without entering title or message
      await tester.ensureVisible(find.text('Send to Class Students'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to Class Students'));
      await tester.pumpAndSettle();

      // Verify validation error messages
      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Message is required'), findsOneWidget);
    },
  );
}
