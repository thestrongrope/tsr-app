import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Finders for managing a class (#402, #403): the dashboard tile that opens it,
/// the three tabs, and the student actions.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// **Who sees what.** `classes:update` (the super admin, a gents or ladies admin
/// for their own gender, a coordinator for an assigned class) gets **Manage
/// Class**, and **Class Students** opening its Students tab. A teacher who only
/// holds `class-students:read` gets **Class Students** alone, names only. A
/// member gets neither.
///
/// **Inside the manage screen the student actions follow the server's
/// permissions**, which differ by role: Remove and Restore are `students:enrol`,
/// the MCQ-admin flag is `class-students:update`, Transfer is `students:transfer`
/// (super admin only). The app labels are the strings below.
class ManageClassScreenObject {
  const ManageClassScreenObject(this.$);

  final PatrolIntegrationTester $;

  // --- Dashboard tiles ------------------------------------------------------

  PatrolFinder get manageClassTile => $('Edit class');
  PatrolFinder get classStudentsTile => $('Class Students');

  // --- Tabs -----------------------------------------------------------------

  PatrolFinder get detailsTab => $(Tab).containing('Details');
  PatrolFinder get scheduleTab => $(Tab).containing('Schedule');
  PatrolFinder get studentsTab => $(Tab).containing('Students');

  // --- Details and Schedule (saved together) --------------------------------

  /// `labelText: 'City'` on the Details tab.
  PatrolFinder get cityField => $(TextFormField).containing('City');

  /// Only on screen while there are unsaved edits.
  PatrolFinder get saveButton => $(FilledButton).containing('Save changes');
  PatrolFinder get savedMessage => $('Class saved');

  PatrolFinder get addDayButton => $(OutlinedButton).containing('Add a day');

  /// One per weekly slot, so counting them counts the slots.
  PatrolFinder get removeDayButtons => $(find.byTooltip('Remove this day'));

  // --- Students -------------------------------------------------------------

  /// The three views are one segmented button; each label carries a count, such
  /// as `Active (10)`.
  PatrolFinder get activeSegment => $(RegExp(r'^Active \(\d+\)$'));
  PatrolFinder get removedSegment => $(RegExp(r'^Removed \(\d+\)$'));

  /// Only offered when someone who took the class's quizzes is not enrolled.
  PatrolFinder get quizTakersSegment => $(RegExp(r'^Quiz takers \(\d+\)$'));

  /// Super admin only.
  PatrolFinder get transfersSegment => $('Transfers');

  /// "Add several" on the Active view, offered with students:enrol (#691).
  PatrolFinder get bulkAddButton =>
      $(find.byKey(const Key('bulk-add-students')));
  PatrolFinder get bulkAddField => $(find.byKey(const Key('bulk-add-field')));

  /// One three-dot menu per active student, in name order.
  PatrolFinder get studentMenus => $(PopupMenuButton<String>);

  PatrolFinder get editItem => $('Edit details');
  PatrolFinder get makeMcqAdminItem => $('Make MCQ admin');
  PatrolFinder get removeMcqAdminItem => $('Remove MCQ admin');

  /// The row icon shown once a student holds the flag. It appears when the
  /// roster has reloaded, so wait for it before opening the student's menu.
  PatrolFinder get mcqAdminBadge => $(find.byTooltip('MCQ admin'));
  PatrolFinder get transferItem => $('Transfer');
  PatrolFinder get removeItem => $('Remove');

  PatrolFinder get restoreButton => $('Restore');
  PatrolFinder get addButton => $('Add');

  /// The Remove dialog: a required reason, then the confirm button.
  PatrolFinder get reasonField => $(AlertDialog).$(TextField);
  PatrolFinder get confirmRemoveButton => $(AlertDialog).$(FilledButton);

  /// The number in a segment label such as `Active (10)`.
  int countOf(PatrolFinder segment) =>
      int.parse(RegExp(r'\((\d+)\)').firstMatch(segment.text!)!.group(1)!);
}
