import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/guide_authoring.dart';

/// API calls behind authoring a guide (#417). The server asks guides:manage on
/// every one; the Admin card hides what the caller may not do, as a courtesy.
class GuidesRepository {
  final ApiClient _apiClient;

  GuidesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<GuideLevel>> getLevels() async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.guidesEndpoint,
    );
    return (json['levels'] as List<dynamic>)
        .map((l) => GuideLevel.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<EditableGuide> getGuide(int levelId) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.guideEndpoint(levelId),
    );
    return EditableGuide.fromJson(json);
  }

  Future<void> saveGuide(int levelId, String html) async {
    await _apiClient.put<Map<String, dynamic>>(
      AppConstants.guideEndpoint(levelId),
      data: {'guide': html},
    );
  }
}
