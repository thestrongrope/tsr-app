import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/models.dart';

/// Repository for parent-child operations and data retrieval (#633).
class ParentRepository {
  final ApiClient _apiClient;

  ParentRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Seam for test mocking of `GET /me/children`.
  @visibleForTesting
  Future<List<dynamic>> fetchChildrenJson() async {
    final response = await _apiClient.get<dynamic>(
      AppConstants.childrenEndpoint,
    );
    if (response is List) return response;
    return const [];
  }

  /// Seam for test mocking of `GET /me/children/{childToken}/classes`.
  @visibleForTesting
  Future<List<dynamic>> fetchChildClassesJson(int childToken) async {
    final response = await _apiClient.get<dynamic>(
      AppConstants.childClassesEndpoint(childToken),
    );
    if (response is List) return response;
    return const [];
  }

  /// Seam for test mocking of `GET /me/children/{childToken}/classes/{classId}/performance`.
  @visibleForTesting
  Future<Map<String, dynamic>> fetchChildPerformanceJson(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) queryParams['start_date'] = from;
    if (to != null) queryParams['end_date'] = to;

    final response = await _apiClient.get<dynamic>(
      AppConstants.childClassPerformanceEndpoint(childToken, classId),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    if (response is Map<String, dynamic>) return response;
    return const {};
  }

  /// Seam for test mocking of `GET /me/children/{childToken}/classes/{classId}/attendance`.
  @visibleForTesting
  Future<List<dynamic>> fetchChildAttendanceJson(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) queryParams['start_date'] = from;
    if (to != null) queryParams['end_date'] = to;

    final response = await _apiClient.get<dynamic>(
      AppConstants.childClassAttendanceEndpoint(childToken, classId),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    if (response is List) return response;
    return const [];
  }

  /// Seam for test mocking of `GET /me/children/{childToken}/classes/{classId}/scores`.
  @visibleForTesting
  Future<List<dynamic>> fetchChildScoresJson(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) queryParams['start_date'] = from;
    if (to != null) queryParams['end_date'] = to;

    final response = await _apiClient.get<dynamic>(
      AppConstants.childClassScoresEndpoint(childToken, classId),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    if (response is List) return response;
    return const [];
  }

  /// Seam for test mocking of `GET /me/children/links`.
  @visibleForTesting
  Future<List<dynamic>> fetchParentLinksJson() async {
    final response = await _apiClient.get<dynamic>(
      AppConstants.childrenLinksEndpoint,
    );
    if (response is List) return response;
    return const [];
  }

  /// Seam for test mocking of `GET /me/children/link/{code}`.
  @visibleForTesting
  Future<Map<String, dynamic>> fetchInviteJson(String code) async {
    final response = await _apiClient.get<dynamic>(
      AppConstants.childrenLinkAcceptEndpoint(Uri.encodeComponent(code)),
    );
    if (response is Map<String, dynamic>) return response;
    return const {};
  }

  /// Seam for test mocking of `POST /me/children/link/{code}`.
  @visibleForTesting
  Future<void> acceptInviteRequest(String code, String relationship) async {
    await _apiClient.post<dynamic>(
      AppConstants.childrenLinkAcceptEndpoint(Uri.encodeComponent(code)),
      data: {'relationship': relationship},
    );
  }

  /// Seam for test mocking of `DELETE /me/children/{childToken}/link`.
  @visibleForTesting
  Future<void> revokeLinkRequest(int childToken) async {
    await _apiClient.delete(
      AppConstants.childrenLinkRevokeEndpoint(childToken),
    );
  }

  /// Seam for test mocking of `POST /members/{childToken}/parent-links`.
  @visibleForTesting
  Future<Map<String, dynamic>> createInviteLinkJson(int childToken) async {
    final response = await _apiClient.post<dynamic>(
      AppConstants.memberParentLinksEndpoint(childToken),
    );
    if (response is Map<String, dynamic>) return response;
    return const {};
  }

  /// Seam for test mocking of `GET /members/{childToken}/parents/candidate/{parentToken}`.
  @visibleForTesting
  Future<Map<String, dynamic>> lookupParentNameJson(int childToken, int parentToken) async {
    final response = await _apiClient.get<dynamic>(
      AppConstants.memberParentCandidateEndpoint(childToken, parentToken),
    );
    if (response is Map<String, dynamic>) return response;
    return const {};
  }

