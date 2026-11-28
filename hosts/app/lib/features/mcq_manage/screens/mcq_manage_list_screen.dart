import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_classes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../classes/providers/providers.dart';
import '../models/mcq_manage.dart';
import '../providers/mcq_manage_provider.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen for teachers/admins to manage a class's MCQs.
///
/// Mirrors the web app's `view_class_spot_quizzes.php`: lists all quizzes
/// (drafts, published, deactivated) with actions to edit, publish,
/// deactivate/reactivate, view scores, and copy to another class.
class McqManageListScreen extends ConsumerWidget {
  final int classId;

  const McqManageListScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(mcqManageListProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('MCQ Management'),
        actions: [
          IconButton(
            tooltip: 'Standard MCQs',
            onPressed: () {
              context.push('/classes/$classId/mcq/manage/standard');
            },
            icon: const Icon(Icons.library_books_rounded),
          ),
        ],
      ),
      body: quizzesAsync.when(
        data: (data) => _McqManageListBody(classId: classId, data: data),
        loading: () => const _McqManageSkeleton(),
        error: (error, _) => ListView(
          padding: withTabBarInset(
            context,
            const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spacing4XL,
              AppTheme.screenPadding,
              AppTheme.spacing3XL,
            ),
          ),
          children: [
            AppSurfaceCard(
              child: AppErrorView(
                error: error,
                onRetry: () => ref.invalidate(mcqManageListProvider(classId)),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: TabBarFabLift(
        child: FloatingActionButton.extended(
          onPressed: () {
            context.push('/classes/$classId/mcq/manage/standard');
          },
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New MCQ'),
        ),
      ),
    );
  }
}

class _McqManageListBody extends ConsumerWidget {
  final int classId;
  final McqManageListResponse data;

  const _McqManageListBody({required this.classId, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mcqManageListProvider(classId));
        await ref.read(mcqManageListProvider(classId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          if (data.items.isEmpty)
            _McqEmptyState(classId: classId)
          else
            ...data.items.map(
              (quiz) => _McqQuizCard(classId: classId, quiz: quiz),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Quizzes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.total} quiz${data.total == 1 ? '' : 'zes'} · '
                  'create, publish & track scores',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _McqQuizCard extends ConsumerWidget {
  final int classId;
  final McqManageQuiz quiz;

  const _McqQuizCard({required this.classId, required this.quiz});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Copying is its own permission, as on the web: managing the class is not
    // enough (#676).
    final classGender = ref
        .watch(classesProvider)
        .classes
        ?.where((c) => c.id == classId)
        .map((c) => c.gender)
        .firstOrNull;
    final capabilities = ref.watch(capabilitiesProvider);
    final canCopy = capabilities.canCopyMcqs(
      classId,
      classGender: classGender,
    );
    final canManage = capabilities.canManageMcqs(
      classId,
      classGender: classGender,
    );
    final link = quiz.link;
    final statusColor = quiz.isDeactivated
        ? AppTheme.mediumText
        : quiz.isPublished
        ? AppTheme.successGreen
        : AppTheme.warningOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkText,
                                ),
                          ),
                          if (quiz.topic != null &&
                              quiz.topic!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              quiz.topic!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.mediumText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(label: quiz.statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.help_outline_rounded,
                      label: '${quiz.questionCount} Qs',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.people_outline_rounded,
                      label: '${quiz.submittedCount} submitted',
                    ),
                    if (quiz.isOpenToAll) ...[
                      const SizedBox(width: 8),
                      const _StatChip(
                        icon: Icons.public_rounded,
                        label: 'Open to all',
                      ),
                    ],
                  ],
                ),
                if (quiz.publishedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Published ${DateFormat('d MMM yyyy').format(quiz.publishedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mediumText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: AppTheme.primaryGreen,
                  onTap: () {
                    context.push(
                      '/classes/$classId/mcq/manage/${quiz.id}/edit',
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.emoji_events_outlined,
                  label: 'Scores',
                  color: AppTheme.accentGold,
                  onTap: () {
                    context.push(
                      '/classes/$classId/mcq/manage/${quiz.id}/scores',
                    );
                  },
                ),
                if (quiz.isPublished)
                  _ActionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'Offline',
                    color: AppTheme.secondaryGreen,
                    onTap: () {
                      context.push(
                        '/classes/$classId/mcq/manage/${quiz.id}/offline',
                      );
                    },
                  ),
                if (link != null && canManage)
                  _ActionButton(
                    icon: Icons.link_rounded,
                    label: 'Copy link',
                    color: AppTheme.primaryGreen,
                    onTap: () => _copyLink(context, link),
                  ),
                if (canCopy)
                  _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    color: AppTheme.mediumText,
                    onTap: () {
                      context.push(
                        '/classes/$classId/mcq/manage/${quiz.id}/copy',
                      );
                    },
                  ),
                if (quiz.isPublished && !quiz.isDeactivated)
                  _ActionButton(
                    icon: Icons.block_rounded,
                    label: 'Deactivate',
                    color: AppTheme.errorRed,
                    onTap: () => _confirmDeactivate(context, ref),
                  )
                else if (!quiz.isPublished)
                  _ActionButton(
                    icon: Icons.send_rounded,
                    label: 'Publish',
                    color: AppTheme.successGreen,
                    onTap: () => _confirmPublish(context, ref),
                  )
                else
                  _ActionButton(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Activate',
                    color: AppTheme.successGreen,
                    onTap: () => _confirmActivate(context, ref),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPublish(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Quiz?'),
        content: Text(
          'Publishing "${quiz.name}" will notify all students in this class '
          'with a push notification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(mcqManageRepositoryProvider).publishQuiz(quiz.id);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: 'Quiz published & students notified',
      );
      ref.invalidate(mcqManageListProvider(classId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    }
  }

  /// Puts the MCQ's link on the clipboard. If that fails, says so and shows the
  /// link so it can be copied by hand (#864).
  Future<void> _copyLink(BuildContext context, String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link copied')));
      }
    } catch (_) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Could not copy the link'),
          content: SelectableText(link),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Quiz?'),
        content: Text(
          'Deactivating "${quiz.name}" will hide it from students. '
          'You can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(mcqManageRepositoryProvider)
          .setQuizDeactivated(quiz.id, deactivate: true);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, message: 'Quiz deactivated');
      ref.invalidate(mcqManageListProvider(classId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    }
  }

  Future<void> _confirmActivate(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(mcqManageRepositoryProvider)
          .setQuizDeactivated(quiz.id, deactivate: false);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, message: 'Quiz reactivated');
      ref.invalidate(mcqManageListProvider(classId));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing to show yet: one link to the Standard MCQs, where every new MCQ
/// starts.
class _McqEmptyState extends StatelessWidget {
  final int classId;

  const _McqEmptyState({required this.classId});

  @override
  Widget build(BuildContext context) {
    return AppEmptySection(
      icon: Icons.quiz_outlined,
      message:
          'No MCQs yet. If the Standard MCQs have none for your class, you '
          'can create a custom MCQ there.',
      actionLabel: 'Start from the Standard MCQs',
      onAction: () => context.push('/classes/$classId/mcq/manage/standard'),
    );
  }
}

class _McqManageSkeleton extends StatelessWidget {
  static const double _cardHeight = 150;

  const _McqManageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.screenPadding),
      ),
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingMD),
            child: SkeletonBox(height: _cardHeight, radius: AppTheme.radiusLG),
          ),
      ],
    );
  }
}
