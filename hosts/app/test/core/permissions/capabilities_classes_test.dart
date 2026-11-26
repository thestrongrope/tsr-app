import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/permissions/capabilities_classes.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';

const _gentsClass = ClassModel(
  id: 10,
  code: 'C10',
  name: 'Alpha',
  level: 1,
  gender: 1,
  status: 'A',
);

Capabilities _of(
  List<String> permissions, {
  PermissionScopes scopes = const PermissionScopes(),
  bool navigationClasses = false,
  List<ClassModel>? classes,
}) => Capabilities.of(
  payload: PermissionsPayload(
    version: 5,
    permissions: permissions,
    scopes: scopes,
    issuedAt: '',
    revision: '0123456789abcdef',
    navigation: PermissionsNavigation(
      classes: navigationClasses,
      manage: false,
    ),
  ),
  classes: classes,
);

void main() {
  group('the class list screen follows the same fact as the Classes tab', () {
    test('a loaded list shows the screen and the tab, whatever the server '
        'navigation says', () {
      final capabilities = _of(
        const [],
        navigationClasses: false,
        classes: const [_gentsClass],
      );
      expect(capabilities.hasClassList(const [_gentsClass]), isTrue);
      expect(capabilities.showClassesTab, isTrue);
    });

    test('no list: the screen shows the empty state and the tab hides', () {
      final capabilities = _of(const [], classes: const []);
      expect(capabilities.hasClassList(const []), isFalse);
      expect(capabilities.hasClassList(null), isFalse);
      expect(capabilities.showClassesTab, isFalse);
    });

    test('the server shows the tab for a member with no class yet: the '
        'screen still has no list to show', () {
      final capabilities = _of(
        const [],
        navigationClasses: true,
        classes: const [],
      );
      expect(capabilities.showClassesTab, isTrue);
      expect(capabilities.hasClassList(const []), isFalse);
    });
  });

  group('class actions follow the grant, not the list role', () {
    test('a class the list calls conducting gets no conduction action '
        'without sessions:create', () {
      final capabilities = _of(
        const ['notifications:send:own'],
        scopes: const PermissionScopes(own: [10], taught: [10]),
        classes: const [
          ClassModel(
            id: 10,
            code: 'C10',
            name: 'Alpha',
            level: 1,
            gender: 1,
            status: 'A',
            role: 'conducting',
          ),
        ],
      );
      expect(capabilities.canRecordConduction(10, classGender: 1), isFalse);
      expect(capabilities.canSendNotification(10, classGender: 1), isTrue);
    });

    test('each action asks its own permission on the class', () {
      final capabilities = _of(
        const [
          'classes:update:own',
          'classes:schedule:own',
          'class-students:read:own',
          'sessions:create:own',
          'mcqs:manage:own',
          'mcqs:copy:own',
          'notifications:send:own',
        ],
        scopes: const PermissionScopes(own: [10]),
      );
      expect(capabilities.canUpdateClass(10, classGender: 1), isTrue);
      expect(capabilities.canEditSchedule(10, classGender: 1), isTrue);
      expect(capabilities.canReadStudents(10, classGender: 1), isTrue);
      expect(capabilities.canRecordConduction(10, classGender: 1), isTrue);
      expect(capabilities.canManageMcqs(10, classGender: 1), isTrue);
      expect(capabilities.canCopyMcqs(10, classGender: 1), isTrue);
      expect(capabilities.canSendNotification(10, classGender: 1), isTrue);
      expect(capabilities.canManageMcqs(11, classGender: 1), isFalse);
    });

    test('nothing is granted before the server has answered', () {
      expect(
        const Capabilities.none().canManageMcqs(10, classGender: 1),
        isFalse,
      );
    });
  });

  group('a class gender that has not loaded yet', () {
    final genderAdmin = _of(
      const ['mcqs:manage:gender'],
      scopes: const PermissionScopes(gender: 1),
    );

    test('a gender admin keeps the action while the gender is null', () {
      expect(genderAdmin.canManageMcqs(10, classGender: null), isTrue);
    });

    test('once loaded, the other gender is refused', () {
      expect(genderAdmin.canManageMcqs(10, classGender: 2), isFalse);
      expect(genderAdmin.canManageMcqs(10, classGender: 1), isTrue);
    });

    test('a member with no gender scope gains nothing from a null gender', () {
      final teacher = _of(
        const ['mcqs:manage:own'],
        scopes: const PermissionScopes(own: [10]),
      );
      expect(teacher.canManageMcqs(11, classGender: null), isFalse);
      expect(teacher.canManageMcqs(10, classGender: null), isTrue);
    });
  });

  group('conduction reminders', () {
    test('shown only when a loaded class is taught or assigned', () {
      final capabilities = _of(
        const ['sessions:create:own'],
        scopes: const PermissionScopes(own: [10], taught: [10]),
      );
      expect(capabilities.hasConductionReminders(const [_gentsClass]), isTrue);
      expect(capabilities.hasConductionReminders(const []), isFalse);
      expect(capabilities.hasConductionReminders(null), isFalse);
    });
  });
}
