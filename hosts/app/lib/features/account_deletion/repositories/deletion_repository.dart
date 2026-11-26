import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/deletion_request.dart';

/// The account deletion routes.
///
/// Contract: `docs/backend/account-deletion-api.md`. Note the path carries no
/// `/api/v1` prefix — [ApiClient] sets Dio's `baseUrl` to the host alone.
class DeletionRepository {
  static const String _path = '/me/deletion-request';

  final Dio _dio;

  DeletionRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// Raise a deletion request, or read back the live one.
  ///
  /// The API answers 202 on create and 200 when a request already exists, with
  /// the same body either way, so this does not distinguish them.
  Future<DeletionRequest> request({String? reason}) async {
    final trimmed = reason?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: (trimmed == null || trimmed.isEmpty) ? null : {'reason': trimmed},
    );
    return DeletionRequest.fromJson(response.data ?? const {});
  }

  /// The current deletion state for the signed-in member.
  Future<DeletionRequest> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(_path);
    return DeletionRequest.fromJson(response.data ?? const {});
  }

  /// Cancel a live request.
  ///
  /// 404 (nothing pending) and 409 (already completed) are states to render,
  /// not failures: both tell the caller what is true now, so they resolve to a
  /// status rather than an exception.
  Future<DeletionRequest> cancel() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(_path);
      return DeletionRequest.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      final failure = ApiException.fromDioException(e);
      if (failure.statusCode == 404) {
        return const DeletionRequest(status: DeletionStatus.none);
      }
      if (failure.statusCode == 409) {
        return DeletionRequest(
          status: DeletionStatus.fromApi(failure.deletionStatus ?? 'completed'),
        );
      }
      throw failure;
    }
  }
}
