import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/account_deletion/models/deletion_request.dart';
import 'package:the_strong_rope/features/account_deletion/repositories/deletion_repository.dart';

/// Answers every request with a canned response and records what was asked.
///
/// A real [Dio] runs on top of this, so the test exercises the actual request
/// building and JSON decoding rather than a stand-in for them.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _RecordingAdapter adapter}) _dioReturning(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  final adapter = _RecordingAdapter(statusCode: statusCode, body: body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

const _pendingBody = {
  'id': 123,
  'status': 'pending',
  'requested_at': '2026-09-01T10:15:00',
  'expected_completion_days': 60,
};

void main() {
  group('DeletionRepository.request', () {
    test('posts to the deletion route and reads back the request', () async {
      final harness = _dioReturning(_pendingBody, statusCode: 202);
      final repository = DeletionRepository(dio: harness.dio);

      final request = await repository.request();

      expect(harness.adapter.lastRequest?.method, 'POST');
      expect(harness.adapter.lastRequest?.path, '/me/deletion-request');
      expect(request.status, DeletionStatus.pending);
      expect(request.requestedAt, DateTime.utc(2026, 9, 1, 10, 15));
    });

    test('treats a repeat request the same as the first one', () async {
      // The API answers 202 on create and 200 when a request already exists.
      // Both carry the same body, so nothing may branch on the code.
      final harness = _dioReturning(_pendingBody);
      final repository = DeletionRepository(dio: harness.dio);

      final request = await repository.request();

      expect(request.status, DeletionStatus.pending);
    });

    test('sends a reason when one is given', () async {
      final harness = _dioReturning(_pendingBody, statusCode: 202);
      final repository = DeletionRepository(dio: harness.dio);

      await repository.request(reason: 'No longer attending');

      expect(harness.adapter.lastRequest?.data, {
        'reason': 'No longer attending',
      });
    });

    test('sends no reason field when none is given', () async {
      final harness = _dioReturning(_pendingBody, statusCode: 202);
      final repository = DeletionRepository(dio: harness.dio);

      await repository.request();

      expect(harness.adapter.lastRequest?.data, isNull);
    });

    test('sends no reason field for a blank reason', () async {
      final harness = _dioReturning(_pendingBody, statusCode: 202);
      final repository = DeletionRepository(dio: harness.dio);

      await repository.request(reason: '   ');

      expect(harness.adapter.lastRequest?.data, isNull);
    });
  });

  group('DeletionRepository.fetch', () {
    test('reads the current status', () async {
      final harness = _dioReturning(const {
        'status': 'none',
        'requested_at': null,
        'expected_completion_days': 60,
      });
      final repository = DeletionRepository(dio: harness.dio);

      final request = await repository.fetch();

      expect(harness.adapter.lastRequest?.method, 'GET');
      expect(request.status, DeletionStatus.none);
    });
  });

  group('DeletionRepository.cancel', () {
    test('deletes the request and reads back the cancelled status', () async {
      final harness = _dioReturning(const {'status': 'cancelled'});
      final repository = DeletionRepository(dio: harness.dio);

      final request = await repository.cancel();

      expect(harness.adapter.lastRequest?.method, 'DELETE');
      expect(request.status, DeletionStatus.cancelled);
    });

    test(
      'reports a 409 as already completed rather than as a failure',
      () async {
        // Cancelling something already finished is a state to render, not an
        // error toast.
        final harness = _dioReturning(const {
          'detail':
              'This account has already been deleted and cannot be restored',
          'deletion_status': 'completed',
        }, statusCode: 409);
        final repository = DeletionRepository(dio: harness.dio);

        final request = await repository.cancel();

        expect(request.status, DeletionStatus.completed);
      },
    );

    test('reports a 404 as nothing pending rather than as a failure', () async {
      final harness = _dioReturning(const {
        'detail': 'No pending deletion request',
      }, statusCode: 404);
      final repository = DeletionRepository(dio: harness.dio);

      final request = await repository.cancel();

      expect(request.status, DeletionStatus.none);
    });

    test('still throws on an unrelated failure', () async {
      final harness = _dioReturning(const {
        'detail': 'Server error occurred',
      }, statusCode: 500);
      final repository = DeletionRepository(dio: harness.dio);

      expect(repository.cancel(), throwsA(isA<ApiException>()));
    });
  });
}
