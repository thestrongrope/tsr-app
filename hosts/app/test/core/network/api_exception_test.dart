import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';

DioException _badResponse(int statusCode, dynamic body) {
  final options = RequestOptions(path: '/me');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
    ),
  );
}

void main() {
  group('ApiException.fromDioException', () {
    test('keeps the deletion status the API sent on a 403', () {
      // The restricted-session gate is the only thing that distinguishes this
      // from an ordinary permission refusal, and it lives in the body.
      final exception = ApiException.fromDioException(
        _badResponse(403, {
          'detail': 'Account deletion pending',
          'deletion_status': 'pending',
        }),
      );

      expect(exception.deletionStatus, 'pending');
      expect(exception.statusCode, 403);
      expect(exception.message, 'Account deletion pending');
    });

    test('reports no deletion status for an ordinary 403', () {
      final exception = ApiException.fromDioException(
        _badResponse(403, {'detail': 'Forbidden'}),
      );

      expect(exception.deletionStatus, isNull);
    });

    test('reports no deletion status when the body is not a map', () {
      final exception = ApiException.fromDioException(
        _badResponse(403, 'Forbidden'),
      );

      expect(exception.deletionStatus, isNull);
      expect(exception.message, 'Forbidden');
    });

    test('reports no deletion status when there is no response at all', () {
      final exception = ApiException.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/me'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(exception.deletionStatus, isNull);
      expect(exception.statusCode, 0);
      expect(exception.message, AppConstants.networkErrorMessage);
    });

    test('still maps a timeout to 408 with the timeout message', () {
      final exception = ApiException.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/me'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(exception.statusCode, 408);
      expect(exception.message, AppConstants.timeoutErrorMessage);
    });
  });
}
