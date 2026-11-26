import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/feedback_item.dart';

/// API calls for the feedback review queue (#891, #892, #893).
///
/// Gated by feedback:review.
class FeedbackRepository {
  final ApiClient _apiClient;

  FeedbackRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches one page of the queue (unhandled first), counting from 1.
  Future<FeedbackPage> fetchFeedback({int page = 1}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminFeedbackEndpoint,
      queryParameters: {'page': page},
    );
    return FeedbackPage.fromJson(body);
  }

  /// Marks a feedback item handled.
  Future<FeedbackItem> markHandled(int id) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminFeedbackHandleEndpoint(id),
    );
    if (body is! Map<String, dynamic> ||
        body['item'] is! Map<String, dynamic>) {
      throw const FormatException('Expected item object in response');
    }
    return FeedbackItem.fromJson(body['item'] as Map<String, dynamic>);
  }

  /// Marks a feedback item unhandled.
  Future<FeedbackItem> markUnhandled(int id) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminFeedbackUnhandleEndpoint(id),
    );
    if (body is! Map<String, dynamic> ||
        body['item'] is! Map<String, dynamic>) {
      throw const FormatException('Expected item object in response');
    }
    return FeedbackItem.fromJson(body['item'] as Map<String, dynamic>);
  }
}
