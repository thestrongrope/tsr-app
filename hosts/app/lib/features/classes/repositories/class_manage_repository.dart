import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/bulk_add.dart';
import '../models/class_manage.dart';
import '../models/class_student_figures.dart';

/// A class's weekly slots and the timezones to pick from (#629).
class ClassScheduleData {
  final List<ManageSchedule> schedules;
  final List<ManageTimezone> timezones;

  const ClassScheduleData({required this.schedules, required this.timezones});

  factory ClassScheduleData.fromJson(Map<String, dynamic> json) =>
      ClassScheduleData(
        schedules: (json['schedules'] as List<dynamic>? ?? const [])
            .map((s) => ManageSchedule.fromJson(s as Map<String, dynamic>))
            .toList(),
        timezones: (json['timezones'] as List<dynamic>? ?? const [])
            .map((t) => ManageTimezone.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

/// API calls behind the manage-a-class screen (#402). Every one is checked on
/// the server against the same permission the web page asks for; the screen
/// hides what the caller may not do, but that is only a courtesy.
class ClassManageRepository {
  final ApiClient _apiClient;

  ClassManageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ClassManagePayload> getManage(int classId) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classManageEndpoint(classId),
    );
    return ClassManagePayload.fromJson(json);
  }

  /// The schedule alone, for the class's teacher or MCQ admin (#629).
  Future<ClassScheduleData> getSchedule(int classId) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classScheduleEndpoint(classId),
    );
    return ClassScheduleData.fromJson(json);
  }

  /// Set day, time and timezone, and nothing else: no topics are sent.
  Future<ClassScheduleData> saveSchedule(
    int classId,
    List<ManageSchedule> schedules,
  ) async {
    final json = await _apiClient.put<Map<String, dynamic>>(
      AppConstants.classScheduleEndpoint(classId),
      data: {
        'schedules': [
          for (final s in schedules)
            {
              'id': s.id,
              'day': s.day,
              'hour': s.hour,
              'minute': s.minute,
              'timezone': s.timezone,
            },
        ],
      },
    );
    return ClassScheduleData.fromJson(json);
  }

  /// The active roster, for a teacher who may look but not edit.
  Future<List<ManagedStudent>> getTeacherRoster(int classId) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classStudentsEndpoint(classId),
    );
    return ManageRoster.fromJson(json).students;
  }

  /// Each current student's attendance, MCQ results and recitation (#692), for
  /// whoever may manage the class's MCQs. No [from] and [to] is the last year;
  /// a bad or over-long range is an [ApiException] carrying the server's reason.
  Future<ClassStudentFigures> getStudentFigures(
    int classId, {
    String? from,
    String? to,
  }) async {
    final json = await _apiClient.get<dynamic>(
      AppConstants.classStudentFiguresEndpoint(classId),
      queryParameters: {'from': ?from, 'to': ?to},
    );
    return ClassStudentFigures.fromJson(json);
  }

  /// Save details and schedule; answers with the refreshed payload.
  Future<ClassManagePayload> save(int classId, ClassDraft draft) async {
    final json = await _apiClient.put<Map<String, dynamic>>(
      AppConstants.classDetailEndpoint(classId),
      data: draft.toJson(),
    );
    return ClassManagePayload.fromJson(json);
  }

  /// Members who can be made the class's teacher, matching [query].
  Future<List<ManageOption>> searchTeachers(int classId, String query) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.classTeachersEndpoint(classId),
      queryParameters: {'q': query},
    );
    return (json['teachers'] as List<dynamic>? ?? const [])
        .map(
          (t) => ManageOption(
            id: (t as Map<String, dynamic>)['token'] as int,
            name: t['name'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Enrol an existing member (#403).
  Future<ManageRoster> addStudent(int classId, int token) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      AppConstants.classStudentsEndpoint(classId),
      data: {'token': token},
    );
    return ManageRoster.fromJson(json);
  }

  /// Enrol a pasted list, one `name, optional mobile` per line (#691). A
  /// [BulkAddResult.needsConfirmation] answer wrote nothing; send the same
  /// [lines] again with [resolutions] (line number to `add`, `enrol` or `skip`).
  Future<BulkAddResult> bulkAddStudents(
    int classId,
    List<String> lines,
    Map<int, String> resolutions,
  ) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      AppConstants.classStudentsBulkEndpoint(classId),
      data: {
        'lines': lines,
        'resolutions': {
          for (final e in resolutions.entries) '${e.key}': e.value,
        },
      },
    );
    return BulkAddResult.fromJson(json);
  }

  Future<ManageRoster> updateStudent(
    int classId,
    int token, {
    required String name,
    required String email,
    required String mobile,
    required String notes,
  }) async {
    final json = await _apiClient.put<Map<String, dynamic>>(
      AppConstants.classStudentEndpoint(classId, token),
      data: {'name': name, 'email': email, 'mobile': mobile, 'notes': notes},
    );
    return ManageRoster.fromJson(json);
  }

  Future<ManageRoster> removeStudent(
    int classId,
    int token,
    String reason,
  ) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      '${AppConstants.classStudentEndpoint(classId, token)}/remove',
      data: {'reason': reason},
    );
    return ManageRoster.fromJson(json);
  }

  Future<ManageRoster> restoreStudent(int classId, int token) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      '${AppConstants.classStudentEndpoint(classId, token)}/restore',
    );
    return ManageRoster.fromJson(json);
  }

  Future<ManageRoster> setClassAdmin(
    int classId,
    int token,
    bool status,
  ) async {
    final json = await _apiClient.put<Map<String, dynamic>>(
      '${AppConstants.classStudentEndpoint(classId, token)}/class-admin',
      data: {'status': status},
    );
    return ManageRoster.fromJson(json);
  }

  /// [type] is `transfer`, `promotion` or `demotion`.
  Future<ManageRoster> transferStudent(
    int classId,
    int token, {
    required int toClassId,
    required String type,
    required String reason,
  }) async {
    final json = await _apiClient.post<Map<String, dynamic>>(
      '${AppConstants.classStudentEndpoint(classId, token)}/transfer',
      data: {'toClassId': toClassId, 'type': type, 'reason': reason},
    );
    return ManageRoster.fromJson(json);
  }

  /// What linking the extra student to the member would do (#1135). Changes
  /// nothing. A refusal is an [ApiException] carrying the server's sentence.
  Future<LinkPreview> linkPreview(int extraToken, int memberToken) async {
    final json = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.adminExtraStudentLinkEndpoint(extraToken, memberToken),
    );
    return LinkPreview.fromJson(json);
  }

  /// Move the extra student's records to the member and remove the extra
  /// student. Throws [LinkRecordsChanged] when the records moved since the
  /// preview, and an [ApiException] for any other refusal.
  Future<void> linkStudent(
    int extraToken,
    int memberToken,
    List<LinkResolution> resolutions,
  ) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        AppConstants.adminExtraStudentLinkEndpoint(extraToken, memberToken),
        data: {'resolutions': resolutions.map((r) => r.toJson()).toList()},
      );
    } on ApiException catch (e) {
      final fresh = e.body?['preview'];
      if (e.statusCode == 409 &&
          e.body?['code'] == 'records_changed' &&
          fresh is Map<String, dynamic>) {
        throw LinkRecordsChanged(e.message, LinkPreview.fromJson(fresh));
      }
      rethrow;
    }
  }
}
