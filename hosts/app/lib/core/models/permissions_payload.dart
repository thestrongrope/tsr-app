/// What the signed-in user may do, as `GET /me/permissions` (version 4 or 5)
/// sends it.
///
/// Roles are only groups of permissions: this model holds no role flags and no
/// role names. Every gate in the app asks [PermissionsPayload.can].
/// Server contract: docs/specs/me-permissions/plan.md.
class PermissionScopes {
  /// The gender a gender admin manages (1 gents, 2 ladies), else null.
  final int? gender;
  final List<int> assigned;
  final List<int> own;
  final List<int> taught;
  final List<int> enrolled;

  const PermissionScopes({
    this.gender,
    this.assigned = const [],
    this.own = const [],
    this.taught = const [],
    this.enrolled = const [],
  });

  /// A missing or malformed `scopes` parses as empty, never as a grant.
  factory PermissionScopes.fromJson(Object? json) {
    if (json is! Map) return const PermissionScopes();
    return PermissionScopes(
      gender: (json['gender'] as num?)?.toInt(),
      assigned: _ids(json['assigned']),
      own: _ids(json['own']),
      taught: _ids(json['taught']),
      enrolled: _ids(json['enrolled']),
    );
  }

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'assigned': assigned,
    'own': own,
    'taught': taught,
    'enrolled': enrolled,
  };

  static List<int> _ids(Object? value) {
    if (value is! List) return const [];
    return value.map((id) => (id as num).toInt()).toList();
  }
}

/// The two tab decisions the server makes for the member (version 5).
class PermissionsNavigation {
  final bool classes;
  final bool manage;

  const PermissionsNavigation({required this.classes, required this.manage});

  /// Absent or malformed parses as null, so the caller falls back to the local
  /// rules rather than hiding a tab.
  static PermissionsNavigation? fromJson(Object? json) {
    if (json is! Map) return null;
    final classes = json['classes'];
    final manage = json['manage'];
    if (classes is! bool || manage is! bool) return null;
    return PermissionsNavigation(classes: classes, manage: manage);
  }

  Map<String, dynamic> toJson() => {'classes': classes, 'manage': manage};
}

class PermissionsPayload {
  final int version;

  /// Identifies this exact answer (16 hex characters); null on a version 4
  /// body. Equal state on the server gives an equal revision.
  final String? revision;

  /// What the server says about the Classes and Manage tabs; null on a
  /// version 4 body.
  final PermissionsNavigation? navigation;

  /// `resource:action:scope` names.
  final List<String> permissions;
  final PermissionScopes scopes;
  final String issuedAt;

  const PermissionsPayload({
    required this.version,
    required this.permissions,
    this.scopes = const PermissionScopes(),
    required this.issuedAt,
    this.revision,
    this.navigation,
  });

  /// What a member holds when nothing has been fetched: no admin surface.
  const PermissionsPayload.member()
    : version = 4,
      permissions = const [],
      scopes = const PermissionScopes(),
      issuedAt = '',
      revision = null,
      navigation = null;

  /// Unknown fields are ignored; missing ones parse as "nothing granted".
  factory PermissionsPayload.fromJson(Map<String, dynamic> json) =>
      PermissionsPayload(
        version: (json['version'] as num?)?.toInt() ?? 4,
        permissions: List<String>.from(json['permissions'] ?? const <String>[]),
        scopes: PermissionScopes.fromJson(json['scopes']),
        issuedAt: (json['issued_at'] ?? '') as String,
        revision: json['revision'] as String?,
        navigation: PermissionsNavigation.fromJson(json['navigation']),
      );

  Map<String, dynamic> toJson() => {
    'version': version,
    'permissions': permissions,
    'scopes': scopes.toJson(),
    'issued_at': issuedAt,
    'revision': revision,
    'navigation': navigation?.toJson(),
  };

  /// May the user do [permission] (`resource:action`)?
  ///
  /// With no class, only a grant in scope `all` counts. With a class, any held
  /// scope that reaches it counts: `all`; `gender` when [classGender] is the
  /// admin's gender; `assigned`, `own`, `taught` or `enrolled` when [classId]
  /// is in that list. An unknown permission or scope is false.
  bool can(String permission, {int? classId, int? classGender}) {
    return _heldScopes(
      permission,
    ).any((scope) => _reaches(scope, classId, classGender));
  }

