import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/utils/api_datetime.dart';

void main() {
  group('parseApiDateTime', () {
    test('reads a value with no timezone designator as UTC', () {
      // The mobile API emits naive strings that are UTC values
      // (api_cast_value() replaces the space with a T and adds nothing else).
      // DateTime.parse would call this local time, which is wrong by the
      // device's offset — 5.5 hours on an IST handset.
      final parsed = parseApiDateTime('2026-09-01T10:15:00');

      expect(parsed, DateTime.utc(2026, 9, 1, 10, 15));
    });

    test('keeps the instant when the value already carries Z', () {
      final parsed = parseApiDateTime('2026-09-01T10:15:00Z');

      expect(parsed, DateTime.utc(2026, 9, 1, 10, 15));
    });

    test('keeps the instant when the value carries a numeric offset', () {
      final parsed = parseApiDateTime('2026-09-01T15:45:00+05:30');

      expect(parsed, DateTime.utc(2026, 9, 1, 10, 15));
    });

    test('returns UTC, so the result is comparable across devices', () {
      expect(parseApiDateTime('2026-09-01T10:15:00')!.isUtc, isTrue);
    });

    test('returns null for null', () {
      expect(parseApiDateTime(null), isNull);
    });

    test('returns null for an empty string', () {
      expect(parseApiDateTime(''), isNull);
    });

    test('returns null for a malformed value instead of throwing', () {
      expect(parseApiDateTime('not a date'), isNull);
    });
  });
  localTests();
  formatTests();
}

void formatTests() {
  group('formatApiLocalDateTime', () {
    test('shows a zone-less server time as UTC converted to device time', () {
      final local = DateTime.utc(2026, 9, 1, 10, 15).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final expected =
          '${local.year}-${two(local.month)}-${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}';

      expect(formatApiLocalDateTime('2026-09-01 10:15:00'), expected);
      expect(formatApiLocalDateTime('2026-09-01T10:15:00Z'), expected);
    });

    test('leaves a date with no time of day unchanged', () {
      expect(formatApiLocalDateTime('2026-09-01'), '2026-09-01');
    });

    test('null is empty and unreadable text is shown as sent', () {
      expect(formatApiLocalDateTime(null), '');
      expect(formatApiLocalDateTime('soon'), 'soon');
    });
  });
}

void localTests() {
  group('parseApiLocalDateTime', () {
    test('is the same instant as parseApiDateTime, in the device clock', () {
      final local = parseApiLocalDateTime('2026-09-01T10:15:00')!;

      expect(local.toUtc(), DateTime.utc(2026, 9, 1, 10, 15));
      expect(local.isUtc, isFalse);
    });

    test('keeps the instant for a value that already carries a zone', () {
      expect(
        parseApiLocalDateTime('2026-09-01T15:45:00+05:30')!.toUtc(),
        DateTime.utc(2026, 9, 1, 10, 15),
      );
    });

    test('null, empty and unparseable input is null, not an error', () {
      expect(parseApiLocalDateTime(null), isNull);
      expect(parseApiLocalDateTime('  '), isNull);
      expect(parseApiLocalDateTime('not a date'), isNull);
    });
  });
}
