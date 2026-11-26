import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/permissions_revision_interceptor.dart';

/// Answers every request with [status] and, when given, the revision header.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, {this.revision});

  final int status;
  final String? revision;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'ok': true}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (revision != null) PermissionsRevisionInterceptor.header: [revision!],
    },
  );

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter, List<String> seen) =>
    Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter
      ..interceptors.add(PermissionsRevisionInterceptor(seen.add));

void main() {
  test('a response with the header reports its revision', () async {
    final seen = <String>[];
    await _dio(
      _Adapter(200, revision: 'bbbbbbbbbbbbbbbb'),
      seen,
    ).get('/classes');
    expect(seen, ['bbbbbbbbbbbbbbbb']);
  });

  test('a response without the header reports nothing', () async {
    final seen = <String>[];
    await _dio(_Adapter(200), seen).get('/classes');
    expect(seen, isEmpty);
  });

  test('an error response carries the revision too', () async {
    final seen = <String>[];
    final dio = _dio(_Adapter(403, revision: 'bbbbbbbbbbbbbbbb'), seen);
    await expectLater(dio.get('/classes'), throwsA(isA<DioException>()));
    expect(seen, ['bbbbbbbbbbbbbbbb']);
  });

  test('the permissions call itself is never reported', () async {
    final seen = <String>[];
    await _dio(
      _Adapter(200, revision: 'bbbbbbbbbbbbbbbb'),
      seen,
    ).get('/me/permissions');
    expect(seen, isEmpty);
  });
}
