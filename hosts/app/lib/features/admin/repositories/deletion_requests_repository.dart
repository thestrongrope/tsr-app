import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/deletion_requests.dart';

/// API calls behind the deletion-requests queue (#416). The server checks
/// `deletion-requests:manage`; hiding the screen is a courtesy. A refusal
/// arrives as an `ApiException` carrying the server's own words: 404 for an
/// address no member holds, 409 for a request that is settled or a completion
/// the model refuses (no confirmation recorded, the reviewer demo accounts,
/// Firebase unreachable). Nothing is changed when one is thrown.
class DeletionRequestsRepository {
  final ApiClient _apiClient;

  DeletionRequestsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// The queue, newest first; [status] narrows it to one status.
  Future<DeletionQueue> getQueue({String? status}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminDeletionRequestsEndpoint,
      queryParameters: {'status': ?status},
    );
    return DeletionQueue.fromJson(body);
  }

  /// Raises a request for the member holding [email].
  Future<RaisedDeletionRequest> raise(String email) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminDeletionRequestsEndpoint,
      data: {'email': email},
    );
    return RaisedDeletionRequest.fromJson(body);
  }

  /// Holds a request for prize delivery; [note] is what the member reads.
  Future<DeletionRequest> hold(int id, String note) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminDeletionRequestHoldEndpoint(id),
      data: {'note': note},
    );
    return DeletionRequest.oneFromJson(body);
  }

  /// Records that the confirmation has been sent to the member.
  Future<DeletionRequest> confirmationSent(int id) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminDeletionRequestConfirmationSentEndpoint(id),
    );
    return DeletionRequest.oneFromJson(body);
  }

  /// Deletes the member's sign-in and anonymises them. Irreversible.
  Future<DeletionRequest> complete(int id) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminDeletionRequestCompleteEndpoint(id),
    );
    return DeletionRequest.oneFromJson(body);
  }
}
