import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/class_guide.dart';

/// Reads a class level's guide (#412). The server takes the level from the
/// class and checks the caller belongs to it. A guide link names the level by
/// its slug instead (#1138); the server then checks the caller is a student
/// or a teacher.
class ClassGuideRepository {
  final ApiClient _apiClient;

  ClassGuideRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ClassGuide> getGuide(int classId) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classGuideEndpoint(classId),
    );
    return ClassGuide.fromJson(json);
  }

  /// The guide a guide link's slug names; a 404 [ApiException] when there is
  /// none, a 403 when the caller is neither a student nor a teacher.
  Future<ClassGuide> getGuideBySlug(String slug) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.readerGuideEndpoint(slug),
    );
    return ClassGuide.fromJson(json);
  }

  /// The guides that can be opened, for a link that names none that exists.
  Future<List<GuideSummary>> getGuides() async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.readerGuidesEndpoint,
    );
    return (json['guides'] as List<dynamic>)
        .map((e) => GuideSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
