import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/providers/permissions_provider.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The Manage tab: every admin tool the member may use, in labelled groups.
///
/// Presentation only: each tool keeps the permission check and the route it
/// always had. Tools the member may not use are not shown.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final capabilities = ref.watch(capabilitiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Manage')),
      body: Column(
        children: [
          const PermissionsStaleNotice(),
          Expanded(child: _body(ref, permissions, capabilities)),
        ],
      ),
    );
  }

  /// [permissions] only says whether an answer is loading or failed; what the
  /// member may use comes from [capabilities].
  Widget _body(
    WidgetRef ref,
    PermissionsState permissions,
    Capabilities capabilities,
  ) {
    final answered = capabilities.hasAnswer;

    if (!answered && permissions.error != null) {
      return _ScrollableState(
        child: AppSurfaceCard(
          child: AppErrorView(
            error: permissions.error!,
            onRetry: () =>
                ref.read(permissionsProvider.notifier).fetchAndSave(),
          ),
        ),
      );
    }

    if (!answered && permissions.isLoading) {
      return const _AdminHubSkeleton();
    }

    final groups = _visibleGroups(capabilities);
    if (!capabilities.showManageTab || groups.isEmpty) {
      return const _ScrollableState(
        child: AppEmptySection(
          icon: Icons.lock_outline_rounded,
          message:
              'No administrative modules available. You do not have access '
              'to any admin tools.',
        ),
      );
    }

    return _AdminHubBody(groups: groups);
  }
}

