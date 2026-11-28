import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/permission_grants.dart';

/// API calls behind a super admin's permission grants (#567). The server checks
/// `permissions:manage` on every one; hiding the screen is a courtesy.
class PermissionGrantsRepository {
  final ApiClient _apiClient;

  PermissionGrantsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Members matching [query] on name, token, email or mobile.
  Future<List<MemberRef>> searchMembers(String query) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminPermissionMembersEndpoint,
      queryParameters: {'q': query},
    );
    return MemberRef.listFromJson(body);
  }

  Future<MemberPermissions> getMember(int token) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminPermissionMemberEndpoint(token),
    );
    return MemberPermissions.fromJson(body);
  }

  /// A refusal (already held, no reason, not grantable) throws an
  /// `ApiException` with the server's words and changes nothing.
  Future<void> grant({
    required int token,
    required String permission,
    required String reason,
  }) async {
    await _apiClient.post<dynamic>(
      AppConstants.adminPermissionGrantEndpoint(token),
      data: {'permission': permission, 'reason': reason},
    );
  }

  Future<void> revoke({required int id, required String reason}) async {
    await _apiClient.post<dynamic>(
      AppConstants.adminPermissionRevokeEndpoint(id),
      data: {'reason': reason},
    );
  }
}
