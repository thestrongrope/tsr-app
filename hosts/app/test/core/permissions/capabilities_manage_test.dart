import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/permissions/capabilities_manage.dart';

Capabilities _holding(
  List<String> permissions, {
  PermissionScopes scopes = const PermissionScopes(),
}) => Capabilities.of(
  payload: PermissionsPayload(
    version: 4,
    permissions: permissions,
    scopes: scopes,
    issuedAt: '',
  ),
  classes: null,
);

void main() {
  test('before the server has answered nothing is granted', () {
    const none = Capabilities.none();

    expect(none.hasAnswer, isFalse);
    expect(none.canReadReports, isFalse);
    expect(none.choosesReportsGender, isFalse);
    expect(none.canRejectRegistrations, isFalse);
    expect(none.isEnrolled, isFalse);
    expect(none.managedGender, isNull);
    expect(none.remindsConduction(classId: 1), isFalse);
  });

  test('a gender admin reads reports but is pinned to their gender', () {
    final capabilities = _holding([
      'reports:read:gender',
    ], scopes: const PermissionScopes(gender: 2));

    expect(capabilities.canReadReports, isTrue);
    expect(capabilities.choosesReportsGender, isFalse);
    expect(capabilities.managedGender, 2);
  });

  test('a member who reads every gender may choose', () {
    final capabilities = _holding(['reports:read:all', 'teachers:read:all']);

    expect(capabilities.choosesReportsGender, isTrue);
    expect(capabilities.canChooseTeacherGender, isTrue);
  });

  test('each tool reads only its own permission', () {
    final capabilities = _holding(['donors:read:all']);

    expect(capabilities.canReadDonors, isTrue);
    expect(capabilities.canReadAuditLog, isFalse);
    expect(capabilities.canManagePermissions, isFalse);
  });

  test('the conduction reminder goes to the class teacher only', () {
    final capabilities = _holding([
      'sessions:create:own',
    ], scopes: const PermissionScopes(own: [10], taught: [10]));

    expect(capabilities.remindsConduction(classId: 10), isTrue);
    expect(capabilities.remindsConduction(classId: 11), isFalse);
  });
}
