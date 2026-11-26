import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/class_registration.dart';

/// Repository for the class request (registration) form.
///
/// Talks to the PHP API layer's GET/POST /registration endpoints, which wrap
/// the existing `tsr_class.php` / `tsr_class_save.php` web form.
class ClassRegistrationRepository {
  final ApiClient _apiClient;

  ClassRegistrationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch the user's existing registration and the form options (interests).
  Future<ClassRegistrationFormData> getFormData() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.classRegistrationEndpoint,
      );
      return ClassRegistrationFormData.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching class registration: $e');
      rethrow;
    }
  }

  /// Submit (create or update) the class request.
  Future<void> submit(Map<String, dynamic> payload) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        AppConstants.classRegistrationEndpoint,
        data: payload,
      );
    } catch (e) {
      debugPrint('Error submitting class registration: $e');
      rethrow;
    }
  }
}
