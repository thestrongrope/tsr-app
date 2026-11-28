import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/enrol_by_token.dart';

/// API calls behind the "Enrol by token" screen (#1050). The server checks
/// `members:enrol-by-token` and the class on every call; hiding the card is a
/// courtesy.
class EnrolByTokenRepository {
  final ApiClient _apiClient;

  EnrolByTokenRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Throws [MemberNotFound] or [AmbiguousToken] for a token that is not one
  /// registered member, and an `ApiException` for anything else (429, 5xx).
  Future<MemberDetails> lookup(int token) async {
    try {
      final body = await _apiClient.get<dynamic>(
        AppConstants.adminMemberEndpoint(token),
      );
      return MemberDetails.fromJson(body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) throw MemberNotFound(e.message);
      if (e.statusCode == 422 && e.body?['code'] == 'ambiguous_token') {
        throw AmbiguousToken(e.message);
      }
      rethrow;
    }
  }

  /// Any 2xx is a success: the server may answer the roster or `saved` with no
  /// roster, and neither is read. Throws [AlreadyEnrolled] or [OtherGender]
  /// when nothing was written for that reason, and an `ApiException` for any
  /// other refusal or failure.
  Future<void> enrol({required int token, required int classId}) async {
    try {
      await _apiClient.post<dynamic>(
        AppConstants.adminMemberEnrolEndpoint(token),
        data: {'classId': classId},
      );
    } on ApiException catch (e) {
      final code = e.body?['code'];
      if (e.statusCode == 409 && code == 'already_enrolled') {
        throw AlreadyEnrolled(e.message);
      }
      if (e.statusCode == 422 && code == 'other_gender') {
        throw OtherGender(e.message);
      }
      rethrow;
    }
  }
}
