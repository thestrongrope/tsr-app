import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/saved_copy.dart';
import '../models/models.dart';
import '../utils/topic_codec.dart';

/// Repository for class-related API operations and caching
class ClassesRepository {
  final ApiClient _apiClient;
  static const String _cacheBoxKey = 'classes_cache';
  static const String _classesKey = 'user_classes';
  static const String _conductionFormKeyPrefix = 'conduction_form_';
  static const String _performanceKeyPrefix = 'performance_';

  final DateTime Function()? _clock;
  final int? Function() _owner;

  /// [clock] is for tests that move time past the saved copy's expiry;
  /// [owner] for tests that sign a member in.
  ClassesRepository({
    ApiClient? apiClient,
    DateTime Function()? clock,
    int? Function()? owner,
  }) : _apiClient = apiClient ?? ApiClient(),
       _clock = clock,
       _owner = owner ?? signedInToken;

  /// The raw class list from the server. A seam for tests: [ApiClient] is a
  /// singleton with a private constructor and cannot be subclassed.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchClassJson() =>
      _apiClient.getUserClasses();

  /// The raw conduction form data from the server; a seam for tests, like
  /// [fetchClassJson].
  @visibleForTesting
  Future<Map<String, dynamic>> fetchConductionFormJson(int classId) =>
      _apiClient.get<Map<String, dynamic>>(
        AppConstants.classConductionNewEndpoint(classId),
      );

  /// The raw performance figures from the server; a seam for tests, like
  /// [fetchClassJson].
  @visibleForTesting
  Future<Map<String, dynamic>> fetchPerformanceJson(
    int classId,
    Map<String, dynamic> queryParams,
  ) => _apiClient.get<Map<String, dynamic>>(
    AppConstants.classPerformanceEndpoint(classId),
    queryParameters: queryParams.isNotEmpty ? queryParams : null,
  );

  /// Get all classes the user is enrolled in.
  ///
  /// Always asks the server: the list carries the teacher, the role and the
  /// weekly schedule, which local reminders are scheduled from, and a copy
  /// with no expiry went stale whenever anything changed on the web. The saved
  /// copy is used only when the server cannot be reached (no connection, a
  /// timeout, or a 5xx) and it is under [savedCopyMaxAge] old. A refusal (401, 403, any other 4xx) is not a reason to
  /// show an old list, so it is thrown.
  ///
  /// [allowSaved] false is for a member who asked to refresh: the server's
  /// answer or an error, never the saved copy passed off as fresh.
  Future<List<ClassModel>> getEnrolledClasses({bool allowSaved = true}) async {
    try {
      final response = await fetchClassJson();
      final classes = response
          .map((json) => ClassModel.fromJson(json))
          .toList();
      await _cacheClasses(classes);
      return classes;
    } on ApiException catch (e) {
      debugPrint('Error fetching classes: $e');
      if (!isUnreachable(e) || !allowSaved) rethrow;
      final cached = await _getCachedClasses();
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Get detailed info for a single class
  Future<ClassModel> getClassDetail(int classId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.classDetailEndpoint(classId),
      );
      return ClassModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching class detail: $e');
      rethrow;
    }
  }

  /// Get class sessions
  Future<List<ClassSession>> getClassSessions(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        AppConstants.classSessionsEndpoint(classId),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return response
          .map((json) => ClassSession.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      rethrow;
    }
  }

