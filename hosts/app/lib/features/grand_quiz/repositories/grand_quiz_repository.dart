import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../models/models.dart';

/// Repository for Grand/Mega Quiz API operations
class GrandQuizRepository {
  static const String _quizInfoCacheKeyPrefix = 'grand_quiz_info';

  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  final DateTime Function() _clock;

  GrandQuizRepository({
    ApiClient? apiClient,
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
  }) : _apiClient = apiClient ?? ApiClient(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  /// The quiz info body from the API (`GET /quiz/info`): the object itself,
  /// with no `{success, data}` wrapper. Public: the API answers a signed-out
  /// caller, and the shared client adds the Firebase bearer when there is one
  /// (the API makes that member the caller). A seam for tests.
  @visibleForTesting
  Future<Map<String, dynamic>> fetchQuizInfoJson() =>
      _apiClient.get<Map<String, dynamic>>(
        AppConstants.quizInfoEndpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

  /// Whether a Firebase token is stored: it only picks the cache key. A seam
  /// for tests, which have no secure storage.
  @visibleForTesting
  Future<bool> hasFirebaseToken() async {
    final token = await _secureStorage.read(key: AppConstants.firebaseTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Fetch quiz info from the API.
  ///
  /// The caller is signed out, or a signed-in member when a Firebase token is
  /// stored (no other credential is sent). Kept for
  /// [AppConstants.quizInfoCacheDuration]; on a network error a copy is returned
  /// only while it is still that fresh (older ones are not).
  Future<QuizInfoResponse> getQuizInfo({
    User? currentUser,
    bool forceRefresh = false,
  }) async {
    String? cacheKey;
    try {
      cacheKey = _cacheKeyFor(
        userToken: currentUser?.token,
        hasFirebaseToken: await hasFirebaseToken(),
      );
      if (!forceRefresh) {
        final cached = await _getCachedQuizInfo(cacheKey);
        if (cached != null) {
          debugPrint('📦 Using cached quiz info ($cacheKey)');
          return cached;
        }
      }

      debugPrint('🔄 Fetching quiz info from API...');
      final quizResponse = QuizInfoResponse(
        success: true,
        data: QuizInfo.fromJson(await fetchQuizInfoJson()),
      );
      await _cacheQuizInfo(cacheKey, quizResponse);
      return quizResponse;
    } on ApiException catch (e) {
      debugPrint('🔴 Quiz info fetch error: ${e.message}');
      final cached = cacheKey == null
          ? null
          : await _getCachedQuizInfo(cacheKey);
      if (cached != null) {
        debugPrint(
          '📦 Returning cached quiz info due to network error ($cacheKey)',
        );
        return cached;
      }

      return QuizInfoResponse(success: false, error: _getErrorMessage(e));
    } catch (e) {
      debugPrint('🔴 Quiz info fetch error: $e');
      return const QuizInfoResponse(
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
        'timestamp': _clock().toIso8601String(),
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
            _clock().difference(timestamp) <
                AppConstants.quizInfoCacheDuration) {
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

  /// Get user-friendly error message from an [ApiException]
  String _getErrorMessage(ApiException e) {
    switch (e.statusCode) {
      case 408:
        return 'Connection timed out. Please try again.';
      case 0:
        return 'No internet connection. Please check your network.';
      case 429:
        return 'Too many requests. Please try again later.';
      default:
        return 'Server error. Please try again later.';
    }
  }
}
