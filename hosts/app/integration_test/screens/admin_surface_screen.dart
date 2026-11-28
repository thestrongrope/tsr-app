import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';

/// Finders for the admin entry point, the Manage tab, and the screen behind it.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// The tab bar is on a tab's starting screen, so a Manage tab that is absent
/// there is really absent, not just not yet built.
class AdminSurfaceScreenObject {
  const AdminSurfaceScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The Manage tab, scoped to the tab bar; shown only to those who hold an
  /// admin module.
  PatrolFinder get manageTab => $(GlassBottomNavBar).$('Manage');

  /// The /admin screen's title, scoped to the AppBar so it cannot match the tab.
  PatrolFinder get title => $(AppBar).$('Manage');

  /// The first Manage row for anyone who holds reports:read (#615), found by its
  /// description so the This week screen's own title cannot match it.
  PatrolFinder get thisWeekRow => $('Classes that need attention this week');

  /// The This week screen's title, scoped to the AppBar.
  PatrolFinder get thisWeekTitle => $(AppBar).$('This week');

  /// The coordinator's card at the top of Home: how many classes need attention.
  PatrolFinder get thisWeekHomeCard => $(RegExp(r'^This week: '));

  PatrolFinder get notificationsCard => $('Notifications');
  PatrolFinder get syllabusManagementCard => $('Syllabus Management');

  /// The dashboard's one entry to the reports list.
  PatrolFinder get reportsCard => $('Reports');
  PatrolFinder get deactivatedClassesCard => $('Deactivated Classes');
  PatrolFinder get teachersCard => $('Teachers');
  PatrolFinder get donorsCard => $('Donors');
  PatrolFinder get deletionRequestsCard => $('Deletion requests');
  PatrolFinder get updateMcqsCard => $('Update MCQs');
  PatrolFinder get quizAdminCard => $('Quiz admin');

  /// The quiz admin screen's title, scoped to the AppBar.
  PatrolFinder get quizAdminTitle => $(AppBar).$('Quiz admin');
  PatrolFinder get transfersCard => $('Transfers & Promotions');

  /// The transfers screen's title, scoped to the AppBar.
  PatrolFinder get transfersTitle => $(AppBar).$('Transfers & Promotions');

  /// The donors screen's title, scoped to the AppBar.
  PatrolFinder get donorsTitle => $(AppBar).$('Donors');

  /// The reports list screen's title, scoped to the AppBar.
  PatrolFinder get reportsTitle => $(AppBar).$('Reports');

  /// The reports list's tiles.
  PatrolFinder get conductionReportCard => $('Conduction Report');
  PatrolFinder get weeklyReportCard => $('Weekly Report');
  PatrolFinder get summaryReportCard => $('Class Summary');
  PatrolFinder get studentPerformanceCard => $('Student Performance');
  PatrolFinder get tsrReportCard => $('TSR at a Glance');
  PatrolFinder get pendingReportCard => $('Pending Work');
  PatrolFinder get subjectConductionCard => $('Subject Conduction');
  PatrolFinder get classSessionsCard => $('Class Sessions');
  PatrolFinder get mcqSummaryCard => $('MCQ Summary');
  PatrolFinder get mcqAdherenceCard => $('MCQ Adherence');
  PatrolFinder get activeTeachersCard => $('Active Teachers');
  PatrolFinder get quranLeaderboardCard => $('Quran Leaderboard');
  PatrolFinder get registrationsCard => $('Registrations');

  PatrolFinder get shareMenu => $(Icons.ios_share);
  PatrolFinder get sharePdf => $('Share as PDF');
  PatrolFinder get shareFailed =>
      $('The file could not be prepared. Please try again.');

  /// The conduction report screen's title, scoped to the AppBar.
  PatrolFinder get conductionReportTitle => $(AppBar).$('Conduction report');

  /// The weekly report screen's title, scoped to the AppBar.
  PatrolFinder get weeklyReportTitle => $(AppBar).$('Weekly report');

  /// The class summary screen's title, scoped to the AppBar.
  PatrolFinder get summaryReportTitle => $(AppBar).$('Class summary');

  /// The student performance screen's title, scoped to the AppBar.
  PatrolFinder get studentPerformanceTitle =>
      $(AppBar).$('Student performance');

  /// The TSR at a glance screen's title, scoped to the AppBar.
  PatrolFinder get tsrReportTitle => $(AppBar).$('TSR at a glance');

  /// The pending work screen's title, scoped to the AppBar.
  PatrolFinder get pendingReportTitle => $(AppBar).$('Pending work');

  /// The subject conduction screen's title, scoped to the AppBar.
  PatrolFinder get subjectConductionTitle => $(AppBar).$('Subject conduction');

  /// Its level chips ("All" first) and the class control that follows a level
  /// (#678), and one card per class shown.
  PatrolFinder get subjectLevelChips => $(ChoiceChip);
  PatrolFinder get subjectClassDropdown => $(DropdownButtonFormField<int?>);
  PatrolFinder get subjectClassCards => $(Card);

  /// The class sessions screen's title, scoped to the AppBar.
  PatrolFinder get classSessionsTitle => $(AppBar).$('Class sessions');

  /// The MCQ summary screen's title, scoped to the AppBar.
  PatrolFinder get mcqSummaryTitle => $(AppBar).$('MCQ summary');

  /// The MCQ adherence screen's title, scoped to the AppBar.
  PatrolFinder get mcqAdherenceTitle => $(AppBar).$('MCQ adherence');

  /// The active teachers screen's title, scoped to the AppBar.
  PatrolFinder get activeTeachersTitle => $(AppBar).$('Active teachers');

  /// The Quran leaderboard screen's title, scoped to the AppBar.
  PatrolFinder get quranLeaderboardTitle => $(AppBar).$('Quran leaderboard');

  /// The Quran leaderboard's minimum-recitations field (#677).
  PatrolFinder get quranMinimumField => $(const Key('quran-minimum'));

  /// The teachers screen's title, scoped to the AppBar.
  PatrolFinder get teachersTitle => $(AppBar).$('Teachers');

  /// The deletion requests screen's title, scoped to the AppBar.
  PatrolFinder get deletionRequestsTitle => $(AppBar).$('Deletion requests');

  /// The WhatsApp Reminders card, the reminders screen's link card (#693) and the
  /// link screen behind it: its title, its state, and the two controls, which a
  /// journey only looks for and never taps.
  PatrolFinder get whatsappRemindersCard => $('WhatsApp Reminders');
  PatrolFinder get whatsappLinkCard =>
      $(RegExp(r'^WhatsApp is |^Checking the'));
  PatrolFinder get whatsappLinkTitle => $(AppBar).$('WhatsApp link');
  PatrolFinder get whatsappLinkState =>
      $(RegExp(r'^(Connected|Waiting for a scan|Offline)$'));
  PatrolFinder get whatsappRelinkButton => $('Re-link WhatsApp');
  PatrolFinder get whatsappLogoutButton => $('Log out of WhatsApp');

  /// The Update MCQs screen's title, scoped to the AppBar.
  PatrolFinder get updateMcqsTitle => $(AppBar).$('Update MCQs');

  /// The registrations screen's title, scoped to the AppBar.
  PatrolFinder get registrationsTitle => $(AppBar).$('Registrations');
}
