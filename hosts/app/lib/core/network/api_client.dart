import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import 'dart:io' show HttpClient, Platform;

import '../constants/app_constants.dart';
import 'permissions_revision_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Marks a request that has already been replayed after a token refresh, so
  /// a genuinely unauthorised call cannot loop.
  static const String _retriedKey = 'tsr_retried_after_refresh';

  /// The in-flight refresh, if any.
  ///
  /// A screen can have several requests in the air at once — the conduction
  /// form asks for the class, the syllabus catalog and the form data together —
  /// and they would all 401 within milliseconds of each other. Without this,
  /// each one asks Firebase for its own new token.
  Future<String?>? _refreshInFlight;

  /// Mints a fresh Firebase ID token and stores it.
  ///
  /// Returns null when there is no signed-in user, or Firebase declines — the
  /// cases where the stored token is genuinely beyond saving.
  Future<String?> _refreshFirebaseToken() {
    return _refreshInFlight ??= () async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;

        final token = await user.getIdToken(true);
        if (token == null || token.isEmpty) return null;

        await setFirebaseToken(token);
        return token;
      } catch (e) {
        debugPrint('Firebase token refresh failed: $e');
        return null;
      } finally {
        _refreshInFlight = null;
      }
    }();
  }

  final StreamController<String> _deletionSignals =
      StreamController<String>.broadcast();

  /// Raw `deletion_status` values seen on failed responses.
  ///
  /// The account deletion gate refuses most routes while a request is live, and
  /// refuses everything for a couple of hours after one completes — including
  /// the status endpoint itself, so polling cannot observe a completion that
  /// happens mid-session. Surfacing it from the interceptor means any screen's
  /// request updates the deletion state without that screen knowing about it.
  Stream<String> get deletionSignals => _deletionSignals.stream;

  final StreamController<void> _forbiddenSignals =
      StreamController<void>.broadcast();

  /// Fires on a 403 from any route but the permissions call itself. A 403 may
  /// mean the user's grants changed, so the permissions provider refetches.
  Stream<void> get forbiddenSignals => _forbiddenSignals.stream;

  final StreamController<String> _revisionSignals =
      StreamController<String>.broadcast();

  /// The `X-Permissions-Revision` seen on responses to any route but the
  /// permissions call itself. The permissions provider compares it with the
  /// revision it holds and refetches when they differ.
  Stream<String> get revisionSignals => _revisionSignals.stream;

  /// Reports an API failure to Crashlytics as a non-fatal.
  ///
  /// **Why this exists.** Until it did, no API failure anywhere in the app
  /// reached Crashlytics at all. `recordError` was wired in exactly one place
  /// — `main.dart`, on `PlatformDispatcher.onError` — so only *uncaught*
  /// errors were ever reported, and every screen that catches its exception to
  /// show a snackbar was, by doing the right thing for the user, silently
  /// discarding the only evidence. Issue #376 was a server-side 500 on every
  /// Not Conducted save; it was invisible in the dashboard and came to light
  /// because a teacher screenshotted the snackbar.
  ///
  /// **Every failure that reaches a caller is reported**, not just 5xx. The
  /// first cut of this filtered to `statusCode >= 500` on the argument that
  /// 4xx and transport errors are routine. That argument protects the
  /// dashboard at the cost of the thing it is for: a 403 nobody expected, or a
  /// 422 on a form that should have validated, is a bug, and the only way to
  /// learn it is happening is to be told. Better recorded and ignored than
  /// missing.
  ///
  /// **What that does not include, and why it needs no filter.** A 401 is the
  /// ordinary hourly token expiry. When the refresh above succeeds the
  /// interceptor returns through `handler.resolve` and never arrives here, so
  /// silent recoveries cost nothing — the exclusion is structural, not a rule
  /// written down here that could drift out of step with the retry logic. What
  /// *does* arrive is a 401 whose refresh or replay failed, and that one is a
  /// user staring at a logged-out app. It belongs in the dashboard.
  ///
  /// The one real exclusion is [DioExceptionType.cancel]: a cancelled request
  /// is the app's own doing — a screen disposed, a search superseded — and is
  /// not a failure anyone needs to see.
  ///
  /// **Status, or the Dio failure type when there is no response.** Timeouts
  /// and connection errors carry no `response` at all, so they are labelled by
  /// `error.type.name` — `connectionError`, `receiveTimeout`. This is why the
  /// label is built from `error.response?.statusCode` and never from
  /// `ApiException.fromDioException(...).statusCode`: that mapping turns an
  /// *unknown* Dio failure into a synthetic 500 and would file every dropped
  /// connection under "the server broke".
  ///
  /// A breadcrumb goes in first. Crashlytics attaches recent `log()` lines to
  /// whatever is reported next, so even a failure that is later judged noise
  /// still leaves a trail on the report that matters.
  ///
  /// Failures here are swallowed. Telemetry must never be the reason a request
  /// error fails to reach the screen that asked for it, and in a debug or test
  /// build Crashlytics may not be initialised at all.
  void _reportApiError(DioException error) {
    if (kIsWeb) return;
    if (error.type == DioExceptionType.cancel) return;

    final request = error.requestOptions;
    final status = error.response?.statusCode;
    final label = status?.toString() ?? error.type.name;
    final reason = 'API ${request.method} ${request.path} -> $label';

    try {
      FirebaseCrashlytics.instance.log(reason);
      FirebaseCrashlytics.instance.recordError(
        error,
        error.stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (e) {
      // Crashlytics unavailable (not initialised, or a platform without it).
      debugPrint('Failed to report API error to Crashlytics: $e');
    }
  }

  /// Initialize the API client
  void initialize() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Local dev: the tsr_mobileapi container serves HTTPS on
    // https://127.0.0.1:4005 with a self-signed certificate. Dart's
    // HttpClient rejects it by default, so in debug builds only we trust
    // localhost certs. Release builds keep full certificate validation
    // (prod uses a real CA-signed cert on mobile-api.thestrongrope.com).
    // Never in a browser: it has no HttpClient to configure, and the override
    // made every call fail there (#1175).
    if (kDebugMode && !kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient()
            ..badCertificateCallback = (cert, host, port) =>
                host == '127.0.0.1' || host == 'localhost';
          return client;
        },
      );
    }

    // Add request interceptor for authentication and device info
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add Firebase ID token to requests
          final token = await _secureStorage.read(
            key: AppConstants.firebaseTokenKey,
          );
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Add device and app info to headers
          try {
            final packageInfo = await PackageInfo.fromPlatform();
            options.headers['X-App-Version'] =
                '${packageInfo.version}+${packageInfo.buildNumber}';

            final deviceInfo = DeviceInfoPlugin();
            if (kIsWeb) {
              final webInfo = await deviceInfo.webBrowserInfo;
              options.headers['X-Device-Info'] =
                  '${webInfo.browserName} ${webInfo.platform}';
              options.headers['X-Platform-Info'] = 'Web ${webInfo.userAgent}';
            } else if (!kIsWeb && Platform.isAndroid) {
              final androidInfo = await deviceInfo.androidInfo;
              options.headers['X-Device-Info'] =
                  '${androidInfo.manufacturer} ${androidInfo.model}';
              options.headers['X-Platform-Info'] =
                  'Android ${androidInfo.version.release}';
            } else if (!kIsWeb && Platform.isIOS) {
              final iosInfo = await deviceInfo.iosInfo;
              options.headers['X-Device-Info'] = iosInfo.utsname.machine;
              options.headers['X-Platform-Info'] =
                  'iOS ${iosInfo.systemVersion}';
            } else if (!kIsWeb && Platform.isMacOS) {
              final macInfo = await deviceInfo.macOsInfo;
              options.headers['X-Device-Info'] =
                  '${macInfo.computerName} ${macInfo.model}';
              options.headers['X-Platform-Info'] = 'macOS ${macInfo.osRelease}';
            } else if (!kIsWeb && Platform.isWindows) {
              final windowsInfo = await deviceInfo.windowsInfo;
              options.headers['X-Device-Info'] = windowsInfo.computerName;
              options.headers['X-Platform-Info'] =
                  'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
            } else if (!kIsWeb && Platform.isLinux) {
              final linuxInfo = await deviceInfo.linuxInfo;
              options.headers['X-Device-Info'] = linuxInfo.name;
              options.headers['X-Platform-Info'] = 'Linux ${linuxInfo.version}';
            }
          } catch (e) {
            debugPrint("Failed to get device/package info: $e");
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          // A 401 is almost always an expired ID token rather than a signed-out
          // user: Firebase mints them with a one-hour life, and the refresh
          // token behind them lasts far longer. So ask Firebase for a new one
          // and replay the request before surfacing anything.
          //
          // This used to delete the stored token and give up. That left the
          // next request with no token at all, so it 401'd too, and the app
          // stayed broken until the user signed out and back in -- which is not
          // a recovery anybody guesses.
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra[_retriedKey] != true) {
            final refreshed = await _refreshFirebaseToken();

            if (refreshed != null) {
              final options = error.requestOptions;
              options.extra = {...options.extra, _retriedKey: true};
              options.headers['Authorization'] = 'Bearer $refreshed';

              try {
                final response = await _dio.fetch<dynamic>(options);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                // Fall through on a second failure; the token was not the
                // problem, or the account really is gone.
                //
                // Reported here rather than at the foot of the interceptor,
                // because this path returns early and would otherwise be the
                // one failure that reaches a user and reaches no dashboard:
                // a fresh token was minted and the request still died.
                _reportApiError(retryError);
                return handler.next(retryError);
              }
            }

            // No user, or Firebase refused to mint a token. Now the stored
            // token really is worthless.
            await _secureStorage.delete(key: AppConstants.firebaseTokenKey);
          }

          // A refusal from the account deletion gate carries the state that
          // caused it. Announce it; the deletion feature decides what it means.
          final deletionStatus = ApiException.fromDioException(
            error,
          ).deletionStatus;
          if (deletionStatus != null && !_deletionSignals.isClosed) {
            _deletionSignals.add(deletionStatus);
          }

          if (error.response?.statusCode == 403 &&
              !error.requestOptions.path.endsWith('/me/permissions') &&
              !_forbiddenSignals.isClosed) {
            _forbiddenSignals.add(null);
          }

          _reportApiError(error);

          handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      PermissionsRevisionInterceptor((revision) {
        if (!_revisionSignals.isClosed) _revisionSignals.add(revision);
      }),
    );

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        _QrSafeLogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (object) {
            debugPrint(object.toString());
          },
        ),
      );
    }
  }

  /// Get current Dio instance
  Dio get dio => _dio;

  /// Store Firebase ID token securely
  Future<void> setFirebaseToken(String token) async {
    await _secureStorage.write(
      key: AppConstants.firebaseTokenKey,
      value: token,
    );
  }

  /// Get stored Firebase ID token
  Future<String?> getFirebaseToken() async {
    return await _secureStorage.read(key: AppConstants.firebaseTokenKey);
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.firebaseTokenKey);
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
  }

  /// Link Firebase account with backend (authentication)
  Future<Map<String, dynamic>> linkAccount(String firebaseToken) async {
    try {
      // Store token for subsequent requests
      await setFirebaseToken(firebaseToken);

      final response = await _dio.post(
        AppConstants.authEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $firebaseToken'}),
      );

      if (response.statusCode == 200) {
        return response.data['me'] as Map<String, dynamic>;
      } else {
        throw ApiException('Authentication failed', response.statusCode ?? 500);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw ApiException('Unexpected error during authentication', 500);
    }
  }

  /// Get current user information
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get('/me');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to get user information',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw ApiException('Unexpected error getting user info', 500);
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/me', data: data);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to update profile',
          response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw ApiException('Unexpected error updating profile', 500);
    }
  }

  /// Get what the current user may do (permission names, scopes, revision).
  ///
  /// With [ifNoneMatch], the revision of the copy the caller holds, the server
  /// answers 304 when nothing changed and this returns null. 304 is accepted
  /// for this call only.
  Future<Map<String, dynamic>?> getPermissions({String? ifNoneMatch}) async {
    try {
      final response = await _dio.get(
        '/me/permissions',
        options: Options(
          headers: ifNoneMatch == null
              ? null
              : {'If-None-Match': '"$ifNoneMatch"'},
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304) return null;
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (_) {
      throw const ApiException('Unexpected error getting permissions', 500);
    }
  }

  /// Get user classes
  Future<List<Map<String, dynamic>>> getUserClasses() async {
    try {
      // include=managed adds the classes the user manages (role 'managing').
      // Reminder scoping (PermissionsPayload.remindsConduction) must stay in
      // place whenever this is sent, or every managed class arms a reminder.
      final response = await _dio.get(
        AppConstants.classesEndpoint,
        queryParameters: {'include': 'managed'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw ApiException('Failed to get classes', response.statusCode ?? 500);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw ApiException('Unexpected error getting classes', 500);
    }
  }

  /// Register device for push notifications
  Future<void> registerDevice(String fcmToken) async {
    try {
      debugPrint(
        '🔵 Registering device with FCM token: ${fcmToken.substring(0, 20)}...',
      );
      final response = await _dio.post(
        AppConstants.devicesEndpoint,
        data: {'fcmToken': fcmToken, 'platform': 'mobile'},
      );
      debugPrint('🟢 Device registration successful: ${response.statusCode}');
    } on DioException catch (e) {
      // Don't throw error for device registration failures
      debugPrint(
        '🔴 Failed to register device: ${e.response?.statusCode} - ${e.message}',
      );
      debugPrint('🔴 Error response: ${e.response?.data}');
    } catch (e) {
      debugPrint('🔴 Unexpected error registering device: $e');
    }
  }

  /// Unregister device for push notifications
  Future<void> unregisterDevice(String fcmToken) async {
    try {
      debugPrint(
        '🔵 Unregistering device with FCM token: ${fcmToken.substring(0, 20)}...',
      );
      final response = await _dio.delete(
        AppConstants.devicesEndpoint,
        data: {'fcmToken': fcmToken},
      );
      debugPrint('🟢 Device unregistration successful: ${response.statusCode}');
    } on DioException catch (e) {
      // Don't throw error for device unregistration failures
      debugPrint(
        '🔴 Failed to unregister device: ${e.response?.statusCode} - ${e.message}',
      );
      debugPrint('🔴 Error response: ${e.response?.data}');
    } catch (e) {
      debugPrint('🔴 Unexpected error unregistering device: $e');
    }
  }

  /// Generic GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Generic POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Generic PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Generic DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Handle Dio exceptions and convert to custom exceptions
  ApiException _handleDioException(DioException e) =>
      ApiException.fromDioException(e);
}

/// Custom API exception class
class ApiException implements Exception {
  final String message;
  final int statusCode;

  /// The decoded response body, when the server sent a JSON object.
  ///
  /// Kept because some responses can only be understood from the body: a 403
  /// from the account-deletion gate is a restricted session, while a 403
  /// without `deletion_status` is an ordinary permission refusal, and the
  /// status code alone cannot tell them apart.
  final Map<String, dynamic>? body;

  const ApiException(this.message, this.statusCode, {this.body});

  /// Map a Dio failure onto an ApiException, keeping the body.
  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(AppConstants.timeoutErrorMessage, 408);
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 500;
        final data = e.response?.data;
        String message = 'Server error occurred';
        Map<String, dynamic>? body;

        if (data is Map<String, dynamic>) {
          body = data;
          message =
              data['detail'] ?? data['message'] ?? 'Server error occurred';
        } else if (data is String) {
          message = data;
        }

        return ApiException(message, statusCode, body: body);
      case DioExceptionType.cancel:
        return ApiException('Request was cancelled', 0);
      case DioExceptionType.connectionError:
        return ApiException(AppConstants.networkErrorMessage, 0);
      default:
        return ApiException(AppConstants.genericErrorMessage, 500);
    }
  }

  /// The raw `deletion_status` the API sent, or null if it sent none.
  ///
  /// Mapping the string onto a status enum is the deletion feature's job; this
  /// only surfaces what arrived.
  String? get deletionStatus => body?['deletion_status'] as String?;

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';

  /// Check if the error is related to authentication
  bool get isAuthError => statusCode == 401;

  /// Check if the error is a network error
  bool get isNetworkError => statusCode == 0;

  /// Check if the error is a server error
  bool get isServerError => statusCode >= 500;

  /// Check if the error is a client error
  bool get isClientError => statusCode >= 400 && statusCode < 500;
}

/// The debug log of every response body, except the WhatsApp link's QR code
/// (#693): it is a live credential and must never reach a log.
class _QrSafeLogInterceptor extends LogInterceptor {
  _QrSafeLogInterceptor({
    super.requestBody,
    super.responseBody,
    super.logPrint,
  });

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final path = response.requestOptions.path;
    if (path == AppConstants.adminWhatsappLinkQrEndpoint ||
        path.startsWith(AppConstants.adminMembersPrefix) ||
        path.startsWith(AppConstants.adminExtraStudentsPrefix)) {
      handler.next(response);
      return;
    }
    super.onResponse(response, handler);
  }
}
