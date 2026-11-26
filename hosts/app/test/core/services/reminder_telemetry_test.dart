import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/services/reminder_telemetry.dart';

void main() {
  test('only the local class reminders count as reminders', () {
    expect(ReminderTelemetry.isReminderType('class_reminder'), isTrue);
    expect(ReminderTelemetry.isReminderType('conduction_reminder'), isTrue);
    expect(ReminderTelemetry.isReminderType('admin_announcement'), isFalse);
    expect(ReminderTelemetry.isReminderType('quiz_released'), isFalse);
  });
}