  /// Does the user get the weekly conduction reminder for this class?
  ///
  /// Only the class's teacher: reminders are for classes a member attends or
  /// conducts, never for ones they manage. Holding `sessions:create` is not
  /// enough: `own` also covers a class's MCQ admin, and `assigned`, `gender`
  /// and `all` reach classes the user manages but does not run.
  bool remindsConduction({required int classId}) {
    final held = _heldScopes('sessions:create').toSet();
    return held.contains('own') && scopes.taught.contains(classId);
  }

  /// Does the user attend any class? (Gates loading the home class list.)
  bool get isEnrolled => scopes.enrolled.isNotEmpty;

  /// Does the user attend, conduct or manage a class? Gates the Classes tab
  /// (#643). Attending is `enrolled`; conducting is `taught` (the teacher) or
  /// `own` (the class's MCQ admin); managing is `assigned` (a coordinator's
  /// classes) or reading a gender's or every class. Everyone holds
  /// `classes:read` at scope `enrolled`, so the permission alone says nothing:
  /// a class in a list does.
  bool get hasClasses =>
      scopes.enrolled.isNotEmpty ||
      scopes.taught.isNotEmpty ||
      scopes.own.isNotEmpty ||
      scopes.assigned.isNotEmpty ||
      _heldScopes('classes:read').any((s) => s == 'gender' || s == 'all');

  /// Is the Classes tab shown? The server's answer when it gave one, else
  /// [hasClasses] (a version 4 body).
  bool get showsClassesTab => navigation?.classes ?? hasClasses;

  /// Is the Manage tab shown? The server's answer when it gave one, else
  /// [hasAdminModule] (a version 4 body).
  bool get showsManageTab => navigation?.manage ?? hasAdminModule;

  /// Does the user hold a permission that has a module in the admin dashboard?
  bool get hasAdminModule =>
      canBroadcast ||
      canUpdateSyllabus ||
      canReadReports ||
      canManageDeactivatedClasses ||
      canManageTeachers ||
      canManageWhatsappReminders ||
      canReadDonors ||
      canManageDeletionRequests ||
      canTransferStudents ||
      canManagePermissions ||
      canManageClassAccess ||
      canManageClassEvents ||
      canEnrolByToken ||
      canManageGuides ||
      canUpdateStandardMcqs ||
      canAdminQuiz ||
      canCopyMcqs ||
      canReadAuditLog ||
      canReviewFeedback;

  bool get canBroadcast => can('notifications:broadcast');

  /// Holds global access to the class event picker. Class-scoped senders reach
  /// events from their class dashboard instead.
  bool get canManageClassEvents =>
      _heldScopes('notifications:send').contains('all');

  bool get canUpdateSyllabus => can('syllabus:update');

  /// Holds `reports:read` in any scope. Not `can('reports:read')`, which with no
  /// class counts only scope `all` and would hide the reports from a gender
  /// admin or a coordinator; the server narrows what each of them sees.
  bool get canReadReports => _heldScopes('reports:read').isNotEmpty;

  /// Holds `quran-leaderboard:read` in any scope (a gender admin holds it for
  /// their gender; the server narrows what they see).
  bool get canReadQuranLeaderboard =>
      _heldScopes('quran-leaderboard:read').isNotEmpty;

  /// Holds `registrations:read` in any scope (a gender admin for their gender,
  /// a coordinator for the classes assigned to them; the server narrows it).
  bool get canReadRegistrations => _heldScopes('registrations:read').isNotEmpty;

  /// Holds `classes:create` in any scope (a gender admin for their gender, the
  /// super admin for both; the server says which genders and refuses the rest).
  bool get canCreateClass => _heldScopes('classes:create').isNotEmpty;

  /// Holds `deactivated-classes:manage` (the super admin only, at scope `all`):
  /// may retire a class and see which have been retired.
  bool get canManageDeactivatedClasses =>
      _heldScopes('deactivated-classes:manage').isNotEmpty;

  /// Holds `donors:read` (Finance and the super admin, at scope `all`): may see
  /// the donors list and download it.
  bool get canReadDonors => _heldScopes('donors:read').isNotEmpty;

  /// Holds `deletion-requests:manage`: may work the account-deletion queue,
  /// including completing a request, which cannot be undone.
  bool get canManageDeletionRequests =>
      _heldScopes('deletion-requests:manage').isNotEmpty;

  /// Holds `students:transfer` (the super admin only, at scope `all`): may
  /// move students between classes in bulk and read the transfer history.
  bool get canTransferStudents => _heldScopes('students:transfer').isNotEmpty;

