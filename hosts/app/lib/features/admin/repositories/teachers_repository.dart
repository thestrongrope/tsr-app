import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/teachers.dart';

/// API calls behind the teachers screens (#622). The server checks
/// `teachers:read` (and `teachers:lookup` for one teacher); hiding the screens
/// is a courtesy.
class TeachersRepository {
  final ApiClient _apiClient;

  TeachersRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// The teachers of [gender] (1 gents, 2 ladies). A gender admin gets their
  /// own whatever is asked.
  Future<TeachersList> getTeachers({required int gender}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminTeachersEndpoint,
      queryParameters: {'gender': gender},
    );
    return TeachersList.fromJson(body);
  }

  /// One teacher. Throws an `ApiException`: 404 when they do not exist or the
  /// caller may not see them, 403 without permission.
  Future<TeacherDetail> getTeacher(int token) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.teacherEndpoint(token),
    );
    return TeacherDetail.fromJson(body);
  }

  /// Saves [changes] under one [comments], all or none. Returns how many
  /// teachers were changed. Throws an `ApiException`: 403 for a teacher the
  /// caller may not manage, 404 for an unknown member, 422 for a missing or
  /// long comment or a bad change (the server's words say which), 500 when it
  /// failed and nothing was changed.
  Future<int> changeTraining({
    required List<TrainingChange> changes,
    required String comments,
  }) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminTeachersTrainingEndpoint,
      data: {
        'changes': [for (final c in changes) c.toJson()],
        'comments': comments,
      },
    );
    return _count(body, 'changed');
  }

  /// Adds the teachers of active classes who have no training record. Returns
  /// how many were added.
  Future<int> importTeachers({required int gender}) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminTeachersImportEndpoint,
      data: {'gender': gender},
    );
    return _count(body, 'added');
  }

  int _count(dynamic body, String key) {
    if (body is! Map<String, dynamic> || body[key] is! num) {
      throw FormatException('teachers: unexpected response ($key)');
    }
    return (body[key] as num).toInt();
  }
}
