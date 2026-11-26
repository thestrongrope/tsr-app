import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/quiz_admin.dart';

/// API calls behind the quiz admin (#673). The server checks `quiz:admin` on
/// every route (and `quiz:reset` for delete-all); hiding the screen is a
/// courtesy. A refusal arrives as an `ApiException` carrying the server's own
/// words: see [quizAdminErrorMessage] for what each status means.
class QuizAdminRepository {
  final ApiClient _apiClient;

  QuizAdminRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Download and publish read or write Google Sheets inside the request, so
  /// they wait up to two minutes. Everything else keeps the normal timeout.
  static final Options slowOptions = Options(
    receiveTimeout: AppConstants.quizAdminSlowTimeout,
  );

  Future<QuizAdminState> getState() async {
    final body = await _apiClient.get<dynamic>(AppConstants.quizAdminEndpoint);
    return QuizAdminState.fromJson(body);
  }

  /// Refetches the settings from the settings sheet. Nothing changes if it
  /// cannot be read.
  Future<QuizActionResult> refreshSettings() async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.quizAdminRefreshEndpoint,
    );
    return QuizActionResult.fromJson(body);
  }

  Future<QuizActionResult> download() async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.quizAdminDownloadEndpoint,
      options: slowOptions,
    );
    return QuizActionResult.fromJson(body);
  }

  /// [kind] is `daily`, `grand`, `mega` or `mega_student`.
  Future<QuizActionResult> generate(String kind) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.quizAdminGenerateEndpoint,
      data: {'kind': kind},
    );
    return QuizActionResult.fromJson(body);
  }

  /// Draws again and replaces what was drawn. For Grand this is its reset.
  Future<QuizActionResult> regenerate(String kind) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.quizAdminRegenerateEndpoint,
      data: {'kind': kind},
    );
    return QuizActionResult.fromJson(body);
  }

  /// [what] is `scoreboard`, `winners`, `mega` or `mega_student`.
  Future<QuizActionResult> publish(String what) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.quizAdminPublishEndpoint,
      data: {'what': what},
      options: slowOptions,
    );
    return QuizActionResult.fromJson(body);
  }

  /// Deletes all quiz data. The server needs `quiz:reset` for it.
  Future<QuizActionResult> deleteAll() async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.quizAdminResetEndpoint,
    );
    return QuizActionResult.fromJson(body);
  }
}

/// True when the call timed out: the server may still have finished it.
bool quizAdminTimedOut(Object error) =>
    error is ApiException && error.statusCode == 408;

/// What to tell the admin about a failed call.
///
/// 409 (busy, blocked, settings not loaded, no Mega drawn) and 502 (a sheet
/// could not be reached, and whether anything was published) carry the
/// server's own sentence, which is the answer. 403, 404 and 422 are the
/// server's refusals of the caller and the request, worded for the screen.
/// A timeout is not here: it is not a failure, see [quizAdminTimedOut].
String quizAdminErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'That did not work. Please try again.';
  }
  String detail(String fallback) =>
      error.message.isNotEmpty ? error.message : fallback;
  switch (error.statusCode) {
    case 403:
      return 'You do not have permission to do that.';
    case 404:
      return 'That action is not part of this quiz.';
    case 409:
      return detail('That cannot be done right now. Nothing was changed.');
    case 422:
      return 'The app asked for something the server does not know. '
          'Nothing was changed.';
    case 502:
      return detail(
        'A sheet could not be reached. Nothing was changed or published.',
      );
    case 0:
      return error.message;
    default:
      return 'That did not work. Please try again.';
  }
}
