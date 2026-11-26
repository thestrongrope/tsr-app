import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/student_transfers.dart';

/// API calls behind bulk transfers and promotions (#420). The server checks
/// `students:transfer`; hiding the screen is a courtesy.
class StudentTransfersRepository {
  final ApiClient _apiClient;

  StudentTransfersRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Every class, active or not, and the level names.
  Future<TransferClasses> getClasses() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminTransferClassesEndpoint,
    );
    return TransferClasses.fromJson(body);
  }

  /// Who can be moved out of [classId]: its students, or for a deactivated
  /// class with none, the students it had when it was deactivated.
  Future<List<TransferStudent>> getStudents(int classId) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminTransferStudentsEndpoint(classId),
    );
    return TransferStudent.listFromJson(body);
  }

  /// Moves [tokens] from [fromClassId] to [toClassId]. A refusal that stops the
  /// whole request (no students, same class, other gender, ...) throws an
  /// `ApiException` with the server's words; otherwise the answer lists who
  /// moved and who did not.
  Future<TransferResult> move({
    required int fromClassId,
    required int toClassId,
    required String type,
    required String reason,
    required List<int> tokens,
  }) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminTransfersEndpoint,
      data: {
        'fromClassId': fromClassId,
        'toClassId': toClassId,
        'type': type,
        'reason': reason,
        'tokens': tokens,
      },
    );
    return TransferResult.fromJson(body);
  }

  /// The transfer log, newest first, narrowed by [query].
  Future<TransferHistoryPage> getHistory({
    String query = '',
    int page = 1,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminTransferHistoryEndpoint,
      queryParameters: {if (query.isNotEmpty) 'q': query, 'page': page},
    );
    return TransferHistoryPage.fromJson(body);
  }
}
