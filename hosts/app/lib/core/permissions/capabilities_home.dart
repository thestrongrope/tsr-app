import '../../features/classes/models/class_model.dart';
import 'capabilities.dart';

/// What Home shows, decided from [Capabilities] alone so that Home and the
/// Classes tab cannot disagree.
extension HomeCapabilities on Capabilities {
  /// The My Classes section. Shown for a member with classes, or for an
  /// enrolled member whose list has settled empty (the empty card). While the
  /// list is loading, only a member who already has classes sees it.
  bool showMyClasses({required bool classesLoading}) {
    if (classes?.isNotEmpty ?? false) return true;
    final enrolled = payload?.isEnrolled ?? false;
    return enrolled && !classesLoading;
  }

  /// "See classes" and "View all" link into the Classes tab, so both show only
  /// when that tab does.
  bool get showClassesLinks => showClassesTab;

  /// The This week card on Home, and a remembered visit to This week.
  bool get mayOpenThisWeek => payload?.canReadReports ?? false;

  /// The WhatsApp link card, and a remembered visit to WhatsApp reminders.
  bool get mayManageWhatsappReminders =>
      payload?.canManageWhatsappReminders ?? false;

  /// The classes the member conducts (the Conducting label) and may
  /// [permission] for. The permission check is the class dashboard's own, so
  /// gender segregation is unchanged.
  List<ClassModel> teachingClasses(String permission) {
    final granted = payload;
    if (granted == null) return const [];
    return [
      for (final c in classes ?? const <ClassModel>[])
        if (c.isConducting &&
            granted.can(permission, classId: c.id, classGender: c.gender))
          c,
    ];
  }

  /// Is a teaching shortcut for [permission] offered? Once the class list has
  /// loaded it answers; until then the classes the server says the member
  /// teaches do, so the shortcut does not wait for the list (#970).
  bool offersTeachingShortcut(String permission) {
    final granted = payload;
    if (granted == null) return false;
    if (classes != null) return teachingClasses(permission).isNotEmpty;
    return granted.scopes.taught.any(
      (id) => granted.can(permission, classId: id),
    );
  }

  /// The class a remembered visit points at, if it may still be offered: the
  /// class is in the loaded list and the member holds [permission] for it.
  /// A null [permission] asks only that the class is still there.
  ClassModel? classForJumpBack(int? classId, {String? permission}) {
    final granted = payload;
    if (granted == null) return null;
    final cls = (classes ?? const <ClassModel>[])
        .where((c) => c.id == classId)
        .firstOrNull;
    if (cls == null) return null;
    if (permission == null) return cls;
    final allowed = granted.can(
      permission,
      classId: cls.id,
      classGender: cls.gender,
    );
    return allowed ? cls : null;
  }

  bool get mayOpenQuizAdmin => payload?.canAdminQuiz ?? false;
  bool get mayOpenStandardMcqs => payload?.canUpdateStandardMcqs ?? false;
  bool get mayOpenTransfers => payload?.canTransferStudents ?? false;
}
