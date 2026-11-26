import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/donors.dart';

/// API calls behind the donors list (#421). The server checks `donors:read`;
/// hiding the screen is a courtesy.
class DonorsRepository {
  final ApiClient _apiClient;

  DonorsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<Donor>> getDonors() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminDonorsEndpoint,
    );
    return Donor.listFromJson(body);
  }

  /// The donors as a file, under the same guard as the list. Throws an
  /// `ApiException`: 404 when there are none, 403 without permission.
  Future<List<int>> download(String format) {
    return _apiClient.get<List<int>>(
      AppConstants.adminDonorsDownloadEndpoint,
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
