import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/screens/class_send_notification_screen.dart';

void main() {
  test('a picked date and time go out as written, with no UTC conversion', () {
    final wallClock = localWallClock(
      DateTime(2026, 11, 10),
      const TimeOfDay(hour: 18, minute: 5),
    );

    expect(wallClock, '2026-11-10T18:05:00');
    expect(wallClock.endsWith('Z'), isFalse);
    expect(wallClock.contains('+'), isFalse);
  });
}
