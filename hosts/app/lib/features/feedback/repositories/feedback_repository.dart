import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

/// Sends a member's feedback to `POST /feedback`.
class FeedbackRepository {
  FeedbackRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static const endpoint = '/feedback';

  /// The most the server accepts in one message.
  static const maxLength = 2000;

  final ApiClient _apiClient;

  /// Sends [text] under [clientId]. Sending the same [clientId] again returns
  /// the stored message rather than a second one. Returns the server's id.
  Future<int> send(String clientId, String text) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint,
        data: {'clientId': clientId, 'text': text},
      );
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error sending feedback: $e');
      rethrow;
    }
  }
}
