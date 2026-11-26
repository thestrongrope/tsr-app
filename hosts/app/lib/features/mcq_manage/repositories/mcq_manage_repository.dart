import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/mcq_manage.dart';
import '../models/mcq_offline.dart';

/// Repository for MCQ management (teacher/admin) API operations.
class McqManageRepository {
  final ApiClient _apiClient;

  McqManageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Paginated list of all MCQs for a class (including drafts/deactivated).
  Future<McqManageListResponse> getManageQuizzes(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.mcqManageEndpoint(classId),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return McqManageListResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching manage quizzes: $e');
      rethrow;
    }
  }

  /// Create a new quiz shell for a class.
  Future<int> createQuiz(
    int classId, {
    required String name,
    required String topic,
    int restrictToClass = 1,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.mcqCreateEndpoint(classId),
        data: {
          'name': name,
          'topic': topic,
          'restrictToClass': restrictToClass,
        },
      );
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error creating quiz: $e');
      rethrow;
    }
  }

  /// Full quiz detail (with questions) for editing.
  Future<McqManageDetail> getQuizDetail(int quizId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.mcqManageDetailEndpoint(quizId),
      );
      return McqManageDetail.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching manage quiz detail: $e');
      rethrow;
    }
  }

  /// Save quiz metadata + questions (replaces all questions).
  Future<void> updateQuiz(
    int quizId, {
    required String name,
    required String topic,
    int? restrictToClass,
    required List<McqManageQuestion> questions,
  }) async {
    try {
      await _apiClient.put<Map<String, dynamic>>(
        AppConstants.mcqManageDetailEndpoint(quizId),
        data: {
          'name': name,
          'topic': topic,
          'restrictToClass': ?restrictToClass,
          'questions': questions.map((q) => q.toJson()).toList(),
        },
      );
    } catch (e) {
      debugPrint('Error updating quiz: $e');
      rethrow;
    }
  }

  /// Publish a quiz (sends push notifications to the class).
  Future<Map<String, dynamic>> publishQuiz(int quizId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.mcqManagePublishEndpoint(quizId),
      );
      return response;
    } catch (e) {
      debugPrint('Error publishing quiz: $e');
      rethrow;
    }
  }

  /// Deactivate or reactivate a quiz.
  Future<Map<String, dynamic>> setQuizDeactivated(
    int quizId, {
    required bool deactivate,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.mcqManageDeactivateEndpoint(quizId),
        data: {'deactivate': deactivate},
      );
      return response;
    } catch (e) {
      debugPrint('Error toggling quiz deactivation: $e');
      rethrow;
    }
  }

  /// Classes the member may copy from or to (`mcqs:copy`).
  Future<List<McqCopyClass>> getCopyClasses() async {
    final response = await _apiClient.get<List<dynamic>>(
      AppConstants.mcqCopyClassesEndpoint,
    );
    return response
        .map((e) => McqCopyClass.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Topics of a class the member may copy from.
  Future<List<String>> getCopyTopics(int classId) async {
    final response = await _apiClient.get<List<dynamic>>(
      AppConstants.mcqCopyTopicsEndpoint(classId),
    );
    return response.map((e) => e.toString()).toList();
  }

  /// Quizzes of a class and topic the member may copy from.
  Future<List<McqCopyQuiz>> getCopyQuizzes(int classId, String topic) async {
    final response = await _apiClient.get<List<dynamic>>(
      AppConstants.mcqCopyQuizzesEndpoint(classId),
      queryParameters: {'topic': topic},
    );
    return response
        .map((e) => McqCopyQuiz.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Copy a quiz to another class.
  Future<int> copyQuiz(int quizId, int targetClassId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.mcqManageCopyEndpoint(quizId),
        data: {'targetClassId': targetClassId},
      );
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error copying quiz: $e');
      rethrow;
    }
  }

  /// Per-student scores for a quiz.
  Future<McqScoresResponse> getQuizScores(int quizId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.mcqManageScoresEndpoint(quizId),
      );
      return McqScoresResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching quiz scores: $e');
      rethrow;
    }
  }

  /// Distinct topics already used by a class.
  Future<List<String>> getTopics(int classId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        AppConstants.mcqTopicsEndpoint(classId),
      );
      return response.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('Error fetching quiz topics: $e');
      rethrow;
    }
  }

  /// Standard MCQs available for a class, grouped by topic/subject.
  Future<McqStandardResponse> getStandardQuizzes(int classId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.mcqStandardEndpoint(classId),
      );
      return McqStandardResponse.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching standard quizzes: $e');
      rethrow;
    }
  }

  /// Copy a standard MCQ into a class as a spot quiz.
  Future<int> copyStandardQuiz(int classId, int mcqId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConstants.mcqStandardCopyEndpoint(classId, mcqId),
      );
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error copying standard quiz: $e');
      rethrow;
    }
  }

  /// Questions and students for recording offline answers (#409).
  Future<McqOfflineData> getOffline(int quizId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.mcqManageOfflineEndpoint(quizId),
    );
    return McqOfflineData.fromJson(response);
  }

  /// Submits every student's correct questions at once; the server saves all
  /// or none. Throws an `ApiException`: 409 carries `conflicts` in its body.
  Future<void> saveOffline(int quizId, Map<int, Set<int>> correctByToken) {
    return _apiClient.post<Map<String, dynamic>>(
      AppConstants.mcqManageOfflineEndpoint(quizId),
      data: {
        'students': [
          for (final e in correctByToken.entries)
            {'token': e.key, 'correct': e.value.toList()..sort()},
        ],
      },
    );
  }

  /// The question sheet, as PDF bytes.
  Future<List<int>> downloadSheet(int quizId) {
    return _apiClient.get<List<int>>(
      AppConstants.mcqManageSheetEndpoint(quizId),
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
