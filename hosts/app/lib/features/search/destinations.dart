import '../../core/constants/app_constants.dart';
import '../../core/permissions/capabilities.dart';
import '../../core/permissions/capabilities_classes.dart';
import '../../core/permissions/capabilities_manage.dart';
import '../../core/router/route_config.dart';
import 'models/search_result.dart';

/// A place in the app that search can open (#557): a screen in Manage, a
/// report or a screen the Me tab lists. It is data, not records, so it needs no server: the app lists its own
/// destinations and keeps those the person may open, each gated by the same
/// [Capabilities] fact the Manage tab and the reports list use.
class SearchDestination {
  const SearchDestination({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.allowed,
    this.signedInOnly = false,
    this.keywords = const [],
  });

  final String title;

  /// `Manage`, `Report` or `Me`, so two similar names can be told apart.
  final String subtitle;

  /// A route in the app, or an `https://` address for a page outside it.
  final String route;
  final bool Function(Capabilities) allowed;

  /// The member's own screen, which a guest has nothing to see on.
  final bool signedInOnly;
  final List<String> keywords;
}

bool _reports(Capabilities c) => c.canReadReports;

/// A Me screen with no permission of its own.
bool _everyone(Capabilities c) => true;

/// Screens governed by token lists rather than permissions (the quiz admins,
/// the MCQ team) are left out: they cannot be filtered this way.
final List<SearchDestination> searchDestinations = [
  SearchDestination(
    title: 'Notifications',
    subtitle: 'Manage',
    route: AppRoutes.adminNotifications,
    allowed: (c) => c.canBroadcast,
    keywords: const ['send', 'alert', 'push', 'broadcast'],
  ),
  SearchDestination(
    title: 'Syllabus Management',
    subtitle: 'Manage',
    route: AppRoutes.adminSyllabus,
    allowed: (c) => c.canUpdateSyllabus,
    keywords: const ['syllabus', 'pdf'],
  ),
  SearchDestination(
    title: 'Reports',
    subtitle: 'Manage',
    route: AppRoutes.adminReports,
    allowed: _reports,
    keywords: const ['report'],
  ),
  SearchDestination(
    title: 'Deactivated Classes',
    subtitle: 'Manage',
    route: AppRoutes.adminDeactivatedClasses,
    allowed: (c) => c.canManageDeactivatedClasses,
    keywords: const ['retire', 'closed', 'archive'],
  ),
  SearchDestination(
    title: 'Transfers & Promotions',
    subtitle: 'Manage',
    route: AppRoutes.adminTransfers,
    allowed: (c) => c.canTransferStudents,
    keywords: const ['transfer', 'promote', 'move'],
  ),
  SearchDestination(
    title: 'Teachers',
    subtitle: 'Manage',
    route: AppRoutes.adminTeachers,
    allowed: (c) => c.canManageTeachers,
    keywords: const ['training', 'trained'],
  ),
  SearchDestination(
    title: 'WhatsApp Reminders',
    subtitle: 'Manage',
    route: AppRoutes.adminWhatsappReminders,
    allowed: (c) => c.canManageWhatsappReminders,
    keywords: const ['remind', 'message'],
  ),
  SearchDestination(
    title: 'Donors',
    subtitle: 'Manage',
    route: AppRoutes.adminDonors,
    allowed: (c) => c.canReadDonors,
    keywords: const ['donations', 'donation', 'donate'],
  ),
  SearchDestination(
    title: 'Deletion requests',
    subtitle: 'Manage',
    route: AppRoutes.adminDeletionRequests,
    allowed: (c) => c.canManageDeletionRequests,
    keywords: const ['account', 'delete', 'privacy'],
  ),
  SearchDestination(
    title: 'Guides',
    subtitle: 'Manage',
    route: AppRoutes.adminGuides,
    allowed: (c) => c.canManageGuides,
    keywords: const ['edit guide', 'author'],
  ),
  SearchDestination(
    title: 'Access log',
    subtitle: 'Manage',
    route: AppRoutes.adminAccessLog,
    allowed: (c) => c.canReadAuditLog,
    keywords: const ['audit', 'admin activity'],
  ),
  SearchDestination(
    title: 'Access',
    subtitle: 'Manage',
    route: AppRoutes.adminPermissions,
    allowed: (c) => c.canManagePermissions,
    keywords: const ['permissions', 'grant', 'roles'],
  ),
  SearchDestination(
    title: 'Conduction Report',
    subtitle: 'Report',
    route: AppRoutes.adminConductionReport,
    allowed: _reports,
    keywords: const ['weekly conduction', 'classes met'],
  ),
  SearchDestination(
    title: 'Weekly Report',
    subtitle: 'Report',
    route: AppRoutes.adminWeeklyReport,
    allowed: _reports,
    keywords: const ['week by week'],
  ),
  SearchDestination(
    title: 'Class Summary',
    subtitle: 'Report',
    route: AppRoutes.adminSummaryReport,
    allowed: _reports,
    keywords: const ['summary'],
  ),
  SearchDestination(
    title: 'Student Performance',
    subtitle: 'Report',
    route: AppRoutes.adminStudentPerformance,
    allowed: _reports,
    keywords: const ['attendance', 'students'],
  ),
  SearchDestination(
    title: 'TSR at a Glance',
    subtitle: 'Report',
    route: AppRoutes.adminTsrReport,
    allowed: _reports,
    keywords: const ['overview', 'by level'],
  ),
  SearchDestination(
    title: 'Pending Work',
    subtitle: 'Report',
    route: AppRoutes.adminPendingReport,
    allowed: _reports,
    keywords: const ['forms', 'c-form', 'not filled', 'mcqs'],
  ),
  SearchDestination(
    title: 'Subject Conduction',
    subtitle: 'Report',
    route: AppRoutes.adminSubjectConduction,
    allowed: _reports,
    keywords: const ['topics', 'subjects'],
  ),
  SearchDestination(
    title: 'Class Sessions',
    subtitle: 'Report',
    route: AppRoutes.adminClassSessions,
    allowed: _reports,
    keywords: const ['sessions recorded'],
  ),
  SearchDestination(
    title: 'MCQ Summary',
    subtitle: 'Report',
    route: AppRoutes.adminMcqSummary,
    allowed: _reports,
    keywords: const ['quiz'],
  ),
  SearchDestination(
    title: 'MCQ Adherence',
    subtitle: 'Report',
    route: AppRoutes.adminMcqAdherence,
    allowed: _reports,
    keywords: const ['standard mcqs'],
  ),
  SearchDestination(
    title: 'Active Teachers',
    subtitle: 'Report',
    route: AppRoutes.adminActiveTeachers,
    allowed: _reports,
    keywords: const ['who is teaching'],
  ),
  SearchDestination(
    title: 'Quran Leaderboard',
    subtitle: 'Report',
    route: AppRoutes.adminQuranLeaderboard,
    allowed: (c) => c.canReadQuranLeaderboard,
    keywords: const ['recitation', 'ranked'],
  ),
  SearchDestination(
    title: 'Registrations',
    subtitle: 'Report',
    route: AppRoutes.adminRegistrations,
    allowed: (c) => c.canReadRegistrations,
    keywords: const ['waiting', 'place', 'registered'],
  ),
  SearchDestination(
    title: 'Profile',
    subtitle: 'Me',
    route: AppRoutes.profile,
    allowed: _everyone,
    signedInOnly: true,
    keywords: const ['my details', 'account', 'token'],
  ),
  SearchDestination(
    title: 'My Children',
    subtitle: 'Me',
    route: AppRoutes.myChildren,
    allowed: _everyone,
    signedInOnly: true,
    keywords: const ['child', 'kids', 'parent'],
  ),
  SearchDestination(
    title: 'My Parents',
    subtitle: 'Me',
    route: AppRoutes.myParents,
    allowed: (c) => c.canManageOwnParents,
    signedInOnly: true,
    keywords: const ['parent', 'father', 'mother'],
  ),
  SearchDestination(
    title: 'Notifications',
    subtitle: 'Me',
    route: AppRoutes.notifications,
    allowed: _everyone,
    signedInOnly: true,
    keywords: const ['inbox', 'alerts', 'messages'],
  ),
  SearchDestination(
    title: 'About',
    subtitle: 'Me',
    route: AppRoutes.about,
    allowed: _everyone,
    keywords: const ['the strong rope', 'tsr'],
  ),
  SearchDestination(
    title: 'Accreditation',
    subtitle: 'Me',
    route: AppRoutes.accreditation,
    allowed: _everyone,
    keywords: const ['certificate', 'recognition'],
  ),
  SearchDestination(
    title: 'Contact',
    subtitle: 'Me',
    route: AppRoutes.contact,
    allowed: _everyone,
    keywords: const ['email', 'whatsapp', 'reach us', 'help'],
  ),
  SearchDestination(
    title: 'Send feedback',
    subtitle: 'Me',
    route: AppRoutes.sendFeedback,
    allowed: _everyone,
    signedInOnly: true,
    keywords: const ['suggestion', 'bug', 'problem', 'report an issue'],
  ),
  SearchDestination(
    title: 'Donate',
    subtitle: 'Me',
    route: AppConstants.donateUrl,
    allowed: _everyone,
    keywords: const ['donation', 'contribution', 'contribute', 'support'],
  ),
];

/// The destinations the person may open whose title or a keyword contains
/// [query] (at least two letters, any case). Nothing before the server has
/// answered, and a guest is not offered a member's own screens.
List<SearchResult> matchDestinations(
  String query,
  Capabilities capabilities, {
  required bool signedIn,
}) {
  final needle = query.trim().toLowerCase();
  if (!capabilities.hasAnswer || needle.length < 2) return const [];
  return [
    for (final d in searchDestinations)
      if (d.allowed(capabilities) &&
          (signedIn || !d.signedInOnly) &&
          (d.title.toLowerCase().contains(needle) ||
              d.keywords.any((k) => k.toLowerCase().contains(needle))))
        SearchResult(
          kind: SearchKind.destination,
          id: 0,
          title: d.title,
          subtitle: d.subtitle,
          target: d.route,
        ),
  ];
}