  /// Holds `permissions:manage` (the super admin only, at scope `all`): may
  /// grant and revoke other members' permissions.
  bool get canManagePermissions => _heldScopes('permissions:manage').isNotEmpty;

  /// Holds `class-access:manage` in any scope (a gender admin for their gender,
  /// the super admin for both): may make a member a class admin and set their
  /// classes. The server narrows which members and genders.
  bool get canManageClassAccess =>
      _heldScopes('class-access:manage').isNotEmpty;

  /// Holds `members:enrol-by-token` (the super admin, at scope `all`): may
  /// look a member up by token, contact details included, and enrol them in a
  /// class.
  bool get canEnrolByToken => _heldScopes('members:enrol-by-token').isNotEmpty;

  /// Holds `guides:manage` (the super admin, at scope `all`): may edit a class
  /// level's guide.
  bool get canManageGuides => _heldScopes('guides:manage').isNotEmpty;

  /// Holds `standard-mcqs:update` (the super admin, and members granted it, at
  /// scope `all`): may replace the Standard MCQs from the source sheet.
  bool get canUpdateStandardMcqs =>
      _heldScopes('standard-mcqs:update').isNotEmpty;

  /// Holds `quiz:admin` (members granted it, at scope `all`): may run the Grand
  /// and Mega quizzes, from the download to the public sheet (#673).
  bool get canAdminQuiz => _heldScopes('quiz:admin').isNotEmpty;

  /// Holds `quiz:reset` (named members, at scope `all`): may also delete all
  /// quiz data. Shows the delete-all control and nothing else; the server
  /// refuses it without this permission.
  bool get canResetQuiz => _heldScopes('quiz:reset').isNotEmpty;

  /// Holds `mcqs:copy` in any scope (a gender admin for their gender, a
  /// coordinator for the classes assigned to them, the super admin for all; the
  /// server narrows which classes the picker lists). Managing a class's MCQs
  /// does not give it.
  bool get canCopyMcqs => _heldScopes('mcqs:copy').isNotEmpty;

  /// Holds `audit-log:read` (the super admin, at scope `all`): may read the
  /// admin access log and download it.
  bool get canReadAuditLog => _heldScopes('audit-log:read').isNotEmpty;

  /// Holds `whatsapp:manage` (the super admin only, at scope `all`): may see
  /// and change the WhatsApp reminders and run them.
  bool get canManageWhatsappReminders =>
      _heldScopes('whatsapp:manage').isNotEmpty;

  /// Holds `teachers:read` in any scope (a gender admin for their gender; the
  /// server narrows what they see). Its writes ride on the same grant until
  /// `teachers:update` exists (#200).
  bool get canManageTeachers => _heldScopes('teachers:read').isNotEmpty;

  /// Holds `teachers:read` for every gender (the super admin), so may choose
  /// whose teachers to see; a gender admin is pinned to their own.
  bool get canChooseTeacherGender =>
      _heldScopes('teachers:read').contains('all');

  /// Holds `parents:add` in any scope (staff who may link parents to students) (#633).
  bool get canAddParents => _heldScopes('parents:add').isNotEmpty;

  /// Holds `parents:add-direct` in any scope (staff who may link a parent by token number, #633).
  /// MCQ admins hold only `parents:add`, so they get the invite link but not token entry.
  bool get canAddParentByToken => _heldScopes('parents:add-direct').isNotEmpty;

  /// Holds `feedback:review` in any scope (reviewers and super admin): may
  /// review member feedback and mark items handled or unhandled (#891).
  bool get canReviewFeedback => _heldScopes('feedback:review').isNotEmpty;

  /// Holds `parents:manage:self` (a member or student who may manage their own parents) (#633).
  bool get canManageOwnParents =>
      _heldScopes('parents:manage').contains('self');

  Iterable<String> _heldScopes(String permission) {
    final prefix = '$permission:';
    return permissions
        .where((name) => name.startsWith(prefix))
        .map((name) => name.substring(prefix.length));
  }

  bool _reaches(String scope, int? classId, int? classGender) {
    switch (scope) {
      case 'all':
      case 'self':
        return true;
      case 'gender':
        return classGender != null &&
            scopes.gender != null &&
            classGender == scopes.gender;
      case 'assigned':
        return classId != null && scopes.assigned.contains(classId);
      case 'own':
        return classId != null && scopes.own.contains(classId);
      case 'taught':
        return classId != null && scopes.taught.contains(classId);
      case 'enrolled':
        return classId != null && scopes.enrolled.contains(classId);
      default:
        return false;
    }
  }
}
