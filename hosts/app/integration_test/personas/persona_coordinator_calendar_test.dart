import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/classes/providers/class_scheduled_notifications_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_scheduled_notifications_repository.dart';
import 'package:the_strong_rope/features/classes/screens/class_send_notification_screen.dart';
import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

// Writes only to the local persona cohort. Demo accounts intentionally cannot
// receive scheduled pushes, so delivery to a non-demo device is a release check.
void main() {
  patrolAppTest('schedule a notification and customise a shared class event', (
    $,
  ) async {
    expect(
      ['127.0.0.1', 'localhost'].contains(Uri.parse(AppConstants.baseUrl).host),
      isTrue,
      reason: 'This writing journey must use the local API',
    );
    await signInAs($, Persona.coordinator);
    final classes = await ApiClient().getUserClasses();
    final classId =
        (classes.singleWhere((item) => item['code'] == 'AYD1')['id'] as num)
            .toInt();
    final container = ProviderScope.containerOf(
      $.tester.element(find.byType(Scaffold).first),
    );
    final zone = await container.read(deviceTimezoneProvider.future);
    final due = DateTime.now().add(const Duration(minutes: 2));
    final notification = await ClassScheduledNotificationsRepository()
        .create(classId, {
          'kind': 'ONCE',
          'title': 'Persona scheduled notification',
          'body': 'Prepare for class',
          'send_at': localWallClock(due, TimeOfDay.fromDateTime(due)),
          'timezone': zone,
        });
    await pushRoute($, '/classes/$classId/notifications/scheduled');
    expect(find.text('Persona scheduled notification'), findsOneWidget);
    await popRoute($);
    await pushRoute($, '/classes/$classId/scheduled-events');
    await $('Create event').tap();
    await $.pumpAndSettle();
    await $.tester.enterText(
      find.byType(TextFormField).first,
      'Persona calendar lesson',
    );
    await $('Mon').tap();
    await $('Save event').scrollTo();
    await $('Save event').tap();
    await $.pumpAndSettle();
    expect(find.text('Persona calendar lesson'), findsOneWidget);
    // The scheduled send remains covered by worker tests; cancel this fixture
    // before switching accounts so a failed later assertion cannot leave it due.
    await ClassScheduledNotificationsRepository().delete(
      classId,
      notification.id,
    );
    await container.read(authStateProvider.notifier).signOut();
    await $.pumpAndSettle();
    await signInAs($, Persona.member);
    await pushRoute($, '/my-class-alerts');
    final card = find.ancestor(
      of: find.text('Persona calendar lesson'),
      matching: find.byType(Card),
    );
    await $(find.text('Persona calendar lesson')).waitUntilVisible();
    final choice = find.descendant(
      of: card,
      matching: find.byType(DropdownButton<int>),
    );
    await $(choice).tap();
    await $('15 minutes before').tap();
    await $.pumpAndSettle();
    expect($.tester.widget<DropdownButton<int>>(choice).value, -15);
    await $(choice).tap();
    await $('Off').tap();
    await $.pumpAndSettle();
    expect($.tester.widget<DropdownButton<int>>(choice).value, 1);
    await $(
      find.descendant(of: card, matching: find.text('Delete for me')),
    ).tap();
    await $('Undo').waitUntilVisible();
    expect(find.text('Persona calendar lesson'), findsNothing);
    await $('Undo').tap();
    await $.pumpAndSettle();
    expect(find.text('Persona calendar lesson'), findsOneWidget);
  });
}
