import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/teacher_surface_screen.dart';

/// Journey 1 of the verification checklist: **the reviewer reaches every
/// teacher-facing screen.**
///
/// For the conducting teacher that is three screens, not five — Take Quiz and
/// Performance Overview are student views hidden behind `!isStaff`. The
/// journey asserts both halves: the three that must be there, and the two that
/// must not.
///
/// **A missing tile is a permissions answer, not a routing bug.** Both teacher
/// tiles return `SizedBox.shrink()` when `permissionsProvider` has no payload
/// or it does not grant `sessions:create` / `mcqs:manage` for this class, so a
/// failure here reads exactly like a navigation problem and is not one. Read
/// the permissions response first.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer reaches every teacher-facing screen', ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final teacher = TeacherSurfaceScreenObject($);

    await classes.demoClassCard.waitUntilVisible();

    // Pull to refresh before opening the class. The list is fetched from the
    // server on every launch now (the saved copy is only an offline fallback),
    // so this is no longer needed to get a fresh list; it is left in place as
    // the path a real teacher can take, and has not been re-run since.
    await $.tester.fling(
      find.byType(RefreshIndicator).first,
      const Offset(0, 400),
      1000,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // The positives come first on purpose. `findsNothing` passes on a blank
    // screen, a spinner or a failed load, so the absences below only mean
    // something once the teacher's own dashboard is known to have rendered.
    await teacher.conductionTile.waitUntilVisible();
    await teacher.mcqManageTile.waitUntilVisible();
    // scrollTo, not waitUntilVisible: the tile sits far below Class Conduction
    // and MCQ, off-screen, and waitUntilVisible does not scroll (#910).
    await teacher.shareJoinLinkTile.scrollTo();
    await teacher.syllabusTile.scrollTo();
    // scrollTo only goes down by default, and the dashboard is now long enough
    // (Share Join Link, #408) that reaching Syllabus scrolls Class Conduction
    // off the top. Come back up before the visits start with the first tile.
    await teacher.conductionTile.scrollTo(scrollDirection: AxisDirection.up);

    expect(teacher.takeQuizTile, findsNothing,
        reason: 'Take Quiz is a student action, hidden for the conducting '
            'teacher who manages quizzes instead');
    expect(teacher.performanceSection, findsNothing,
        reason: 'Performance Overview is a student metric; the conducting '
            'teacher has no attendance or quiz rows of their own here');

    await _visit($, teacher.conductionTile, teacher.conductionTitle, teacher);
    await _visit($, teacher.mcqManageTile, teacher.mcqManageTitle, teacher);
    await _visit($, teacher.syllabusTile, teacher.syllabusTitle, teacher);

    // Share Join Link (#408) opens the system share sheet. Its text differs
    // by Android version, so only the round trip is asserted: the tap does not
    // crash, a native back dismisses the sheet without sharing, and the
    // dashboard is still there.
    await teacher.shareJoinLinkTile.scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    // Android-only for now, like the suite: the iOS share sheet has no back
    // press and would need its own dismissal.
    await $.platformAutomator.android.pressBack();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    await teacher.shareJoinLinkTile.waitUntilVisible();
  });
}

/// Opens one destination, asserts arrival, and returns to the dashboard.
///
/// The return leg re-asserts a dashboard landmark rather than trusting the pop.
/// Without it a back press that did not land shows up as a finder failure on
/// the *next* screen, which is a long way from the thing that actually broke.
Future<void> _visit(
  PatrolIntegrationTester $,
  PatrolFinder tile,
  PatrolFinder arrival,
  TeacherSurfaceScreenObject teacher,
) async {
  // scrollTo() before tap(): the Share Join Link tile (#408) pushed the lower
  // tiles towards the fold, and a bare tap() waits out the selector timeout on
  // anything off-screen.
  await tile.scrollTo().tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));

  await arrival.waitUntilVisible();

  await teacher.backButton.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));

  // scrollTo(), not waitUntilVisible(): the dashboard may come back scrolled
  // down from the tile just visited, leaving the landmark off-screen above.
  // Up, because scrollTo only goes down by default; it does nothing when the
  // landmark is already on screen.
  await teacher.conductionTile.scrollTo(scrollDirection: AxisDirection.up);
}
