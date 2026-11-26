import '../../../core/network/api_client.dart';
import '../models/geo.dart';

/// Calls to our own /geo routes. Nothing here leaves our servers: that is the
/// point of keeping a copy of GeoNames instead of asking a third party.
///
/// Every method can throw (offline, rate limited). The form treats a failed
/// postal or city lookup as "no suggestion" and stays plain text; without the
/// countries it disables the country field and offers a retry.
class GeoRepository {
  final ApiClient _apiClient;

  GeoRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<GeoCountry>> countries() async {
    final json = await _apiClient.get<Map<String, dynamic>>('/geo/countries');
    return (json['countries'] as List<dynamic>? ?? const [])
        .map((c) => GeoCountry.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// The state and a suggested city for [code], or null when we do not hold it.
  /// A POST so what the member typed is not in any access log's URL.
  Future<GeoPostalResult?> postal(String countryCode, String code) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      '/geo/postal',
      data: {'country': countryCode, 'code': code},
    );
    if (json['found'] != true) return null;
    return GeoPostalResult(
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  Future<List<GeoCity>> cities(String countryCode, String query) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      '/geo/cities',
      data: {'country': countryCode, 'query': query},
    );
    return (json['cities'] as List<dynamic>? ?? const [])
        .map((c) => GeoCity.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}