  /// Seam for test mocking of `POST /members/{childToken}/parents`.
  @visibleForTesting
  Future<dynamic> addParentDirectJson(
    int childToken,
    int parentToken,
    String relationship,
  ) async {
    return _apiClient.post<dynamic>(
      AppConstants.memberParentsEndpoint(childToken),
      data: {
        'parent_token': parentToken,
        'relationship': relationship,
      },
    );
  }

  /// Seam for test mocking of `GET /me/parents`.
  @visibleForTesting
  Future<List<dynamic>> fetchMyParentsJson() async {
    final response = await _apiClient.get<dynamic>(
      AppConstants.myParentsEndpoint,
    );
    if (response is List) return response;
    return const [];
  }

  /// Seam for test mocking of `DELETE /me/parents/{parentToken}`.
  @visibleForTesting
  Future<void> revokeMyParentRequest(int parentToken) async {
    await _apiClient.delete(
      AppConstants.myParentRevokeEndpoint(parentToken),
    );
  }

  /// Get list of linked children for the current parent.
  Future<List<ChildModel>> getChildren() async {
    final jsonList = await fetchChildrenJson();
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((j) => ChildModel.fromJson(j))
        .toList();
  }

  /// Get list of classes for a specific child.
  Future<List<ChildClassModel>> getChildClasses(int childToken) async {
    final jsonList = await fetchChildClassesJson(childToken);
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((j) => ChildClassModel.fromJson(j))
        .toList();
  }

  /// Get performance summary for a child in a class.
  Future<ChildPerformanceModel> getChildPerformance(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async {
    final json = await fetchChildPerformanceJson(
      childToken,
      classId,
      from: from,
      to: to,
    );
    return ChildPerformanceModel.fromJson(json);
  }

  /// Get attendance history sessions for a child in a class.
  Future<List<ChildAttendanceHistory>> getChildAttendance(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async {
    final jsonList = await fetchChildAttendanceJson(
      childToken,
      classId,
      from: from,
      to: to,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((j) => ChildAttendanceHistory.fromJson(j))
        .toList();
  }

  /// Get quiz scores for a child in a class.
  Future<List<ChildScoreModel>> getChildScores(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async {
    final jsonList = await fetchChildScoresJson(
      childToken,
      classId,
      from: from,
      to: to,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((j) => ChildScoreModel.fromJson(j))
        .toList();
  }

  /// Get list of links created for/by this parent.
  Future<List<ParentLinkModel>> getParentLinks() async {
    final jsonList = await fetchParentLinksJson();
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((j) => ParentLinkModel.fromJson(j))
        .toList();
  }

  /// What the invite [code] says, without accepting it (#1122).
  Future<ParentInvitePreview> inspectInvite(String code) async {
    final json = await fetchInviteJson(code);
    return ParentInvitePreview.fromJson(json);
  }

  /// Accept the invite [code] as [relationship]: `father`, `mother` or `guardian`.
  /// Refusals arrive as an [ApiException] (410 used or expired, 409 already
  /// linked, 422 not allowed for this account, 403 removed by the child).
  Future<void> acceptInvite(String code, String relationship) =>
      acceptInviteRequest(code, relationship);

  /// Revoke an active parent link.
  Future<void> revokeLink(int childToken) async {
    await revokeLinkRequest(childToken);
  }

  /// Create a one-time invite link for adding a parent to a child (#633).
  Future<ParentInviteLink> createInviteLink(int childToken) async {
    final json = await createInviteLinkJson(childToken);
    return ParentInviteLink.fromJson(json);
  }

  /// Look up a candidate parent's display name for direct linking to [childToken].
  Future<String?> lookupParentName(int childToken, int parentToken) async {
    final json = await lookupParentNameJson(childToken, parentToken);
    return json['name'] as String?;
  }

  /// Directly link a parent to a child by token (staff only).
  Future<void> addParentDirect(
    int childToken,
    int parentToken,
    String relationship,
  ) async {
    await addParentDirectJson(childToken, parentToken, relationship);
  }

  /// Get list of parents linked to the caller (child-side).
  Future<List<MyParentModel>> getMyParents() async {
    final jsonList = await fetchMyParentsJson();
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((j) => MyParentModel.fromJson(j))
        .toList();
  }

  /// Revoke a parent link from the child side.
  Future<void> revokeMyParent(int parentToken) async {
    await revokeMyParentRequest(parentToken);
  }
}
