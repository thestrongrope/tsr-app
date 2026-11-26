import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

import '../screens/admin_surface_screen.dart';
import '../screens/class_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/teacher_surface_screen.dart';

/// The six persona accounts. Invented users, one per access level, created by
/// scripts/persona-cohort.sql. Each has its own Firebase email/password login.
enum Persona {
  member('persona.member@demo.invalid'),
  coordinator('persona.coord@demo.invalid'),
  gentsAdmin('persona.gentsadmin@demo.invalid'),
  ladiesAdmin('persona.ladiesadmin@demo.invalid'),
  superAdmin('persona.superadmin@demo.invalid'),
  finance('persona.finance@demo.invalid');

  const Persona(this.email);
  final String email;
}

/// Supplied by scripts/patrol-personas.sh from .secrets/persona-credentials.env.
/// Never committed, never written into a test file.
const _personaPassword = String.fromEnvironment('TSR_PERSONA_PASSWORD');

/// Signs in as [persona]. Same flow as `signInAsReviewer`; see that file for
/// why the Sign In button is scrolled to and why the permission dialog is
/// dismissed natively.
Future<void> signInAs(PatrolIntegrationTester $, Persona persona) async {
  if (_personaPassword.isEmpty) {
    throw StateError(
      'TSR_PERSONA_PASSWORD is empty. The persona Firebase users may not exist '
      'yet. Run the suite via scripts/patrol-personas.sh, which passes the '
      'password as a --dart-define.',
    );
  }

  final login = LoginScreenObject($);
  // The app opens on Home as a guest (#555); sign-in is one tap away. The
  // wait covers the splash screen on a cold start.
  await login.inviteButton.waitUntilVisible(
    timeout: const Duration(seconds: 30),
  );
  await login.inviteButton.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));

  await signInOnLoginScreen($, persona);
}

/// Signs in as [persona] from the sign-in screen, which is already showing
/// (a link that needs an account sends a guest straight to it).
Future<void> signInOnLoginScreen(
  PatrolIntegrationTester $,
  Persona persona,
) async {
  final login = LoginScreenObject($);
  await login.emailField.enterText(persona.email);
  await login.passwordField.enterText(_personaPassword);
  await login.signInButton.scrollTo().tap();

  if (await $.platformAutomator.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 10),
  )) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }

  await $.pumpAndSettle(timeout: const Duration(seconds: 60));
}

