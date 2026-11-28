import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/utils/user_message.dart';

void main() {
  test('a refusal the member can act on keeps the server\'s own words', () {
    expect(
      userMessage(const ApiException('That date already has a session', 409)),
      'That date already has a session',
    );
  });

  test('a server fault never shows the server\'s text, which may be HTML', () {
    expect(
      userMessage(
        const ApiException('<html><body>502 Bad Gateway</body>', 502),
      ),
      isNot(contains('<')),
    );
    expect(
      userMessage(const ApiException('Server error occurred', 500)),
      contains('on our side'),
    );
  });

  test('a message that is long or looks like an exception is not shown', () {
    final long = 'x' * 300;
    expect(
      userMessage(ApiException(long, 400)),
      AppConstants.genericErrorMessage,
    );
    expect(
      userMessage(const ApiException('FormatException: bad', 400)),
      AppConstants.genericErrorMessage,
    );
    expect(
      userMessage(const ApiException('', 400)),
      AppConstants.genericErrorMessage,
    );
  });

  test('no connection and a timeout say so', () {
    expect(
      userMessage(const ApiException('whatever', 0)),
      AppConstants.networkErrorMessage,
    );
    expect(
      userMessage(const ApiException('whatever', 408)),
      AppConstants.timeoutErrorMessage,
    );
    expect(
      userMessage(const SocketException('no route')),
      AppConstants.networkErrorMessage,
    );
    expect(
      userMessage(TimeoutException('slow')),
      AppConstants.timeoutErrorMessage,
    );
  });

  test('a raw Dio failure is mapped the same way', () {
    final offline = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(userMessage(offline), AppConstants.networkErrorMessage);
  });

  test('anything else is the generic message, never the exception text', () {
    final message = userMessage(StateError('secret internals'));

    expect(message, AppConstants.genericErrorMessage);
    expect(message, isNot(contains('secret')));
  });
}
