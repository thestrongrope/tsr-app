import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/account_deletion/models/deletion_request.dart';

void main() {
  group('DeletionStatus.fromApi', () {
    test('maps every status the server enum can hold', () {
      // migrations/2026_09_02_account_deletion_requests.sql, plus the
      // synthesised 'none' the read route returns when no row exists.
      expect(DeletionStatus.fromApi('pending'), DeletionStatus.pending);
      expect(
        DeletionStatus.fromApi('awaiting_prize_delivery'),
        DeletionStatus.awaitingPrizeDelivery,
      );
      expect(DeletionStatus.fromApi('completed'), DeletionStatus.completed);
      expect(DeletionStatus.fromApi('cancelled'), DeletionStatus.cancelled);
      expect(DeletionStatus.fromApi('none'), DeletionStatus.none);
    });

    test('treats a missing status as no request', () {
      expect(DeletionStatus.fromApi(null), DeletionStatus.none);
    });

    test('treats an unrecognised status as unknown, not as no request', () {
      // If the server grows a new blocking state, mirroring it as "no request"
      // would leave the app opening screens the API is already refusing.
      expect(
        DeletionStatus.fromApi('under_legal_hold'),
        DeletionStatus.unknown,
      );
    });
  });

  group('DeletionStatus.isRestricted', () {
    test('restricts while a request is live', () {
      expect(DeletionStatus.pending.isRestricted, isTrue);
      expect(DeletionStatus.awaitingPrizeDelivery.isRestricted, isTrue);
    });

    test('restricts on an unrecognised status', () {
      expect(DeletionStatus.unknown.isRestricted, isTrue);
    });

    test('does not restrict when no request is live', () {
      expect(DeletionStatus.none.isRestricted, isFalse);
      expect(DeletionStatus.cancelled.isRestricted, isFalse);
    });

    test('does not restrict once completed, which is terminal instead', () {
      expect(DeletionStatus.completed.isRestricted, isFalse);
      expect(DeletionStatus.completed.isTerminal, isTrue);
    });
  });

  group('DeletionRequest.fromJson', () {
    test('reads a pending request', () {
      final request = DeletionRequest.fromJson(const {
        'status': 'pending',
        'requested_at': '2026-09-01T10:15:00',
        'expected_completion_days': 60,
      });

      expect(request.status, DeletionStatus.pending);
      expect(request.requestedAt, DateTime.utc(2026, 9, 1, 10, 15));
      expect(request.expectedCompletionDays, 60);
    });

    test('reads the empty response the API sends when nothing is pending', () {
      final request = DeletionRequest.fromJson(const {
        'status': 'none',
        'requested_at': null,
        'expected_completion_days': 60,
      });

      expect(request.status, DeletionStatus.none);
      expect(request.requestedAt, isNull);
    });

    test('parses requested_at as UTC, not as device-local time', () {
      final request = DeletionRequest.fromJson(const {
        'status': 'pending',
        'requested_at': '2026-09-01T10:15:00',
        'expected_completion_days': 60,
      });

      expect(request.requestedAt!.isUtc, isTrue);
    });

    test('falls back to the 60-day window when the field is absent', () {
      final request = DeletionRequest.fromJson(const {'status': 'pending'});

      expect(request.expectedCompletionDays, 60);
    });
  });
}