  /// Get user's attendance records for a class
  Future<List<StudentAttendance>> getMyAttendance(
    int classId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final response = await _apiClient.get<List<dynamic>>(
        AppConstants.classAttendanceEndpoint(classId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      return response
          .map(
            (json) => StudentAttendance.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
      rethrow;
    }
  }

  /// Get performance metrics for a class.
  ///
  /// Network first, like the class list: the saved copy is shown only when the
  /// server cannot be reached and it is under [savedCopyMaxAge] old.
  /// [forceRefresh] true never falls back to it.
  Future<ClassPerformance> getClassPerformance(
    int classId, {
    bool forceRefresh = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final response = await fetchPerformanceJson(classId, queryParams);
      final performance = ClassPerformance.fromJson(response);

      // Only cache if no dates provided (standard view)
      if (startDate == null && endDate == null) {
        await _cachePerformance(classId, performance);
      }
      return performance;
    } on ApiException catch (e) {
      debugPrint('Error fetching performance: $e');
      // Only the standard view is saved, so a date-filtered one has no copy.
      final hasSavedView = startDate == null && endDate == null;
      if (!isUnreachable(e) || forceRefresh || !hasSavedView) rethrow;
      final cached = await _getCachedPerformance(classId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Get quizzes for a class (paginated)
  Future<QuizListResponse> getClassQuizzes(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.classQuizzesEndpoint(classId),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return QuizListResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching quizzes: $e');
      rethrow;
    }
  }

  /// Get quiz detail
  Future<Quiz> getQuizDetail(int quizId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.quizDetailEndpoint(quizId),
      );
      return Quiz.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching quiz detail: $e');
      rethrow;
    }
  }

  /// Get quiz questions (for taking quiz)
  Future<QuizQuestionsResponse> getQuizQuestions(
    int quizId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.quizQuestionsEndpoint(quizId),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return QuizQuestionsResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching quiz questions: $e');
      rethrow;
    }
  }

  /// Submit quiz responses
  Future<QuizSubmitResponse> submitQuiz(
    int quizId,
    List<Map<String, dynamic>> responses,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.quizSubmitEndpoint(quizId),
        data: {'responses': responses},
      );
      return QuizSubmitResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error submitting quiz: $e');
      rethrow;
    }
  }

  /// Get user's score for a specific quiz
  Future<Map<String, dynamic>> getQuizScore(int quizId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.quizScoreEndpoint(quizId),
      );
      return response;
    } catch (e) {
      debugPrint('Error fetching quiz score: $e');
      rethrow;
    }
  }

  /// Get quiz history/scores for a class
  Future<List<QuizScoreHistory>> getClassQuizHistory(
    int classId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final response = await _apiClient.get<List<dynamic>>(
        AppConstants.classScoresEndpoint(classId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      return response
          .map(
            (json) => QuizScoreHistory.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching quiz history: $e');
      rethrow;
    }
  }

  // ============ Class Conduction (teacher/admin) ============

  /// Get paginated conduction records for a class.
  Future<ConductionListResponse> getConductionSessions(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.classConductionEndpoint(classId),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return ConductionListResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching conduction sessions: $e');
      rethrow;
    }
  }

  /// Get form data (class, students, holy Quran, next dates) for adding a
  /// conduction record. A copy is kept so the form opens with no network: a
  /// teacher can fill a record where there is no signal and send it later.
  Future<ConductionFormData> getConductionFormData(int classId) async {
    final key = '$_conductionFormKeyPrefix$classId';
    try {
      final response = await fetchConductionFormJson(classId);
      try {
        await (await _savedCopies()).save(key, jsonEncode(response));
      } catch (e) {
        debugPrint('Error caching conduction form data: $e');
      }
      return ConductionFormData.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching conduction form data: $e');
      if (isUnreachable(e)) {
        try {
          final saved = (await _savedCopies()).read(key);
          if (saved is String) {
            return ConductionFormData.fromJson(jsonDecode(saved));
          }
        } catch (readError) {
          debugPrint('Error reading cached conduction form data: $readError');
        }
      }
      rethrow;
    }
  }

  /// Get the syllabus topics offered for this class's level.
  ///
  /// Returns an empty catalog rather than throwing, and that is the point: a
  /// level with no syllabus, a subject the syllabus does not cover and a failed
  /// request are all cases where the form must fall back to the free-text topic
  /// field. Letting this fail the whole form, or leaving a dropdown that can
  /// only offer "Other", would both be worse than the box teachers had before.
  /// Asked for as `dynamic` on purpose: a level with no syllabus comes back as
  /// `[]`, and `get<Map<String, dynamic>>` would fail that cast — throwing on
  /// the most common case, for a body the server sends by design.
  Future<SyllabusTopics> getSyllabusTopics(int classId) async {
    try {
      final response = await _apiClient.get<dynamic>(
        AppConstants.classSyllabusTopicsEndpoint(classId),
      );
      return syllabusTopicsFromJson(response);
    } catch (e) {
      debugPrint('Error fetching syllabus topics: $e');
      return const <String, SubjectCatalog>{};
    }
  }

  /// Get a single conduction record with attendance for editing.
  Future<ConductionEditData> getConductionSession(
    int classId,
    int sessionId,
  ) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.classConductionSessionEndpoint(classId, sessionId),
      );
      return ConductionEditData.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching conduction session: $e');
      rethrow;
    }
  }

  /// Get the Holy Quran surah list for the conduction form's dropdown.
  ///
  /// Returns an empty list rather than throwing: the form hides the Quran
  /// section when there is nothing to offer, and the edit form falls back to
  /// this when the session payload carries no list (e.g. an older server).
  Future<List<HolyQuranSurah>> getHolyQuran() async {
    try {
      final response = await _apiClient.get<dynamic>(
        AppConstants.holyQuranEndpoint,
      );
      if (response is List) {
        return response
            .map((e) => HolyQuranSurah.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return const <HolyQuranSurah>[];
    } catch (e) {
      debugPrint('Error fetching Holy Quran surahs: $e');
      return const <HolyQuranSurah>[];
    }
  }

  /// Check whether a date already has a conduction record.
  Future<ConductionDateCheck> checkConductionDate(
    int classId,
    DateTime date,
  ) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.classConductionCheckEndpoint(classId),
        queryParameters: {'date': date.toIso8601String().split('T').first},
      );
      return ConductionDateCheck.fromJson(response);
    } catch (e) {
      debugPrint('Error checking conduction date: $e');
      rethrow;
    }
  }

  /// Create a new conduction record.
  Future<ConductionSession> addConduction(
    int classId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.classConductionEndpoint(classId),
        data: payload,
      );
      return ConductionSession.fromJson(response);
    } catch (e) {
      debugPrint('Error adding conduction: $e');
      rethrow;
    }
  }

  /// Update an existing conduction record.
  Future<ConductionSession> updateConduction(
    int classId,
    int sessionId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        AppConstants.classConductionSessionEndpoint(classId, sessionId),
        data: payload,
      );
      return ConductionSession.fromJson(response);
    } catch (e) {
      debugPrint('Error updating conduction: $e');
      rethrow;
    }
  }

  // ============ Caching Methods ============

  Future<Box> _openCacheBox() async {
    return await Hive.openBox(_cacheBoxKey);
  }

  Future<SavedCopies> _savedCopies() async =>
      SavedCopies(await _openCacheBox(), owner: _owner, clock: _clock);

  Future<void> _cacheClasses(List<ClassModel> classes) async {
    try {
      final saved = await _savedCopies();
      final jsonList = classes
          .map(
            (c) => {
              'id': c.id,
              'code': c.code,
              'name': c.name,
              'level': c.level,
              'levelName': c.levelName,
              'language': c.language,
              'gender': c.gender,
              'status': c.status,
              'location': c.location,
              'teacherName': c.teacherName,
              'teacherMobile': c.teacherMobile,
              'format': c.format,
              'startedOn': c.startedOn?.toIso8601String(),
              'role': c.role,
              'joinUrl': c.joinUrl,
              'city': c.city,
              'country': c.country,
              'tags': c.tags,
              'studentCount': c.studentCount,
              'schedules': c.schedules
                  .map(
                    (s) => {
                      'day': s.day,
                      'hour': s.hour,
                      'minute': s.minute,
                      'timezone': s.timezone,
                    },
                  )
                  .toList(),
            },
          )
          .toList();
      // As JSON text: Hive hands nested maps back as Map<dynamic, dynamic> once the
      // box is reopened from disk, which the model's casts reject.
      await saved.save(_classesKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error caching classes: $e');
    }
  }

  Future<List<ClassModel>?> _getCachedClasses() async {
    try {
      final saved = await _savedCopies();
      final data = saved.read(_classesKey);
      if (data is! String) return null;
      return (jsonDecode(data) as List)
          .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading cached classes: $e');
      return null;
    }
  }

  Future<void> _cachePerformance(
    int classId,
    ClassPerformance performance,
  ) async {
    try {
      final saved = await _savedCopies();
      await saved.save('$_performanceKeyPrefix$classId', {
        'totalSessions': performance.totalSessions,
        'attendedSessions': performance.attendedSessions,
        'attendancePercent': performance.attendancePercent,
        'totalRecitation': performance.totalRecitation,
        'averageRecitation': performance.averageRecitation,
        'quizzesAttempted': performance.quizzesAttempted,
        'quizAverageScore': performance.quizAverageScore,
      });
    } catch (e) {
      debugPrint('Error caching performance: $e');
    }
  }

  Future<ClassPerformance?> _getCachedPerformance(int classId) async {
    try {
      final saved = await _savedCopies();
      final data = saved.read('$_performanceKeyPrefix$classId');
      if (data == null) return null;
      return ClassPerformance.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('Error reading cached performance: $e');
      return null;
    }
  }

  /// Clear all cached data
  ///
  /// Throws when the box cannot be cleared, so a caller that must know (account
  /// deletion) does.
  Future<void> clearCache() async {
    final box = await _openCacheBox();
    await box.clear();
  }
}
