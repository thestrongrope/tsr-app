import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';

/// Real-shaped `GET /me/permissions` bodies (version 4), one per persona.
/// Shape: docs/specs/me-permissions/plan.md and web/models/permissions.php.
const _member = [
  'classes:read:enrolled',
  'syllabus:read:all',
  'profile:read:self',
];

Map<String, dynamic> _body(
  List<String> permissions, {
  int? gender,
  List<int> assigned = const [],
  List<int> assignedGenders = const [],
  List<int> own = const [],
  List<int> taught = const [],
  List<int> enrolled = const [],
}) => {
  'version': 4,
  'issued_at': '2026-10-05T08:00:00.000000+00:00',
  'permissions': [..._member, ...permissions],
  'scopes': {
    'gender': gender,
    'assigned': assigned,
    'assigned_genders': assignedGenders,
    'own': own,
    'taught': taught,
    'enrolled': enrolled,
  },
};

PermissionsPayload _parse(Map<String, dynamic> body) =>
    PermissionsPayload.fromJson(body);

void main() {
  group('revision and navigation (version 5)', () {
    test('a v5 body parses revision and navigation', () {
      final p = _parse({
        ..._body([], enrolled: [412]),
        'version': 5,
        'revision': '0123456789abcdef',
        'navigation': {'classes': true, 'manage': false},
      });
      expect(p.version, 5);
      expect(p.revision, '0123456789abcdef');
      expect(p.navigation!.classes, isTrue);
      expect(p.navigation!.manage, isFalse);
      expect(p.showsClassesTab, isTrue);
      expect(p.showsManageTab, isFalse);
    });

    test('server navigation wins over the local rules', () {
      final p = _parse({
        ..._body(['reports:read:gender'], enrolled: [412]),
        'version': 5,
        'revision': '0123456789abcdef',
        'navigation': {'classes': false, 'manage': false},
      });
      expect(p.hasClasses, isTrue);
      expect(p.hasAdminModule, isTrue);
      expect(p.showsClassesTab, isFalse);
      expect(p.showsManageTab, isFalse);
    });

    test('a v4 body has no revision and computes both facts locally', () {
      final p = _parse(_body(['reports:read:gender'], enrolled: [412]));
      expect(p.revision, isNull);
      expect(p.navigation, isNull);
      expect(p.showsClassesTab, isTrue);
      expect(p.showsManageTab, isTrue);
    });

    test('a v4 member with nothing shows neither tab', () {
      final p = _parse(_body([]));
      expect(p.showsClassesTab, isFalse);
      expect(p.showsManageTab, isFalse);
    });

    test('a malformed navigation parses as absent', () {
      final p = _parse({..._body([]), 'navigation': 'yes'});
      expect(p.navigation, isNull);
    });

    test('revision and navigation survive a save and reload', () {
      final p = _parse({
        ..._body([]),
        'version': 5,
        'revision': 'aaaaaaaaaaaaaaaa',
        'navigation': {'classes': true, 'manage': true},
      });
      final again = PermissionsPayload.fromJson(p.toJson());
      expect(again.revision, 'aaaaaaaaaaaaaaaa');
      expect(again.navigation!.manage, isTrue);
    });
  });

  group('PermissionsPayload.fromJson', () {
    test('member: parses permissions and enrolled scope', () {
      final p = _parse(_body([], enrolled: [412]));
      expect(p.version, 4);
      expect(p.permissions, contains('classes:read:enrolled'));
      expect(p.scopes.enrolled, [412]);
      expect(p.scopes.gender, isNull);
      expect(p.isEnrolled, isTrue);
      expect(p.hasAdminModule, isFalse);
    });

    test('teacher: own and taught lists', () {
      final p = _parse(
        _body(['sessions:create:own'], own: [391], taught: [391]),
      );
      expect(p.scopes.own, [391]);
      expect(p.scopes.taught, [391]);
    });

    test('class coordinator: assigned list; assigned_genders is ignored', () {
      final p = _parse(
        _body(
          ['sessions:create:assigned'],
          assigned: [395],
          assignedGenders: [2],
        ),
      );
      expect(p.scopes.assigned, [395]);
    });

    test('gender admin: scopes.gender', () {
      final p = _parse(_body(['sessions:create:gender'], gender: 2));
      expect(p.scopes.gender, 2);
    });

    test('super admin: broadcast and syllabus give an admin module', () {
      final p = _parse(
        _body(['notifications:broadcast:all', 'syllabus:update:all']),
      );
      expect(p.canBroadcast, isTrue);
      expect(p.canUpdateSyllabus, isTrue);
      expect(p.hasAdminModule, isTrue);
    });

    test(
      'reports:read in any scope gives the Reports entry and an admin module',
      () {
        for (final grant in ['all', 'gender', 'assigned']) {
          final p = _parse(_body(['reports:read:$grant'], gender: 1));
          expect(p.canReadReports, isTrue, reason: grant);
          expect(p.hasAdminModule, isTrue, reason: grant);
        }
      },
    );

    test('without reports:read the Reports entry is hidden', () {
      final p = _parse(_body(['sessions:create:assigned'], assigned: [395]));
      expect(p.canReadReports, isFalse);
      expect(p.hasAdminModule, isFalse);
    });

    test('donors:read alone gives the Donors entry and an admin module', () {
      final p = _parse(_body(['donors:read:all']));
      expect(p.canReadDonors, isTrue);
      expect(p.hasAdminModule, isTrue);
    });

    test('without donors:read the Donors entry is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canReadDonors, isFalse);
    });

    test(
      'hasClasses: only someone who attends, conducts or manages one (#643)',
      () {
        expect(_parse(_body([])).hasClasses, isFalse, reason: 'a subscriber');
        expect(_parse(_body([], enrolled: [412])).hasClasses, isTrue);
        expect(
          _parse(_body(['classes:read:own'], taught: [7])).hasClasses,
          isTrue,
        );
        expect(
          _parse(_body(['classes:read:own'], own: [9])).hasClasses,
          isTrue,
          reason: 'a class MCQ admin',
        );
        expect(
          _parse(_body(['classes:read:assigned'], assigned: [5])).hasClasses,
          isTrue,
        );
        expect(
          _parse(_body(['classes:read:assigned'])).hasClasses,
          isFalse,
          reason: 'a coordinator with nothing assigned',
        );
        expect(
          _parse(_body(['classes:read:gender'], gender: 1)).hasClasses,
          isTrue,
        );
        expect(_parse(_body(['classes:read:all'])).hasClasses, isTrue);
        expect(
          _parse(_body(['donors:read:all'])).hasClasses,
          isFalse,
          reason: 'finance has an admin module, not a class',
        );
        expect(const PermissionsPayload.member().hasClasses, isFalse);
      },
    );

    test(
      'deletion-requests:manage alone gives the queue and an admin module',
      () {
        final p = _parse(_body(['deletion-requests:manage:all']));
        expect(p.canManageDeletionRequests, isTrue);
        expect(p.hasAdminModule, isTrue);
      },
    );

    test('standard-mcqs:update alone gives the update and an admin module', () {
      final p = _parse(_body(['standard-mcqs:update:all']));
      expect(p.canUpdateStandardMcqs, isTrue);
      expect(p.hasAdminModule, isTrue);
      expect(
        _parse(_body(['reports:read:gender'], gender: 1)).canUpdateStandardMcqs,
        isFalse,
      );
    });

    test('quiz:admin alone gives the quiz admin and an admin module', () {
      final p = _parse(_body(['quiz:admin:all']));
      expect(p.canAdminQuiz, isTrue);
      expect(p.canResetQuiz, isFalse, reason: 'delete-all is its own grant');
      expect(p.hasAdminModule, isTrue);
      expect(
        _parse(_body(['reports:read:gender'], gender: 1)).canAdminQuiz,
        isFalse,
      );
    });

    test('quiz:reset shows delete-all but is not an admin module', () {
      final p = _parse(_body(['quiz:reset:all']));
      expect(p.canResetQuiz, isTrue);
      expect(p.canAdminQuiz, isFalse);
      expect(p.hasAdminModule, isFalse);
      final both = _parse(_body(['quiz:admin:all', 'quiz:reset:all']));
      expect(both.canAdminQuiz && both.canResetQuiz, isTrue);
    });

    test('mcqs:copy alone gives the copy picker and an admin module', () {
      final p = _parse(_body(['mcqs:copy:gender'], gender: 1));
      expect(p.canCopyMcqs, isTrue);
      expect(p.hasAdminModule, isTrue);
      final assigned = _parse(_body(['mcqs:copy:assigned'], assigned: [5]));
      expect(assigned.canCopyMcqs, isTrue);
      final manager = _parse(_body(['mcqs:manage:own'], own: [5]));
      expect(manager.canCopyMcqs, isFalse, reason: 'manage is not copy');
      expect(manager.hasAdminModule, isFalse);
    });

    test('students:transfer alone gives Transfers and an admin module', () {
      final p = _parse(_body(['students:transfer:all']));
      expect(p.canTransferStudents, isTrue);
      expect(p.hasAdminModule, isTrue);
    });

    test('permissions:manage alone gives Access and an admin module', () {
      final p = _parse(_body(['permissions:manage:all']));
      expect(p.canManagePermissions, isTrue);
      expect(p.hasAdminModule, isTrue);
    });

    test('without permissions:manage Access is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canManagePermissions, isFalse);
    });

    test(
      'class-access:manage alone gives Class admins and an admin module',
      () {
        final gender = _parse(_body(['class-access:manage:gender'], gender: 1));
        final all = _parse(_body(['class-access:manage:all']));
        expect(gender.canManageClassAccess, isTrue);
        expect(all.canManageClassAccess, isTrue);
        expect(gender.hasAdminModule, isTrue);
      },
    );

    test('without class-access:manage Class admins is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canManageClassAccess, isFalse);
    });

    test(
      'members:enrol-by-token shows Enrol by token and counts as a module',
      () {
        final p = _parse(_body(['members:enrol-by-token:all']));
        expect(p.canEnrolByToken, isTrue);
        expect(p.hasAdminModule, isTrue);
      },
    );

    test('without members:enrol-by-token Enrol by token is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canEnrolByToken, isFalse);
    });

    test('without students:transfer Transfers is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canTransferStudents, isFalse);
    });

    test('without deletion-requests:manage the queue is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canManageDeletionRequests, isFalse);
    });

    test('classes:create in any scope gives the New class entry', () {
      expect(
        _parse(_body(['classes:create:gender'], gender: 1)).canCreateClass,
        isTrue,
      );
      expect(_parse(_body(['classes:create:all'])).canCreateClass, isTrue);
    });

    test('without classes:create the New class entry is hidden', () {
      final p = _parse(_body(['classes:update:assigned']));
      expect(p.canCreateClass, isFalse);
    });

    test('deactivated-classes:manage gives the entry and an admin module', () {
      final p = _parse(_body(['deactivated-classes:manage:all']));
      expect(p.canManageDeactivatedClasses, isTrue);
      expect(p.hasAdminModule, isTrue);
    });

    test('without deactivated-classes:manage the entry is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canManageDeactivatedClasses, isFalse);
    });

    test('whatsapp:manage gives the entry and an admin module', () {
      final p = _parse(_body(['whatsapp:manage:all']));
      expect(p.canManageWhatsappReminders, isTrue);
      expect(p.hasAdminModule, isTrue);
    });

    test('without whatsapp:manage the entry is hidden', () {
      final p = _parse(_body(['reports:read:gender'], gender: 1));
      expect(p.canManageWhatsappReminders, isFalse);
    });

    test('teachers:read in any scope gives the entry and an admin module', () {
      for (final scope in ['all', 'gender']) {
        final p = _parse(_body(['teachers:read:$scope'], gender: 1));
        expect(p.canManageTeachers, isTrue, reason: scope);
        expect(p.hasAdminModule, isTrue, reason: scope);
      }
    });

    test('only teachers:read for every gender may choose whose teachers', () {
      expect(
        _parse(_body(['teachers:read:all'])).canChooseTeacherGender,
        isTrue,
      );
      expect(
        _parse(
          _body(['teachers:read:gender'], gender: 2),
        ).canChooseTeacherGender,
        isFalse,
      );
    });

    test('without teachers:read the entry is hidden', () {
      final p = _parse(_body(['teachers:lookup:assigned']));
      expect(p.canManageTeachers, isFalse);
      expect(p.hasAdminModule, isFalse);
    });

    test('parents:add in any scope grants canAddParents', () {
      for (final scope in ['all', 'gender', 'assigned', 'own']) {
        final p = _parse(_body(['parents:add:$scope']));
        expect(p.canAddParents, isTrue, reason: scope);
      }
      expect(_parse(_body(['parents:manage:self'])).canAddParents, isFalse);
    });

    test('only parents:add-direct grants canAddParentByToken', () {
      for (final scope in ['all', 'gender', 'assigned', 'taught']) {
        final p = _parse(_body(['parents:add-direct:$scope']));
        expect(p.canAddParentByToken, isTrue, reason: scope);
      }
      expect(_parse(_body(['parents:add:own'])).canAddParentByToken, isFalse);
    });

    test('parents:manage:self grants canManageOwnParents', () {
      expect(
        _parse(_body(['parents:manage:self'])).canManageOwnParents,
        isTrue,
      );
      expect(_parse(_body(['parents:add:own'])).canManageOwnParents, isFalse);
    });

    test('unknown fields are ignored', () {
      final body = _body([])
        ..['role_name'] = 'SUPER_ADMIN'
        ..['something_new'] = {'a': 1};
      (body['scopes'] as Map<String, dynamic>)['future_scope'] = [1];
      expect(() => _parse(body), returnsNormally);
      expect(_parse(body).can('notifications:broadcast'), isFalse);
    });

    test('missing scopes parses as empty', () {
      final p = _parse({
        'version': 4,
        'permissions': ['sessions:create:own'],
      });
      expect(p.scopes.own, isEmpty);
      expect(p.scopes.gender, isNull);
      expect(p.can('sessions:create', classId: 10), isFalse);
    });

    test('malformed scopes parses as empty', () {
      final p = _parse({'permissions': [], 'scopes': []});
      expect(p.scopes.enrolled, isEmpty);
    });

    test('toJson round-trips', () {
      final p = _parse(
        _body(['sessions:create:own'], own: [1, 2], taught: [1], gender: 1),
      );
      final again = PermissionsPayload.fromJson(p.toJson());
      expect(again.permissions, p.permissions);
      expect(again.scopes.own, [1, 2]);
      expect(again.scopes.taught, [1]);
      expect(again.scopes.gender, 1);
    });
  });

  group('can()', () {
    // One row per scope: the permission name held, the scopes it resolves
    // against, the class asked about and the expected answer.
    final cases =
        <
          ({
            String name,
            String held,
            PermissionScopes scopes,
            int? classId,
            int? classGender,
            bool expected,
          })
        >[
          (
            name: 'all, no class',
            held: 'notifications:broadcast:all',
            scopes: const PermissionScopes(),
            classId: null,
            classGender: null,
            expected: true,
          ),
          (
            name: 'all, any class',
            held: 'sessions:create:all',
            scopes: const PermissionScopes(),
            classId: 77,
            classGender: 2,
            expected: true,
          ),
          (
            name: 'gender matches',
            held: 'sessions:create:gender',
            scopes: const PermissionScopes(gender: 1),
            classId: 10,
            classGender: 1,
            expected: true,
          ),
          (
            name: 'gender differs',
            held: 'sessions:create:gender',
            scopes: const PermissionScopes(gender: 1),
            classId: 10,
            classGender: 2,
            expected: false,
          ),
          (
            name: 'gender unknown class gender',
            held: 'sessions:create:gender',
            scopes: const PermissionScopes(gender: 1),
            classId: 10,
            classGender: null,
            expected: false,
          ),
          (
            name: 'gender scope null (no gender admin)',
            held: 'sessions:create:gender',
            scopes: const PermissionScopes(),
            classId: 10,
            classGender: 1,
            expected: false,
          ),
          (
            name: 'gender held, asked with no class',
            held: 'sessions:create:gender',
            scopes: const PermissionScopes(gender: 1),
            classId: null,
            classGender: null,
            expected: false,
          ),
          (
            name: 'assigned contains class',
            held: 'sessions:create:assigned',
            scopes: const PermissionScopes(assigned: [10]),
            classId: 10,
            classGender: 1,
            expected: true,
          ),
          (
            name: 'assigned lacks class',
            held: 'sessions:create:assigned',
            scopes: const PermissionScopes(assigned: [11]),
            classId: 10,
            classGender: 1,
            expected: false,
          ),
          (
            name: 'own contains class',
            held: 'sessions:create:own',
            scopes: const PermissionScopes(own: [10]),
            classId: 10,
            classGender: 1,
            expected: true,
          ),
          (
            name: 'own lacks class',
            held: 'sessions:create:own',
            scopes: const PermissionScopes(own: [11]),
            classId: 10,
            classGender: 1,
            expected: false,
          ),
          (
            name: 'taught contains class',
            held: 'class-students:update:taught',
            scopes: const PermissionScopes(taught: [10]),
            classId: 10,
            classGender: 1,
            expected: true,
          ),
          (
            name: 'taught lacks class',
            held: 'class-students:update:taught',
            scopes: const PermissionScopes(taught: [11]),
            classId: 10,
            classGender: 1,
            expected: false,
          ),
          (
            name: 'enrolled contains class',
            held: 'classes:read:enrolled',
            scopes: const PermissionScopes(enrolled: [10]),
            classId: 10,
            classGender: 1,
            expected: true,
          ),
          (
            name: 'enrolled lacks class',
            held: 'classes:read:enrolled',
            scopes: const PermissionScopes(enrolled: [11]),
            classId: 10,
            classGender: 1,
            expected: false,
          ),
          (
            name: 'class-scoped grant, asked with no class',
            held: 'sessions:create:own',
            scopes: const PermissionScopes(own: [10]),
            classId: null,
            classGender: null,
            expected: false,
          ),
        ];

    for (final c in cases) {
      test(c.name, () {
        final p = PermissionsPayload(
          version: 4,
          permissions: [c.held],
          scopes: c.scopes,
          issuedAt: '',
        );
        final action = c.held.substring(0, c.held.lastIndexOf(':'));
        expect(
          p.can(action, classId: c.classId, classGender: c.classGender),
          c.expected,
        );
      });
    }

    test('unknown permission is false', () {
      final p = _parse(_body(['sessions:create:all']));
      expect(p.can('nonsense:do'), isFalse);
      expect(p.can('nonsense:do', classId: 1, classGender: 1), isFalse);
    });

    test('unknown scope is false', () {
      final p = PermissionsPayload(
        version: 4,
        permissions: const ['sessions:create:galaxy'],
        issuedAt: '',
      );
      expect(p.can('sessions:create', classId: 1, classGender: 1), isFalse);
    });

    test('empty scopes and no permissions is false', () {
      expect(
        const PermissionsPayload.member().can('sessions:create', classId: 1),
        isFalse,
      );
    });

    test('a name that merely starts with the permission does not match', () {
      final p = _parse(_body(['sessions:create-extra:all']));
      expect(p.can('sessions:create'), isFalse);
    });
  });

  group('remindsConduction()', () {
    PermissionsPayload held(
      List<String> permissions, {
      PermissionScopes scopes = const PermissionScopes(),
    }) => PermissionsPayload(
      version: 4,
      permissions: permissions,
      scopes: scopes,
      issuedAt: '',
    );

    test('teacher of the class: yes', () {
      final p = held([
        'sessions:create:own',
      ], scopes: const PermissionScopes(own: [10], taught: [10]));
      expect(p.remindsConduction(classId: 10), isTrue);
    });

    test('MCQ admin of the class (own, not taught): no', () {
      final p = held([
        'sessions:create:own',
      ], scopes: const PermissionScopes(own: [10], taught: [11]));
      expect(p.can('sessions:create', classId: 10, classGender: 1), isTrue);
      expect(p.remindsConduction(classId: 10), isFalse);
    });

    test('class coordinator: no reminders for the classes they manage', () {
      final p = held([
        'sessions:create:assigned',
      ], scopes: const PermissionScopes(assigned: [10]));
      expect(p.can('sessions:create', classId: 10, classGender: 1), isTrue);
      expect(p.remindsConduction(classId: 10), isFalse);
    });

    test('class coordinator who teaches a class: yes for that class only', () {
      final p = held(
        ['sessions:create:assigned', 'sessions:create:own'],
        scopes: const PermissionScopes(
          assigned: [10, 11],
          own: [11],
          taught: [11],
        ),
      );
      expect(p.remindsConduction(classId: 10), isFalse);
      expect(p.remindsConduction(classId: 11), isTrue);
    });

    test('gender admin: no reminders, even for their gender', () {
      final p = held([
        'sessions:create:gender',
      ], scopes: const PermissionScopes(gender: 2));
      expect(p.can('sessions:create', classId: 20, classGender: 2), isTrue);
      expect(p.remindsConduction(classId: 20), isFalse);
    });

    test('gender admin who teaches a class: yes for that class only', () {
      final p = held([
        'sessions:create:gender',
        'sessions:create:own',
      ], scopes: const PermissionScopes(gender: 2, own: [20], taught: [20]));
      expect(p.remindsConduction(classId: 20), isTrue);
      expect(p.remindsConduction(classId: 21), isFalse);
    });

    test('super admin: no reminders', () {
      final p = held(['sessions:create:all']);
      expect(p.can('sessions:create', classId: 10, classGender: 1), isTrue);
      expect(p.remindsConduction(classId: 10), isFalse);
    });

    test('student: no', () {
      final p = held([
        'classes:read:enrolled',
      ], scopes: const PermissionScopes(enrolled: [10]));
      expect(p.remindsConduction(classId: 10), isFalse);
    });
  });
}
