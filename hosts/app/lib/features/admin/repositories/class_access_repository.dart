import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/class_access.dart';
import '../models/permission_grants.dart';

/// API calls behind a coordination admin's class access screens (#1034). The
/// server checks `class-access:manage`, the member's gender and the version on
/// every call; hiding the screens is a courtesy.
class ClassAccessRepository {
  final ApiClient _apiClient;

  ClassAccessRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<MemberRef>> searchMembers(String query) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.classAccessMembersEndpoint,
      queryParameters: {'q': query},
    );
    return MemberRef.listFromJson(body);
  }

  Future<MemberAccess> getMember(int token) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.classAccessMemberEndpoint(token),
    );
    return MemberAccess.fromJson(body);
  }

  Future<AccessOptions> getOptions() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.classAccessOptionsEndpoint,
    );
    return AccessOptions.fromJson(body);
  }

  Future<ClassPreview> preview({
    required int gender,
    required List<AccessFilter> filters,
  }) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.classAccessPreviewEndpoint,
      data: {'gender': gender, 'conditions': _conditions(filters)},
    );
    return ClassPreview.fromJson(body);
  }

  /// Sends back the [previewHash] of the preview the admin saw. Throws [PreviewChanged] or
  /// [MemberChanged] when nothing was saved for that reason, and an
  /// `ApiException` for any other refusal or failure.
  ///
  /// The answer is not read: the server may say `saved` with no member view,
  /// and the caller reloads the member either way.
  Future<void> grant({
    required int token,
    required int gender,
    required List<AccessFilter> filters,
    required String reason,
    required String version,
    required String previewHash,
  }) => _write(AppConstants.classAccessGrantEndpoint(token), {
    'gender': gender,
    'conditions': _conditions(filters),
    'reason': reason,
    'version': version,
    'previewHash': previewHash,
  });

  Future<void> revoke({
    required int id,
    required String reason,
    required String version,
  }) => _write(AppConstants.classAccessRevokeEndpoint(id), {
    'reason': reason,
    'version': version,
  });

  Future<void> _write(String path, Map<String, Object?> data) async {
    try {
      await _apiClient.post<dynamic>(path, data: data);
    } on ApiException catch (e) {
      final body = e.body;
      if (e.statusCode != 409 || body == null) rethrow;
      final code = body['code'];
      if (code == 'preview_changed') {
        throw PreviewChanged(ClassPreview.fromJson(body));
      }
      if (code == 'member_changed') throw const MemberChanged();
      rethrow;
    }
  }

  List<Map<String, Object?>> _conditions(List<AccessFilter> filters) => [
    for (final f in filters) ...f.toConditions(),
  ];
}
