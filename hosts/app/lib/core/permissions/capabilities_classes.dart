import '../../features/classes/models/class_model.dart';
import 'capabilities.dart';

/// What the class screens may show. Each answer comes from the server's grant
/// for that class; the class list decides only which classes exist and the
/// role badge.
///
/// Rules, each pinned by a test:
/// - Actions follow the grant, the badge follows the list's role. A class the
///   list calls "conducting" without a `sessions:create` grant shows its
///   badge and no conduction action: the server decides what is allowed.
/// - A class's gender comes from the loaded list. Until it loads it is null,
///   and a gender admin's grant is then read as reaching their own gender, so
///   a button does not vanish while the list loads. The server still checks.
extension ClassCapabilities on Capabilities {
  /// The class screen lists classes when the loaded list has any. This is the
  /// list half of the Classes tab rule, so the screen is never empty while the
  /// tab shows because of the list.
  bool hasClassList(List<ClassModel>? classes) => classes?.isNotEmpty ?? false;

  bool canUpdateClass(int classId, {int? classGender}) =>
      _grants('classes:update', classId, classGender);

  bool canEditSchedule(int classId, {int? classGender}) =>
      _grants('classes:schedule', classId, classGender);

  bool canReadStudents(int classId, {int? classGender}) =>
      _grants('class-students:read', classId, classGender);

  bool canRecordConduction(int classId, {int? classGender}) =>
      _grants('sessions:create', classId, classGender);

  bool canManageMcqs(int classId, {int? classGender}) =>
      _grants('mcqs:manage', classId, classGender);

  bool canCopyMcqs(int classId, {int? classGender}) =>
      _grants('mcqs:copy', classId, classGender);

  bool canSendNotification(int classId, {int? classGender}) =>
      _grants('notifications:send', classId, classGender);

  // Parents of a student (#633): add one, add one by token, manage one's own.
  bool get canAddParents => payload?.canAddParents ?? false;
  bool get canAddParentByToken => payload?.canAddParentByToken ?? false;
  bool get canManageOwnParents => payload?.canManageOwnParents ?? false;

  /// Does any of [classes] give the member a weekly conduction reminder?
  /// Decides whether the reminder settings show the conduction toggle.
  bool hasConductionReminders(List<ClassModel>? classes) =>
      classes?.any((cls) => remindsConduction(classId: cls.id)) ?? false;

  bool _grants(String permission, int classId, int? classGender) => can(
    permission,
    classId: classId,
    classGender: classGender ?? genderScope,
  );
}
