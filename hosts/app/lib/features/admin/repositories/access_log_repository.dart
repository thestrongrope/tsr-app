import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/access_log.dart';

/// API calls behind the admin access log (#419). The server checks
/// `audit-log:read`; hiding the screen is a courtesy.
class AccessLogRepository {
  final ApiClient _apiClient;

  AccessLogRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Map<String, dynamic> _query(AccessLogFilter filter) => {
    if (filter.token != null) 'token': filter.token,
    if (filter.page.isNotEmpty) 'page': filter.page,
  };

  Future<AccessLog> getAccessLog(AccessLogFilter filter) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.adminAccessLogEndpoint,
      queryParameters: _query(filter),
    );
    return AccessLog.fromJson(json);
  }

  /// The filtered accesses as a file, under the same guard as the lists. Throws
  /// an `ApiException`: 404 when none match, 403 without permission.
  Future<List<int>> download(String format, AccessLogFilter filter) {
    return _apiClient.get<List<int>>(
      AppConstants.adminAccessLogDownloadEndpoint,
      queryParameters: {'format': format, ..._query(filter)},
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
