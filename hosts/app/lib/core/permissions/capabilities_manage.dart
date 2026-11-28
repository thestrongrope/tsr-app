import 'capabilities.dart';

/// What the Manage hub, the reports, the admin screens, search and the local
/// reminders may show. Each answer comes from the server's saved answer held by
/// [Capabilities]; nothing is granted before the server has answered.
///
/// The Manage tab and the hub's empty state share one fact,
/// [Capabilities.showManageTab]. Home's admin cards use the same fact.
extension ManageCapabilities on Capabilities {
  /// Has the server answered at all? False only before the first answer.
  bool get hasAnswer => payload != null;

  // Manage hub tiles: each reads the permission it gates on.
  bool get canReadReports => payload?.canReadReports ?? false;
  bool get canReadAuditLog => payload?.canReadAuditLog ?? false;
  bool get canBroadcast => payload?.canBroadcast ?? false;
  bool get canManageClassEvents => payload?.canManageClassEvents ?? false;
  bool get canManageClassAccess => payload?.canManageClassAccess ?? false;
  bool get canEnrolByToken => payload?.canEnrolByToken ?? false;
  bool get canManageWhatsappReminders =>
      payload?.canManageWhatsappReminders ?? false;
  bool get canManageTeachers => payload?.canManageTeachers ?? false;
  bool get canTransferStudents => payload?.canTransferStudents ?? false;
  bool get canReadDonors => payload?.canReadDonors ?? false;
  bool get canUpdateSyllabus => payload?.canUpdateSyllabus ?? false;
  bool get canManageGuides => payload?.canManageGuides ?? false;
  bool get canUpdateStandardMcqs => payload?.canUpdateStandardMcqs ?? false;
  bool get canCopyMcqs => payload?.canCopyMcqs ?? false;
  bool get canAdminQuiz => payload?.canAdminQuiz ?? false;
  bool get canManagePermissions => payload?.canManagePermissions ?? false;
  bool get canManageDeactivatedClasses =>
      payload?.canManageDeactivatedClasses ?? false;
  bool get canManageDeletionRequests =>
      payload?.canManageDeletionRequests ?? false;
  bool get canReviewFeedback => payload?.canReviewFeedback ?? false;

  // Reports and admin screens.
  bool get canReadQuranLeaderboard => payload?.canReadQuranLeaderboard ?? false;
  bool get canReadRegistrations => payload?.canReadRegistrations ?? false;
  bool get canCreateClass => payload?.canCreateClass ?? false;
  bool get canRejectRegistrations =>
      payload?.can('registrations:reject') ?? false;
  bool get canResetQuiz => payload?.canResetQuiz ?? false;
  bool get canChooseTeacherGender => payload?.canChooseTeacherGender ?? false;

  /// The gender a gender admin manages, else null.
  int? get managedGender => payload?.scopes.gender;

  /// Reports screens show a gender picker only to a member who reads every
  /// gender; anyone else is pinned to their own (the server narrows too).
  bool get choosesReportsGender => payload?.can('reports:read') ?? false;
  bool get choosesLeaderboardGender =>
      payload?.can('quran-leaderboard:read') ?? false;
  bool get choosesRegistrationsGender =>
      payload?.can('registrations:read') ?? false;

  // Loading classes and local reminders. Reminders are decided on the phone
  // only; the server has no twin for this rule.
  bool get isEnrolled => payload?.isEnrolled ?? false;
}
