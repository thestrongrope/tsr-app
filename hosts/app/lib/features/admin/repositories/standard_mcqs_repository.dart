import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/standard_mcqs.dart';

/// API calls behind the Standard MCQs update (#669). The server checks
/// `standard-mcqs:update`; hiding the screen is a courtesy. A refusal arrives
/// as an `ApiException` carrying the server's own words: 403 without the
/// permission, 422 for an empty choice, 409 while another update is running.
class StandardMcqsRepository {
  final ApiClient _apiClient;

  StandardMcqsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// The languages and levels that can be updated.
  Future<StandardMcqSources> getSources() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.standardMcqSourcesEndpoint,
    );
    return StandardMcqSources.fromJson(body);
  }

  /// Replaces the Standard MCQs for each chosen language and level from the
  /// source sheet. Slow: it reads the sheet for every pair.
  Future<List<StandardMcqResult>> update({
    required List<int> languages,
    required List<int> levels,
  }) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.standardMcqUpdateEndpoint,
      data: {'languages': languages, 'levels': levels},
    );
    return StandardMcqResult.listFromJson(body);
  }
}
