import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/class_create.dart';
import '../models/class_manage.dart';

/// API calls behind creating a class (#636). The server checks `classes:create`
/// for the chosen gender; offering only what it allows is a courtesy.
class ClassCreateRepository {
  final ApiClient _apiClient;

  ClassCreateRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<CreateClassOptions> getOptions() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.classCreateOptionsEndpoint,
    );
    return CreateClassOptions.fromJson(body);
  }

  /// The levels a class can be at.
  Future<List<ManageOption>> getLevels() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.classLevelsEndpoint,
    );
    return [
      for (final l in body as List<dynamic>)
        ManageOption.fromJson(l as Map<String, dynamic>),
    ];
  }

  /// Members who can be made the teacher of a new class of [gender].
  Future<List<ManageOption>> searchTeachers(int gender, String query) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classCreateTeachersEndpoint,
      queryParameters: {'gender': gender, 'q': query},
    );
    return [
      for (final t in json['teachers'] as List<dynamic>? ?? const [])
        ManageOption(
          id: (t as Map<String, dynamic>)['token'] as int,
          name: t['name'] as String? ?? '',
        ),
    ];
  }

  /// Creates the class and answers with its id. Throws an `ApiException`: 409
  /// when the same class was just created, 422 for a missing or invalid answer
  /// (the server's words say which), 403 without permission.
  Future<int> createClass({
    required int gender,
    required int levelId,
    required String location,
    required String city,
    required String country,
    required int teacher,
    required List<int> tags,
    required List<ManageSchedule> schedules,
  }) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      AppConstants.classesEndpoint,
      data: {
        'gender': gender,
        'levelId': levelId,
        'location': location,
        'city': city,
        'country': country,
        'teacher': teacher,
        'tags': tags,
        'schedules': [
          for (final s in schedules)
            {
              'day': s.day,
              'hour': s.hour,
              'minute': s.minute,
              'timezone': s.timezone,
            },
        ],
      },
    );
    return json['classId'] as int;
  }
}
