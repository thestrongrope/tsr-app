import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';

/// Records each request and answers with the next scripted status.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.statuses);

  final List<int> statuses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final status = statuses.removeAt(0);
    return ResponseBody.fromString(
      status == 304 ? '' : jsonEncode({'version': 5}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // No stored token: the secure-storage plugin is not available in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    ApiClient().initialize();
  });

  test('sends If-None-Match and treats 304 as "unchanged" (null)', () async {
    final adapter = _Adapter([304]);
    ApiClient().dio.httpClientAdapter = adapter;

    final body = await ApiClient().getPermissions(
      ifNoneMatch: '0123456789abcdef',
    );

    expect(body, isNull);
    expect(adapter.requests, hasLength(1));
    expect(
      adapter.requests.single.headers['If-None-Match'],
      '"0123456789abcdef"',
    );
  });

  test(
    'without a revision it sends no If-None-Match and returns the body',
    () async {
      final adapter = _Adapter([200]);
      ApiClient().dio.httpClientAdapter = adapter;

      final body = await ApiClient().getPermissions();

      expect(body, {'version': 5});
      expect(
        adapter.requests.single.headers.containsKey('If-None-Match'),
        isFalse,
      );
    },
  );

  test('a 304 is not accepted on other calls', () async {
    ApiClient().dio.httpClientAdapter = _Adapter([304]);

    await expectLater(
      ApiClient().dio.get('/classes'),
      throwsA(isA<DioException>()),
    );
  });

  test('a 503 is an error, not an empty answer', () async {
    ApiClient().dio.httpClientAdapter = _Adapter([503]);

    await expectLater(
      ApiClient().getPermissions(ifNoneMatch: '0123456789abcdef'),
      throwsA(isA<ApiException>()),
    );
  });
}
