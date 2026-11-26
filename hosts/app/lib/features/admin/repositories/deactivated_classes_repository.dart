import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/deactivated_classes.dart';

/// API calls behind deactivating classes (#618). The server checks
/// `deactivated-classes:manage`; hiding the screen is a courtesy.
class DeactivatedClassesRepository {
  final ApiClient _apiClient;

  DeactivatedClassesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// The deactivated classes and the activity log, newest first.
  Future<DeactivatedClasses> getDeactivatedClasses() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminDeactivatedClassesEndpoint,
    );
    return DeactivatedClasses.fromJson(body);
  }

  /// The active classes that can be chosen, with their student counts.
  Future<List<DeactivationCandidate>> getCandidates() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminDeactivatedClassesCandidatesEndpoint,
    );
    return DeactivationCandidate.listFromJson(body);
  }

  /// Retires [classId]. [type] is `completed` or `shutdown`, [effectiveDate]
  /// `YYYY-MM-DD`. Throws an `ApiException`: 409 when the class is no longer
  /// active, 422 for a bad type, date or reason (the server's words say which),
  /// 404 for an unknown class, 403 without permission, 500 when it failed and
  /// nothing was changed.
  Future<void> deactivateClass({
    required int classId,
    required String type,
    required String effectiveDate,
    required String reason,
  }) async {
    await _apiClient.post<dynamic>(
      AppConstants.classDeactivateEndpoint(classId),
      data: {'type': type, 'effectiveDate': effectiveDate, 'reason': reason},
    );
  }
}
