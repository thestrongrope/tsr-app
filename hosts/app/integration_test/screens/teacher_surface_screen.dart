import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

/// Finders for the teacher's own surface: the tiles the class dashboard offers
/// someone who *conducts* the class, and the screens behind them.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// **The teacher's dashboard is three destinations, not five.** Take Quiz and
/// the whole Performance Overview section are wrapped in `if (!isConducting)`
/// (`class_dashboard_screen.dart:418` and `:454`) — they are student views, and
/// the conducting teacher has no attendance or quiz rows of their own to show.
/// So `/classes/:id/performance` and `/classes/:id/quizzes` are not reachable
/// from here at all, which is why this object names them only as absences.
///
/// **Arrival is asserted on the AppBar title, scoped to the AppBar.** Two of
/// the three destinations carry a title identical to the tile that opens them
/// ('Class Conduction', 'MCQ Management'), so an unscoped `find.text` can match
/// the route being left during the push transition. Scoping removes the whole
/// collision class rather than hunting a unique landmark per screen.
///
/// Nothing here writes. Each screen is reached, asserted and left. The share
/// tile opens the system share sheet, which is dismissed without sharing.
class TeacherSurfaceScreenObject {
  const TeacherSurfaceScreenObject(this.$);

  final PatrolIntegrationTester $;

  // --- Dashboard tiles ------------------------------------------------------

  PatrolFinder get conductionTile => $('Class Conduction');
  PatrolFinder get mcqManageTile => $('MCQ Management');

  /// Same permission as MCQ Management (mcqs:manage on the class, #692).
  PatrolFinder get studentPerformanceTile => $('Student Performance');
  PatrolFinder get syllabusTile => $('Syllabus');

  /// Shown only when the class carries a `joinUrl`, which the server sends to
  /// the class teacher alone (#408). Its absence for the reviewer means the
  /// class list came from a cache written before `joinUrl` existed, or the
  /// server gate stopped recognising the teacher -- not a layout problem.
  PatrolFinder get shareJoinLinkTile => $('Share Join Link');

  /// Student-only, and asserted absent. Their presence would mean the class
  /// came back with `isConducting: false` — a permissions answer, not a
  /// navigation one.
  PatrolFinder get takeQuizTile => $('Take Quiz');
  PatrolFinder get performanceSection => $('Performance Overview');

  // --- Arrivals -------------------------------------------------------------

  PatrolFinder get conductionTitle => $(AppBar).$('Class Conduction');
  PatrolFinder get mcqManageTitle => $(AppBar).$('MCQ Management');

  /// A pattern, not a string: the syllabus screen titles itself
  /// `'<levelName> Syllabus'` when it has data and bare `'Syllabus'` when it
  /// does not, and the local `syllabus` table is empty. Matching the suffix
  /// keeps the assertion honest in both cases.
  PatrolFinder get syllabusTitle => $(AppBar).$(RegExp('Syllabus'));

  /// The AppBar's default leading widget. Used instead of a native back press
  /// because it stays inside the Flutter tree, and so carries over to the iOS
  /// half unchanged. None of the three screens overrides `leading`.
  PatrolFinder get backButton => $(BackButton);
}
