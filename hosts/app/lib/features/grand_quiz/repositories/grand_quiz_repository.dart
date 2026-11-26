import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/user.dart';
import '../models/models.dart';

/// Repository for Grand/Mega Quiz API operations
class GrandQuizRepository {
  static const String _quizInfoCacheKeyPrefix = 'grand_quiz_info';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  GrandQuizRepository({Dio? dio, FlutterSecureStorage? secureStorage})
    : _dio = dio ?? Dio(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// External API URL for quiz info
  static const String quizInfoUrl =
      'https://account.thestrongrope.com/api/quiz_info.php';

  /// Fetch quiz info from the external API
  ///
  /// Supports three authentication modes:
  /// 1. No auth (public access)
  /// 2. Firebase token only (view personalized data)
  /// 3. Dual auth - Firebase + User token (required for registration)
  Future<QuizInfoResponse> getQuizInfo({
    User? currentUser,
    bool forceRefresh = false,
  }) async {
    try {
      final firebaseToken = await _secureStorage.read(
        key: AppConstants.firebaseTokenKey,
      );
      final cacheKey = _cacheKeyFor(
        userToken: currentUser?.token,
        hasFirebaseToken: firebaseToken != null && firebaseToken.isNotEmpty,
      );

      // Check cache first
      if (!forceRefresh) {
        final cached = await _getCachedQuizInfo(cacheKey);
        if (cached != null) {
          debugPrint('📦 Using cached quiz info ($cacheKey)');
          return cached;
        }
      }

      debugPrint('🔄 Fetching quiz info from API...');

      // Build request headers
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Add Firebase token if available (for personalized data)
      if (firebaseToken != null) {
        headers['Authorization'] = 'Bearer $firebaseToken';
      }

      // Build URL with user token if available (for dual auth / registration)
      String url = quizInfoUrl;
      if (currentUser != null) {
        url = '$quizInfoUrl?token=${currentUser.token}';
      }

      final response = await _dio.get(
        url,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final quizResponse = QuizInfoResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        // Cache the response if successful
        if (quizResponse.success && quizResponse.data != null) {
          await _cacheQuizInfo(cacheKey, quizResponse);
        }

        return quizResponse;
      }

      return const QuizInfoResponse(
        success: false,
        error: 'Failed to fetch quiz info',
      );
    } on DioException catch (e) {
      debugPrint('🔴 Quiz info fetch error: ${e.message}');

      // Try to return cached data on network error
      final firebaseToken = await _secureStorage.read(
        key: AppConstants.firebaseTokenKey,
      );
      final cacheKey = _cacheKeyFor(
        userToken: currentUser?.token,
        hasFirebaseToken: firebaseToken != null && firebaseToken.isNotEmpty,
      );
      final cached = await _getCachedQuizInfo(cacheKey);
      if (cached != null) {
        debugPrint(
          '📦 Returning cached quiz info due to network error ($cacheKey)',
        );
        return cached;
      }

      return QuizInfoResponse(success: false, error: _getErrorMessage(e));
    } catch (e) {
      debugPrint('🔴 Quiz info fetch error: $e');
      return QuizInfoResponse(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  String _cacheKeyFor({
    required int? userToken,
    required bool hasFirebaseToken,
  }) {
    if (userToken != null) {
      return '${_quizInfoCacheKeyPrefix}_u_$userToken';
    }
    return hasFirebaseToken
        ? '${_quizInfoCacheKeyPrefix}_auth'
        : '${_quizInfoCacheKeyPrefix}_guest';
  }

  /// Cache quiz info response
  Future<void> _cacheQuizInfo(
    String cacheKey,
    QuizInfoResponse response,
  ) async {
    try {
      final box = await Hive.openBox(AppConstants.cacheBoxKey);
      await box.put(cacheKey, {
        'data': _serializeResponse(response),
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Quiz info cached');
    } catch (e) {
      debugPrint('⚠️ Failed to cache quiz info: $e');
    }
  }

  /// Get cached quiz info if not expired
  Future<QuizInfoResponse?> _getCachedQuizInfo(String cacheKey) async {
    try {
      final box = await Hive.openBox(AppConstants.cacheBoxKey);
      final cached = box.get(cacheKey);

      if (cached != null && cached is Map) {
        final timestamp = DateTime.tryParse(
          cached['timestamp'] as String? ?? '',
        );
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < _cacheDuration) {
          return _deserializeResponse(cached['data'] as Map);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to read cached quiz info: $e');
    }
    return null;
  }

  /// Clear cached quiz info
  ///
  /// Throws when the box cannot be cleared, so account deletion can report it.
  Future<void> clearCache() async {
    final box = await Hive.openBox(AppConstants.cacheBoxKey);
    final keysToDelete = box.keys
        .where(
          (key) => key is String && key.startsWith(_quizInfoCacheKeyPrefix),
        )
        .toList();
    await box.deleteAll(keysToDelete);
  }

  /// Serialize response for caching
  Map<String, dynamic> _serializeResponse(QuizInfoResponse response) {
    if (response.data == null) {
      return {'success': false, 'error': response.error};
    }

    final data = response.data!;
    return {
      'success': true,
      'data': {
        'type': data.type,
        'name': data.name,
        'series': data.series,
        'description': data.description,
        'status': data.status,
        'message': data.message,
        'is_superuser': data.isSuperuser,
        'timing': {
          'registration_start': data.timing.registrationStart
              ?.toIso8601String(),
          'quiz_stop': data.timing.quizStop?.toIso8601String(),
        },
        'episodes': data.episodes != null
            ? {
                'total': data.episodes!.total,
                'current_day': data.episodes!.currentDay,
                'current_episode': data.episodes!.currentEpisode,
                'next_episode': data.episodes!.nextEpisode,
                'list': data.episodes!.list
                    .map(
                      (e) => {
                        'id': e.id,
                        'number': e.number,
                        'status': e.status,
                        'is_accessible': e.isAccessible,
                        'start': e.start?.toIso8601String(),
                        'end': e.end?.toIso8601String(),
                        'form_id': e.formId,
                      },
                    )
                    .toList(),
              }
            : null,
        'banner': data.banner,
        'colors': {
          'primary': _colorToHex(data.colors.primary),
          'secondary': _colorToHex(data.colors.secondary),
          'background': _colorToHex(data.colors.background),
          'text': _colorToHex(data.colors.text),
        },
        'mode': data.mode,
        'youtube_url': data.youtubeUrl,
        'admin_url': data.adminUrl,
        'auth': {
          'method': data.auth.method,
          'can_register': data.auth.canRegister,
          'user_token': data.auth.userToken,
        },
        'can_take_part': data.canTakePart,
      },
    };
  }

  /// Convert Color to hex string
  String _colorToHex(Color color) {
    final r = (color.r * 255.0).round() & 0xff;
    final g = (color.g * 255.0).round() & 0xff;
    final b = (color.b * 255.0).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  /// Deserialize cached response
  QuizInfoResponse _deserializeResponse(Map cached) {
    return QuizInfoResponse.fromJson(Map<String, dynamic>.from(cached));
  }

  /// Get user-friendly error message from DioException
  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 429) {
          return 'Too many requests. Please try again later.';
        }
        return 'Server error. Please try again later.';
      default:
        return 'Failed to load quiz info. Please try again.';
    }
  }
}
