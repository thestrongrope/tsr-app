import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// Answers every request with [status] and [body].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

TsrWebService _service(int status, Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://thestrongrope.com'))
    ..httpClientAdapter = _Adapter(status, body);
  return TsrWebService(dio: dio);
}

const _notFound = {
  'success': false,
  'error': {'code': 'NOT_FOUND', 'message': 'Article not found: x'},
};

/// What the site answers for a slug it does not know: HTTP 404 with a
/// NOT_FOUND error body (checked against production, 2026-10-29).
void main() {
  group('TsrWebService.getArticle', () {
    test('an HTTP 404 is ApiException(404)', () async {
      await expectLater(
        _service(404, _notFound).getArticle('x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    test('a NOT_FOUND body on a 200 is ApiException(404)', () async {
      await expectLater(
        _service(200, _notFound).getArticle('x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    test('a server fault is not a 404', () async {
      await expectLater(
        _service(500, {'success': false}).getArticle('x'),
        throwsA(
          predicate(
            (e) => !(e is ApiException && e.statusCode == 404),
            'not a 404',
          ),
        ),
      );
    });
  });
}
