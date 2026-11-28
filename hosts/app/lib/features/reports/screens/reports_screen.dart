import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// One report the list offers.
class _ReportEntry {
  const _ReportEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    this.visibleTo,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  /// A report with a permission of its own (not just `reports:read`) says who
  /// may see it; null means everyone who reaches this screen.
  final bool Function(Capabilities capabilities)? visibleTo;
}

bool _canReadQuranLeaderboard(Capabilities capabilities) =>
    capabilities.canReadQuranLeaderboard;

bool _canReadRegistrations(Capabilities capabilities) =>
    capabilities.canReadRegistrations;

/// Every report the app has. A new report is one more entry here. All need
/// `reports:read`, which gets a member to this screen; each report's route
/// still checks it on the server.
const _reports = [
  _ReportEntry(
    title: 'Conduction Report',
    description: 'How each class did, week by week',
    icon: Icons.fact_check_outlined,
    color: Color(0xFF5C6BC0),
    route: AppRoutes.adminConductionReport,
  ),
  _ReportEntry(
    title: 'Weekly Report',
    description: 'Which classes met, week by week',
    icon: Icons.calendar_view_week_outlined,
    color: Color(0xFF26A69A),
    route: AppRoutes.adminWeeklyReport,
  ),
  _ReportEntry(
    title: 'Class Summary',
    description: 'How each class did over a period',
    icon: Icons.summarize_outlined,
    color: Color(0xFFAB47BC),
    route: AppRoutes.adminSummaryReport,
  ),
  _ReportEntry(
    title: 'Student Performance',
    description: 'Attendance, MCQs and recitation for each student',
    icon: Icons.school_outlined,
    color: Color(0xFFEF6C00),
    route: AppRoutes.adminStudentPerformance,
  ),
  _ReportEntry(
    title: 'TSR at a Glance',
    description: 'Conduction, MCQs, attendance and recitation by level',
    icon: Icons.dashboard_outlined,
    color: Color(0xFF00897B),
    route: AppRoutes.adminTsrReport,
  ),
  _ReportEntry(
    title: 'Pending Work',
    description: 'Class forms and MCQs still to do, by teacher',
    icon: Icons.pending_actions_outlined,
    color: Color(0xFFD84315),
    route: AppRoutes.adminPendingReport,
  ),
  _ReportEntry(
    title: 'Subject Conduction',
    description: 'The topic each class taught in each subject, week by week',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF5E35B1),
    route: AppRoutes.adminSubjectConduction,
  ),
  _ReportEntry(
    title: 'Class Sessions',
    description: 'Sessions recorded per class, and what the last one covered',
    icon: Icons.event_note_outlined,
    color: Color(0xFF00838F),
    route: AppRoutes.adminClassSessions,
  ),
  _ReportEntry(
    title: 'MCQ Summary',
    description: 'How each class\'s students did on its MCQs',
    icon: Icons.quiz_outlined,
    color: Color(0xFFC2185B),
    route: AppRoutes.adminMcqSummary,
  ),
  _ReportEntry(
    title: 'MCQ Adherence',
    description: 'How closely each class follows the standard MCQs',
    icon: Icons.rule_outlined,
    color: Color(0xFF6D4C41),
    route: AppRoutes.adminMcqAdherence,
  ),
  _ReportEntry(
    title: 'Active Teachers',
    description: 'Who is teaching, what they conduct and what they attend',
    icon: Icons.groups_outlined,
    color: Color(0xFF455A64),
    route: AppRoutes.adminActiveTeachers,
  ),
  _ReportEntry(
    title: 'Quran Leaderboard',
    description: 'Who recited the most, ranked over a period',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF2E7D32),
    route: AppRoutes.adminQuranLeaderboard,
    visibleTo: _canReadQuranLeaderboard,
  ),
  _ReportEntry(
    title: 'Registrations',
    description: 'Who registered and is waiting to be placed in a class',
    icon: Icons.how_to_reg_outlined,
    color: Color(0xFF00838F),
    route: AppRoutes.adminRegistrations,
    visibleTo: _canReadRegistrations,
  ),
];

/// The reports a member may read, with a search box (#576).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    final shown = [
      for (final r in _reports)
        if ((r.visibleTo?.call(capabilities) ?? true) &&
            matchesSearch(_search, [r.title, r.description]))
          r,
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          ReportSearchField(
            hint: 'Search reports',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Text('No reports match your search.')
          else
            for (final r in shown)
              Card(
                elevation: 0,
                color: AppTheme.lightGreen,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: r.color.withValues(alpha: 0.15),
                    child: Icon(r.icon, color: r.color),
                  ),
                  title: Text(r.title),
                  subtitle: Text(r.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(r.route),
                ),
              ),
        ],
      ),
    );
  }
}