/// One admin tool: its label, what it does, and exactly where it goes.
class _AdminTool {
  const _AdminTool({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
}

/// A section of the hub: its heading and the member's tools inside it.
class _AdminGroup {
  const _AdminGroup({required this.title, required this.tools});

  final String title;
  final List<_AdminTool> tools;
}

/// The hub's groups, holding only the tools the member may use. Each tool is
/// gated by its own permission, read through [Capabilities].
List<_AdminGroup> _visibleGroups(Capabilities capabilities) {
  final groups = [
    _AdminGroup(
      title: 'Monitoring',
      tools: [
        if (capabilities.canReadReports)
          const _AdminTool(
            title: 'This week',
            description: 'Classes that need attention this week',
            icon: Icons.event_note_outlined,
            color: AppTheme.primaryGreen,
            route: AppRoutes.adminThisWeek,
          ),
        if (capabilities.canReadReports)
          const _AdminTool(
            title: 'Reports',
            description: 'Conduction, weekly and class summary',
            icon: Icons.fact_check_outlined,
            color: AppTheme.secondaryGreen,
            route: AppRoutes.adminReports,
          ),
        if (capabilities.canReadAuditLog)
          const _AdminTool(
            title: 'Access log',
            description: 'Who used the admin pages, and when',
            icon: Icons.history_outlined,
            color: AppTheme.accentGold,
            route: AppRoutes.adminAccessLog,
          ),
      ],
    ),
    _AdminGroup(
      title: 'Communication',
      tools: [
        if (capabilities.canBroadcast)
          const _AdminTool(
            title: 'Notifications',
            description: 'Send alerts & view history',
            icon: Icons.notifications_active_outlined,
            color: AppTheme.primaryGreen,
            route: '/admin/notifications',
          ),
        if (capabilities.canManageClassEvents)
          const _AdminTool(
            title: 'Class events',
            description: 'Create and manage scheduled events for a class',
            icon: Icons.event_repeat,
            color: AppTheme.secondaryGreen,
            route: AppRoutes.adminClassEvents,
          ),
        if (capabilities.canManageWhatsappReminders)
          const _AdminTool(
            title: 'WhatsApp Reminders',
            description: 'Who is reminded, when, and what was sent',
            icon: Icons.chat_outlined,
            color: AppTheme.successGreen,
            route: AppRoutes.adminWhatsappReminders,
          ),
        if (capabilities.canReviewFeedback)
          const _AdminTool(
            title: 'Feedback',
            description: 'Review submitted member feedback',
            icon: Icons.rate_review_outlined,
            color: AppTheme.primaryGreen,
            route: AppRoutes.adminFeedback,
          ),
      ],
    ),
    _AdminGroup(
      title: 'People',
      tools: [
        if (capabilities.canManageTeachers)
          const _AdminTool(
            title: 'Teachers',
            description: 'Who may conduct which level',
            icon: Icons.school_outlined,
            color: AppTheme.secondaryGreen,
            route: AppRoutes.adminTeachers,
          ),
        if (capabilities.canTransferStudents)
          const _AdminTool(
            title: 'Transfers & Promotions',
            description: 'Move students between classes in bulk',
            icon: Icons.swap_horiz_rounded,
            color: AppTheme.primaryGreen,
            route: AppRoutes.adminTransfers,
          ),
        if (capabilities.canReadDonors)
          const _AdminTool(
            title: 'Donors',
            description: 'Who donates, and the list as a file',
            icon: Icons.volunteer_activism_outlined,
            color: AppTheme.accentGold,
            route: AppRoutes.adminDonors,
          ),
      ],
    ),
    _AdminGroup(
      title: 'Content & quizzes',
      tools: [
        if (capabilities.canUpdateSyllabus)
          const _AdminTool(
            title: 'Syllabus Management',
            description: 'Manage class syllabus & PDFs',
            icon: Icons.menu_book_outlined,
            color: AppTheme.warningOrange,
            route: '/admin/syllabus',
          ),
        if (capabilities.canManageGuides)
          const _AdminTool(
            title: 'Guides',
            description: 'Edit the guide for each class level',
            icon: Icons.auto_stories_outlined,
            color: AppTheme.secondaryGreen,
            route: AppRoutes.adminGuides,
          ),
        if (capabilities.canUpdateStandardMcqs)
          const _AdminTool(
            title: 'Update MCQs',
            description: 'Replace the Standard MCQs from the source sheet',
            icon: Icons.quiz_outlined,
            color: AppTheme.warningOrange,
            route: AppRoutes.adminStandardMcqs,
          ),
        if (capabilities.canCopyMcqs)
          const _AdminTool(
            title: 'Copy MCQ',
            description: 'Copy a quiz from one class to another',
            icon: Icons.copy_all_outlined,
            color: AppTheme.warningOrange,
            route: AppRoutes.adminMcqCopy,
          ),
        if (capabilities.canAdminQuiz)
          const _AdminTool(
            title: 'Quiz admin',
            description: 'Run the Grand and Mega quizzes',
            icon: Icons.emoji_events_outlined,
            color: AppTheme.accentGold,
            route: AppRoutes.adminQuiz,
          ),
      ],
    ),
    _AdminGroup(
      title: 'Administration',
      tools: [
        if (capabilities.canManagePermissions)
          const _AdminTool(
            title: 'Access',
            description: 'Grant and revoke what a member can do',
            icon: Icons.admin_panel_settings_outlined,
            color: AppTheme.primaryGreen,
            route: AppRoutes.adminPermissions,
          ),
        if (capabilities.canManageClassAccess)
          const _AdminTool(
            title: 'Class admins',
            description: 'Choose the classes a member coordinates',
            icon: Icons.groups_outlined,
            color: AppTheme.primaryGreen,
            route: AppRoutes.adminClassAccess,
          ),
        if (capabilities.canEnrolByToken)
          const _AdminTool(
            title: 'Enrol by token',
            description: 'Look a member up and add them to a class',
            icon: Icons.person_add_alt_1_outlined,
            color: AppTheme.primaryGreen,
            route: AppRoutes.adminEnrolByToken,
          ),
        if (capabilities.canManageDeactivatedClasses)
          const _AdminTool(
            title: 'Deactivated Classes',
            description: 'Retire a class and see which have been',
            icon: Icons.archive_outlined,
            color: AppTheme.errorRed,
            route: AppRoutes.adminDeactivatedClasses,
          ),
        if (capabilities.canManageDeletionRequests)
          const _AdminTool(
            title: 'Deletion requests',
            description: 'Members who asked to delete their account',
            icon: Icons.person_remove_outlined,
            color: AppTheme.errorRed,
            route: AppRoutes.adminDeletionRequests,
          ),
      ],
    ),
  ];

  return groups.where((group) => group.tools.isNotEmpty).toList();
}

/// The member's groups, each a section header with its tools as tappable rows.
class _AdminHubBody extends StatelessWidget {
  const _AdminHubBody({required this.groups});

  final List<_AdminGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.screenPadding),
      ),
      children: [
        for (final group in groups) ...[
          AppSectionHeader(title: group.title),
          const SizedBox(height: AppTheme.spacingMD),
          for (final tool in group.tools)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
              child: _AdminToolRow(tool: tool),
            ),
          const SizedBox(height: AppTheme.spacingLG),
        ],
      ],
    );
  }
}

/// One tool: its tinted icon, name and purpose, and a chevron. The whole card
/// is the tap target.
class _AdminToolRow extends StatelessWidget {
  const _AdminToolRow({required this.tool});

  final _AdminTool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      onTap: () => context.push(tool.route),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: tool.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ExcludeSemantics(
              child: Icon(tool.icon, size: 24, color: tool.color),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  tool.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.mediumText,
          ),
        ],
      ),
    );
  }
}

/// A centred message that still scrolls, so it never overflows a short screen.
class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          AppTheme.spacing4XL,
          AppTheme.screenPadding,
          AppTheme.spacing3XL,
        ),
      ),
      children: [child],
    );
  }
}

class _AdminHubSkeleton extends StatelessWidget {
  static const double _rowHeight = 84;

  const _AdminHubSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.screenPadding),
      ),
      children: [
        for (var i = 0; i < 6; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingMD),
            child: SkeletonBox(height: _rowHeight, radius: AppTheme.radiusLG),
          ),
      ],
    );
  }
}
