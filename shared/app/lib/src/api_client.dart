import 'dart:convert';

import 'package:http/http.dart' as http;

/// One HTTP response from the API: the status and the decoded JSON object, if any.
class ApiResponse {
  const ApiResponse(this.statusCode, this.json);

  final int statusCode;
  final Map<String, Object?>? json;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// The API's error text (`{"detail": "..."}`), when it sent one.
  String? get detail => json?['detail'] as String?;
}

/// Talks to the API (api. through the gateway). Plumbing only: it knows paths and JSON, never a
/// business rule. Every call has a timeout (CODING-GUIDELINES.md rule 3).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.authHeaders,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final Map<String, String> Function() authHeaders;
  final Duration timeout;
  final http.Client _client;

  /// POSTs [body] as JSON. Network failures and timeouts throw; the caller decides what to show.
  Future<ApiResponse> postJson(String path, Map<String, Object?> body) async {
    final response = await _client
        .post(
          baseUrl.resolve(path),
          headers: {'Content-Type': 'application/json', ...authHeaders()},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return ApiResponse(response.statusCode, _decode(response.body));
  }

  static Map<String, Object?>? _decode(String body) {
    if (body.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(body);
    return decoded is Map<String, Object?> ? decoded : null;
  }
}