/// Pull to refresh on the home screen. The class list is cache-first with no
/// expiry, and the sign-in fetch may predate the seed, so refresh before
/// reading classes.
Future<void> refreshHome(PatrolIntegrationTester $) async {
  await $(GlassBottomNavBar).waitUntilVisible();
  await $.tester.fling(
    find.byType(RefreshIndicator).first,
    const Offset(0, 400),
    1000,
  );
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// Taps the bottom tab labelled [label]: Home, Library, Classes or Me.
Future<void> openTab(PatrolIntegrationTester $, String label) async {
  await $(GlassBottomNavBar).$(label).tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// The Classes tab.
Future<void> openMyClasses(PatrolIntegrationTester $) => openTab($, 'Classes');

/// Pushes [path] through the app's own router, as a deep link would.
Future<void> pushRoute(PatrolIntegrationTester $, String path) async {
  final context = $.tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(path);
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// Steps through the class list from the top, one screenful at a time, calling
/// [onScreen] after each step; stops early when it returns true.
Future<void> _stepClassList(
  PatrolIntegrationTester $,
  bool Function() onScreen,
) async {
  final position = $.tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  position.jumpTo(0);
  await $.tester.pump();
  while (true) {
    if (onScreen()) return;
    if (position.pixels >= position.maxScrollExtent - 1) return;
    position.jumpTo(
      (position.pixels + position.viewportDimension * 0.7).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await $.tester.pump();
  }
}

/// Returns which of [codes] were on screen at any point of a full walk down the
/// class list.
///
/// `findsNothing` on a lazy list only sees the children built right now, and the
/// local database holds a couple of hundred real classes, so an absence is only
/// meaningful after every screenful has been looked at. Assert on the demo
/// codes only (`AYD`, `AYP`), never on real classes.
Future<Set<String>> walkClassList(
  PatrolIntegrationTester $,
  List<String> codes,
) async {
  final seen = <String>{};
  await _stepClassList($, () {
    for (final code in codes) {
      if (find.text(code).evaluate().isNotEmpty) seen.add(code);
    }
    return false;
  });
  return seen;
}

/// Types [text] into the class list's search box (scrolled back to the top
/// first: the list is lazy and the box is its first row), or clears it when
/// [text] is empty.
Future<void> searchClassList(PatrolIntegrationTester $, String text) async {
  $.tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await $.tester.pump();
  await $.tester.enterText(find.byType(TextField).first, text);
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// Whether some text on screen matches [pattern] (the class list's counts).
Finder textMatching(RegExp pattern) => find.byWidgetPredicate(
  (widget) => widget is Text && pattern.hasMatch(widget.data ?? ''),
);

/// Scrolls the class list until the card with [code] is built, then taps it.
///
/// The list is lazy and can rebuild under a settle (a refresh that lands after
/// a search was cleared), which drops the card between finding it and tapping
/// it. So the card is looked for again until it is on screen at the tap.
Future<void> openClassFromList(PatrolIntegrationTester $, String code) async {
  // Text widgets only: find.text also matches the search box's own text, so a
  // query still typed there would be tapped instead of the class card.
  final card = find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == code,
  );
  // Tap the whole card, not the small code chip inside it: the chip can sit at
  // the clipped edge of the list under the app bar, where a tap lands on nothing.
  Finder tile() =>
      find.ancestor(of: card.first, matching: find.byType(InkWell)).first;
  const looks = 5;
  for (var look = 1; look <= looks; look++) {
    await _stepClassList($, () => card.evaluate().isNotEmpty);
    if (card.evaluate().isEmpty) {
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      continue;
    }
    await $.tester.ensureVisible(tile());
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    if (card.evaluate().isEmpty) continue;
    await $.tester.tap(tile());
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    return;
  }
  fail('class $code was not on the class list after $looks looks');
}

/// Pops the current route through the app's own router.
Future<void> popRoute(PatrolIntegrationTester $) async {
  final context = $.tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).pop();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// The class dashboard's tiles, asserted both ways. The dashboard is a plain
/// scroll view, so an absent tile really is absent from the tree.
///
/// The Syllabus tile is shown to every role, so it is waited for first: the
/// absences below only mean something once the dashboard has rendered.
Future<void> expectDashboardTiles(
  PatrolIntegrationTester $, {
  required bool conduction,
  required bool mcq,
  required bool notification,
  required bool shareJoinLink,
  required bool takeQuiz,
  required bool performance,
  required bool syllabus,
  bool? manageClass,
  bool? classStudents,
}) async {
  final teacher = TeacherSurfaceScreenObject($);
  await teacher.syllabusTile.waitUntilExists();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));

  void check(String name, Finder finder, bool expected) {
    expect(
      finder,
      expected ? findsWidgets : findsNothing,
      reason:
          'dashboard tile "$name" should be '
          '${expected ? 'visible' : 'absent'}',
    );
  }

  check('Class Conduction', teacher.conductionTile, conduction);
  check('MCQ Management', teacher.mcqManageTile, mcq);
  check('Class Notification', find.text('Class Notification'), notification);
  // Student Performance follows MCQ Management: both are mcqs:manage (#692).
  check('Student Performance', teacher.studentPerformanceTile, mcq);
  check('Share Join Link', teacher.shareJoinLinkTile, shareJoinLink);
  check('Take Quiz', teacher.takeQuizTile, takeQuiz);
  check('Performance Overview', teacher.performanceSection, performance);
  check('Syllabus', teacher.syllabusTile, syllabus);

  // Manage Class (classes:update) and Class Students (class-students:read) are
  // checked only by the journeys that say which they expect (#402).
  if (manageClass != null) {
    check('Edit class', find.text('Edit class'), manageClass);
  }
  if (classStudents != null) {
    check('Class Students', find.text('Class Students'), classStudents);
  }
}

/// Codes of the three demo classes, for [walkClassList].
const demoCodes = [
  ClassListScreenObject.demoClassCode,
  ClassListScreenObject.miqdadClassCode,
  'AYP1',
];

/// Taps Share as PDF and waits for the system share sheet: the real path,
/// download from the local API, save, open the sheet. A failed download would
/// show the failure message instead of the sheet. Then backs out of the sheet
/// and waits for [screenTitle] to be back.
Future<void> _shareAsPdfAndReturn(
  PatrolIntegrationTester $,
  PatrolFinder screenTitle,
) async {
  final admin = AdminSurfaceScreenObject($);
  await admin.shareMenu.tap();
  await admin.sharePdf.tap();
  // Wait for the outcome, not a fixed time: the error message fades after a
  // few seconds, and the system sheet takes the app out of the foreground.
  var sheetOpened = false;
  for (var i = 0; i < 40 && !sheetOpened; i++) {
    await $.tester.pump(const Duration(milliseconds: 500));
    expect(
      admin.shareFailed,
      findsNothing,
      reason: 'the report file must download and reach the share sheet',
    );
    sheetOpened = $.tester.binding.lifecycleState != AppLifecycleState.resumed;
  }
  expect(sheetOpened, isTrue, reason: 'the share sheet never opened');
  await $.platform.android.pressBack();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await screenTitle.waitUntilVisible();
}

/// A staff persona who holds reports:read but no other admin module (a gender
/// admin or a coordinator): the Manage tab opens a dashboard with the Reports entry and
/// nothing else, the list searches, and each report opens without showing any
/// class in [mustNotSee] (the other gender's demo classes). The Quran
/// leaderboard has a permission of its own: a gender admin ([leaderboard])
/// opens it. So does Registrations, with registrations:read ([registrations]),
/// and Teachers with teachers:read ([teachers]).
/// Drags the open dropdown menu until a row containing [text] is built, up to
/// the top first and then down. A dropdown menu is a lazy list and the order
/// of its rows is the server's, so a row may be above or below the viewport.
/// Plain drags and a widget lookup, not Patrol's scrollTo, which fails the test
/// when the row is on the other side. Returns whether the row was found.
Future<bool> revealInOpenMenu(PatrolIntegrationTester $, String text) async {
  final target = find.textContaining(text);
  final menu = find.byType(Scrollable).last;
  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    await $.tester.drag(menu, const Offset(0, 400));
    await $.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 80 && target.evaluate().isEmpty; i++) {
    await $.tester.drag(menu, const Offset(0, -400));
    await $.pump(const Duration(milliseconds: 100));
  }
  return target.evaluate().isNotEmpty;
}

Future<void> expectReportsOnlyAdmin(
  PatrolIntegrationTester $, {
  required List<String> mustNotSee,
  bool shareFile = false,
  bool leaderboard = false,
  bool registrations = false,
  bool teachers = false,
}) async {
  final admin = AdminSurfaceScreenObject($);

  await admin.manageTab.waitUntilVisible();
  await admin.manageTab.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.title.waitUntilVisible();
  await admin.reportsCard.waitUntilVisible();
  expect(admin.notificationsCard, findsNothing);
  expect(admin.syllabusManagementCard, findsNothing);
  expect(
    admin.deactivatedClassesCard,
    findsNothing,
    reason: 'deactivating classes is for the super admin only',
  );
  // teachers:read is a gender admin's and the super admin's, not a coordinator's.
  expect(
    admin.teachersCard,
    teachers ? findsOneWidget : findsNothing,
    reason: 'the Teachers card is for whoever holds teachers:read',
  );

  await admin.reportsCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.reportsTitle.waitUntilVisible();
  await admin.conductionReportCard.waitUntilVisible();
  // The list searches: a name narrows it, and clearing brings the rest back.
  await $(TextField).enterText('summary');
  await $.pumpAndSettle();
  await admin.summaryReportCard.waitUntilVisible();
  expect(admin.conductionReportCard, findsNothing);
  await $(TextField).enterText('');
  await $.pumpAndSettle();
  await admin.conductionReportCard.waitUntilVisible();

  await admin.conductionReportCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.conductionReportTitle.waitUntilVisible();
  await $('This week').waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'the report must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );

  // The share menu offers the all-weeks file (#679). Look, do not choose: that
  // would open the system share sheet. Tapping outside closes the menu.
  await admin.shareMenu.tap();
  await $(
    'Share all weeks (CSV)',
  ).waitUntilVisible(timeout: const Duration(seconds: 10));
  await $.tester.tapAt(const Offset(2, 2)); // the menu's barrier
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await admin.conductionReportTitle.waitUntilVisible(
    timeout: const Duration(seconds: 10),
  );

  if (shareFile) await _shareAsPdfAndReturn($, admin.conductionReportTitle);

  // Back to the list, then the weekly report: it opens on the week stepper
  // (or says the period is empty) and shows no class in [mustNotSee].
  await popRoute($);
  await admin.weeklyReportCard.waitUntilVisible();
  await admin.weeklyReportCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.weeklyReportTitle.waitUntilVisible();
  await $(DropdownButtonFormField<String>).first.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'the weekly report must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  if (shareFile) await _shareAsPdfAndReturn($, admin.weeklyReportTitle);

  // And the class summary, the same way.
  await popRoute($);
  await admin.summaryReportCard.waitUntilVisible();
  await admin.summaryReportCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.summaryReportTitle.waitUntilVisible();
  await $(DropdownButtonFormField<String>).first.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'the summary must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  if (shareFile) await _shareAsPdfAndReturn($, admin.summaryReportTitle);

  // And the student performance report: its students are those of the
  // persona's own classes, so none of [mustNotSee] may appear.
  await popRoute($);
  await admin.studentPerformanceCard.waitUntilVisible();
  await admin.studentPerformanceCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.studentPerformanceTitle.waitUntilVisible();
  await $(TextField).waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'the student report must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  if (shareFile) await _shareAsPdfAndReturn($, admin.studentPerformanceTitle);

  // And TSR at a glance: its four sections cover the persona's own classes.
  await popRoute($);
  await admin.tsrReportCard.waitUntilVisible();
  await admin.tsrReportCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.tsrReportTitle.waitUntilVisible();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  // Either the sections, or, for a persona whose classes are all excluded from
  // reports, the empty message.
  expect(
    $('Class conduction').exists ||
        $('No classes were found in this period.').exists,
    isTrue,
    reason: 'TSR at a glance shows neither its sections nor the empty message',
  );
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'TSR at a glance must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  if (shareFile) await _shareAsPdfAndReturn($, admin.tsrReportTitle);

  // And pending work: the teachers of the persona's own classes, none of
  // [mustNotSee].
  await popRoute($);
  await admin.pendingReportCard.waitUntilVisible();
  await admin.pendingReportCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.pendingReportTitle.waitUntilVisible();
  await $(DropdownButtonFormField<String>).first.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'pending work must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  // The reminder: open the preview and CANCEL. This never taps Send: the local
  // stack holds real push credentials and the teachers are real members. The
  // preview itself sends nothing. A persona with nothing pending has no button.
  if ($('Remind').exists) {
    await $('Remind').first.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await $('Cancel').waitUntilVisible();
    await $('Cancel').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  }
  if (shareFile) await _shareAsPdfAndReturn($, admin.pendingReportTitle);

  // And subject conduction: the persona's own classes, none of [mustNotSee].
  await popRoute($);
  await admin.subjectConductionCard.waitUntilVisible();
  await admin.subjectConductionCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.subjectConductionTitle.waitUntilVisible();
  await $(DropdownButtonFormField<String>).first.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'subject conduction must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  // The class control (#678): absent until a level is chosen, then it narrows
  // the list to one class. A month with nothing held has no level chips.
  if (admin.subjectLevelChips.evaluate().length > 1) {
    expect(
      admin.subjectClassDropdown,
      findsNothing,
      reason: 'the class control waits for a level',
    );
    await admin.subjectLevelChips.at(1).tap();
    await admin.subjectClassDropdown.waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    await admin.subjectClassDropdown.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    // Choose the first real class, not "All classes": the first row of the open
    // menu that names a class ("CODE · teacher"). Tapped by text inside the
    // menu's own list: the closed dropdown also builds its items, and Patrol's
    // DropdownMenuItem finder cannot tap them.
    await $.tester.tap(
      find
          .descendant(
            of: find.byType(Scrollable).last,
            matching: find.textContaining(' · '),
          )
          .first,
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(admin.subjectClassDropdown, findsOneWidget);
    expect(
      admin.subjectClassCards.evaluate().length,
      lessThanOrEqualTo(1),
      reason: 'one class chosen shows that class only',
    );
    if (admin.subjectClassCards.evaluate().isEmpty) {
      await $(
        'No sessions for this class in this period.',
      ).waitUntilVisible(timeout: const Duration(seconds: 10));
    }
    for (final code in mustNotSee) {
      expect(
        $(code),
        findsNothing,
        reason: 'the class list must never offer $code to this persona',
      );
    }
  }
  if (shareFile) await _shareAsPdfAndReturn($, admin.subjectConductionTitle);

  // And class sessions: the persona's own classes, none of [mustNotSee].
  await popRoute($);
  await admin.classSessionsCard.scrollTo();
  await admin.classSessionsCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.classSessionsTitle.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'class sessions must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);

  // The share menu offers the all-classes file (#680). Look, do not choose:
  // that would open the system share sheet. Tapping outside closes the menu.
  await admin.shareMenu.waitUntilVisible(timeout: const Duration(seconds: 10));
  await admin.shareMenu.tap();
  await $(
    'Share all (CSV)',
  ).waitUntilVisible(timeout: const Duration(seconds: 10));
  await $.tester.tapAt(const Offset(2, 2)); // the menu's barrier
  await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  await admin.classSessionsTitle.waitUntilVisible(
    timeout: const Duration(seconds: 10),
  );

  // And the MCQ summary: the persona's own classes, none of [mustNotSee].
  await popRoute($);
  await admin.mcqSummaryCard.scrollTo();
  await admin.mcqSummaryCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.mcqSummaryTitle.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'the MCQ summary must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  await _expectShareAllOffered(
    $,
    admin.mcqSummaryTitle,
    emptyText: 'No class published MCQs in this period.',
  ); // (#681)

  // And MCQ adherence: the persona's own classes, none of [mustNotSee].
  await popRoute($);
  await admin.mcqAdherenceCard.scrollTo();
  await admin.mcqAdherenceCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.mcqAdherenceTitle.waitUntilVisible();
  for (final code in mustNotSee) {
    expect(
      $(code),
      findsNothing,
      reason: 'MCQ adherence must never show $code to this persona',
    );
  }
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  await _expectShareAllOffered(
    $,
    admin.mcqAdherenceTitle,
    emptyText: 'No class has standard MCQs to follow.',
  ); // (#681)

  // And active teachers: the teachers of the persona's own classes.
  await popRoute($);
  await admin.activeTeachersCard.scrollTo();
  await admin.activeTeachersCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.activeTeachersTitle.waitUntilVisible();
  expect(
    $('Ladies'),
    findsNothing,
    reason: 'only a user who reaches every class chooses the gender',
  );
  expect($('The report could not be loaded.'), findsNothing);
  if (shareFile) await _shareAsPdfAndReturn($, admin.activeTeachersTitle);

  // And the Quran leaderboard, for whoever holds quran-leaderboard:read: pinned
  // to their gender. That nobody else is offered it is a widget test
  // (reports_screen_test.dart): this list builds lazily, so an absent card
  // here would prove nothing.
  await popRoute($);
  if (leaderboard) {
    await admin.quranLeaderboardCard.scrollTo();
    await admin.quranLeaderboardCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.quranLeaderboardTitle.waitUntilVisible();
    expect(
      $('Ladies'),
      findsNothing,
      reason: 'only a user who reaches every class chooses the gender',
    );
    expect($('The leaderboard could not be loaded.'), findsNothing);
    // The minimum-recitations control (#677) is there and filters: a minimum
    // nobody meets empties the list and leaves the field editable.
    await admin.quranMinimumField.waitUntilVisible(
      timeout: const Duration(seconds: 10),
    );
    await admin.quranMinimumField.enterText('999999999');
    await $(
      'No member has 999999999 or more recitations in this period.',
    ).waitUntilVisible(timeout: const Duration(seconds: 20));
    expect(admin.quranMinimumField, findsOneWidget);
    expect($('The leaderboard could not be loaded.'), findsNothing);
    await popRoute($);
  }

  // And who is waiting to be placed, pinned to the persona's gender.
  if (registrations) {
    await admin.registrationsCard.scrollTo();
    await admin.registrationsCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await admin.registrationsTitle.waitUntilVisible();
    expect(
      $('Ladies'),
      findsNothing,
      reason: 'only a user who reaches every class chooses the gender',
    );
    expect($('The registrations could not be loaded.'), findsNothing);
    await popRoute($);
  }

  // Back to the Manage dashboard, which is a tab's start: nothing below it to pop.
  await popRoute($);
}

/// Manage -> Reports -> Registrations, then narrows the list to the invented
/// registrants of scripts/persona-cohort.sql (all named "Persona Reg ..."), so a
/// journey only ever acts on those and never on a real registrant (#614).
Future<void> openPersonaRegistrations(PatrolIntegrationTester $) async {
  final admin = AdminSurfaceScreenObject($);
  await admin.manageTab.waitUntilVisible();
  await admin.manageTab.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.reportsCard.waitUntilVisible();
  await admin.reportsCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.registrationsCard.scrollTo();
  await admin.registrationsCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.registrationsTitle.waitUntilVisible();
  await $(TextField).enterText('Persona Reg');
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// Manage -> Teachers, then narrows the list to the invented teachers of
/// scripts/persona-cohort.sql (all named "Persona Teach ..."), so a journey only
/// ever acts on those and never on a real teacher (#622).
Future<void> openPersonaTeachers(PatrolIntegrationTester $) async {
  final admin = AdminSurfaceScreenObject($);
  await admin.manageTab.waitUntilVisible();
  await admin.manageTab.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  // Teachers sits below the fold since the Class events card was added.
  await admin.teachersCard.scrollTo();
  await admin.teachersCard.tap();
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  await admin.teachersTitle.waitUntilVisible();
  // The list itself loaded: its count line is there and its error is not.
  await $(RegExp(r'^\d+ teachers$')).waitUntilVisible();
  expect($('The teachers could not be loaded.'), findsNothing);
  await $(TextField).enterText('Persona Teach');
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

/// The button [label] on the card of the registrant named [name].
PatrolFinder registrantButton(
  PatrolIntegrationTester $,
  String name,
  String label,
) => $(Card).containing($(name)).$(label);

/// Waits until no widget shows [text]. Patrol can wait for something to appear
/// but not to go, and an `expect(..., findsNothing)` straight after a write
/// races the list reloading from the server (#614).
Future<void> waitUntilGone(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while ($(text).exists) {
    if (DateTime.now().isAfter(deadline)) {
      fail('"$text" was still on screen after ${timeout.inSeconds}s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await $.pump();
  }
}

/// The share menu offers the all-classes file (#681), when there is a report to
/// share; a persona whose classes hold nothing for the period is shown
/// [emptyText] and no share menu (an empty report shares no file). Look, do not
/// choose: choosing would open the system share sheet. Tapping outside closes
/// the menu.
Future<void> _expectShareAllOffered(
  PatrolIntegrationTester $,
  PatrolFinder title, {
  required String emptyText,
}) async {
  const wait = Duration(seconds: 10);
  // The report loads after the title, and the reports that cover a whole gender
  // are slow on a busy machine: wait for whichever outcome it has, up to a minute.
  for (var i = 0; i < 60; i++) {
    if ($(Icons.ios_share).exists || $(emptyText).exists) break;
    await $.pump(const Duration(seconds: 1));
  }
  if (!$(Icons.ios_share).exists) {
    // Not `expect`: a failing expect inside a Patrol test prints nothing and hangs
    // until the runner's watchdog, so a slow report once cost a 30 minute run that
    // named no reason. A thrown error names it.
    if (!$(emptyText).exists) {
      throw StateError(
        'The report offered neither a share menu nor "$emptyText" after 60 s.',
      );
    }
    return;
  }
  await $(Icons.ios_share).tap();
  await $('Share all (CSV)').waitUntilVisible(timeout: wait);
  await $.tester.tapAt(const Offset(2, 2)); // the menu's barrier
  await $.pumpAndSettle(timeout: wait);
  await title.waitUntilVisible(timeout: wait);
}
