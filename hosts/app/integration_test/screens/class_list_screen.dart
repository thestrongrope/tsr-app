import 'package:patrol/patrol.dart';

/// Finders for the home screen's class list and the class detail beneath it.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// The demo class is located by its **code**, never by its id. The reset
/// migration drops and rebuilds the class, so its autoincrement id changes on
/// every run (observed: 390, then 391), while the code `AYD1` is fixed. Dates
/// are relative for the same reason and must never be hardcoded either.
class ClassListScreenObject {
  const ClassListScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The demo class's code, stable across resets.
  static const demoClassCode = 'AYD1';

  /// The demo class's name, as written in the migration.
  static const demoClassName = 'AMMAR DEMO';

  /// The reviewer account's display name, as written in the migration.
  static const demoTeacherName = 'App Review Teacher';

  /// The cohort's second class, added so the syllabus topic dropdowns can be
  /// reached at all. Only MIQDAD has a syllabus, so [demoClassCode] above —
  /// which is AMMAR — serves the plain free-text topic box and cannot exercise
  /// them. See tsr-account `migrations/2026_09_06_reviewer_demo_cohort.sql`.
  static const miqdadClassCode = 'AYD2';
  static const miqdadClassName = 'MIQDAD DEMO';

  /// The card on the home screen's class list.
  ///
  /// Found by **code**, not by name. The home card never renders
  /// `ClassModel.name`: since #379 its title is the level
  /// (`levelName ?? 'Level N'`, so `AMMAR`), and the only other text on it is
  /// the code chip and the teacher. Matching `AMMAR DEMO` here waited out the
  /// full selector timeout on every journey in the suite — six of them —
  /// because Patrol never runs in CI and nothing else looks at this screen.
  ///
  /// The code is also the more stable anchor, for the reason already recorded
  /// above: the reset migration rebuilds the class and its id moves, but
  /// `AYD1` is fixed.
  PatrolFinder get demoClassCard => $(demoClassCode);
  PatrolFinder get miqdadClassCard => $(miqdadClassCode);

  /// The dashboard reached by tapping the class card. It shows the class code,
  /// name, teacher and schedule -- **not** the student roster, which sits a
  /// level deeper behind "Class Conduction". Asserting student names here was
  /// this suite's first wrong assumption about the app.
  PatrolFinder get classCodeChip => $(demoClassCode);
  PatrolFinder get teacherName => $('Teacher: $demoTeacherName');
  PatrolFinder get classConductionAction => $('Class Conduction');

  /// Section header on the class list, shown to someone who manages classes
  /// they do not teach. A user with a single class never sees the list at all:
  /// the screen opens that class's dashboard directly.
  PatrolFinder get managingHeader => $('Managing');

  /// The empty state of My Classes, for a user with no classes.
  PatrolFinder get noClassesYet => $('No Classes Yet');

  /// The roster itself is not on this screen or the one below it; its finders
  /// live in [ConductionScreenObject], along with why.
}
