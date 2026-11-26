import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/content_width_cap.dart';
import '../providers/providers.dart';
import '../services/conduction_queue_store.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen showing paginated conduction records for a class.
///
/// Accessible to teachers and class admins. Shows a list of past sessions
/// with a FAB to add new conduction records.
class ConductionListScreen extends ConsumerWidget {
  final int classId;

  const ConductionListScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(conductionSessionsProvider(classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Class Conduction')),
      body: ContentWidthCap(
        child: Column(
          children: [
            _UnsentRecords(classId: classId),
            Expanded(
              child: sessionsAsync.when(
                data: (data) =>
                    _ConductionListBody(classId: classId, data: data),
                loading: () => const ClassLoadingSkeleton(),
                error: (error, _) => AppErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(conductionSessionsProvider(classId)),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: TabBarFabLift(
        child: FloatingActionButton.extended(
          onPressed: () {
            context.push('/classes/$classId/conduction/add');
          },
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Record'),
        ),
      ),
    );
  }
}

/// Records saved on this device that the server has not accepted yet: waiting
/// to be sent, or refused with the reason and a way to retry or drop them.
class _UnsentRecords extends ConsumerWidget {
  const _UnsentRecords({required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsent = ref
        .watch(conductionQueueProvider)
        .where((i) => i.classId == classId)
        .toList();
    if (unsent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [for (final item in unsent) _UnsentRecordCard(item: item)],
      ),
    );
  }
}

class _UnsentRecordCard extends ConsumerWidget {
  const _UnsentRecordCard({required this.item});

  final QueuedConduction item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.read(conductionQueueProvider.notifier);
    final date = DateFormat(
      'EEE, d MMM y',
    ).format(DateTime.parse(item.conductedOn));
    final color = item.failed ? AppTheme.errorRed : AppTheme.warningOrange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.failed ? Icons.error_outline : Icons.schedule_send,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.failed ? '$date: not sent' : '$date: waiting to send',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (item.failed) ...[
              const SizedBox(height: 4),
              Text(item.error!, style: TextStyle(color: color)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  if (item.failed)
                    TextButton(
                      onPressed: () => queue.retry(item.key),
                      child: const Text('Try again'),
                    ),
                  TextButton(
                    onPressed: () => queue.discard(item.key),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConductionListBody extends StatelessWidget {
  final int classId;
  final ConductionListResponse data;

  const _ConductionListBody({required this.classId, required this.data});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger a refresh by invalidating the provider
        // This is handled by the parent Consumer
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class info header
            if (data.classInfo != null) _buildClassHeader(context),
            const SizedBox(height: 20),

            // Summary row
            _buildSummaryRow(context),
            const SizedBox(height: 20),

            // Sessions list
            if (data.sessions.isEmpty)
              _buildEmptyState(context)
            else
              ...data.sessions.map(
                (session) =>
                    _ConductionSessionCard(session: session, classId: classId),
              ),

            // Bottom spacing for FAB
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildClassHeader(BuildContext context) {
    final classInfo = data.classInfo!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classInfo.code,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  classInfo.levelName ?? 'Level ${classInfo.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (classInfo.teacherName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          classInfo.teacherName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${classInfo.totalStudents}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Students',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    final conducted = data.sessions.where((s) => s.conducted).length;
    final notConducted = data.sessions.where((s) => !s.conducted).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            label: 'Total',
            value: '${data.totalRecords}',
            icon: Icons.list_alt_rounded,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryChip(
            label: 'Conducted',
            value: '$conducted',
            icon: Icons.check_circle_rounded,
            color: AppTheme.successGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryChip(
            label: 'Missed',
            value: '$notConducted',
            icon: Icons.cancel_rounded,
            color: AppTheme.warningOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 48,
                color: AppTheme.primaryGreen.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No conduction records yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first record',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single conduction session card in the list.
class _ConductionSessionCard extends StatelessWidget {
  final ConductionSession session;
  final int classId;

  const _ConductionSessionCard({required this.session, required this.classId});

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat(
      'EEE, MMM d, yyyy',
    ).format(session.conductedOn);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: session.conducted
              ? AppTheme.successGreen.withValues(alpha: 0.15)
              : AppTheme.warningOrange.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          onTap: () {
            if (session.editable) {
              context.push('/classes/$classId/conduction/${session.id}/edit');
            } else {
              _showDetailSheet(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: date + status
                Row(
                  children: [
                    // Date
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: session.conducted
                                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                                  : AppTheme.warningOrange.withValues(
                                      alpha: 0.1,
                                    ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSM,
                              ),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: session.conducted
                                  ? AppTheme.successGreen
                                  : AppTheme.warningOrange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateFormatted,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: session.conducted
                            ? AppTheme.successGreen.withValues(alpha: 0.1)
                            : AppTheme.warningOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.conducted ? 'Conducted' : 'Not Conducted',
                        style: TextStyle(
                          color: session.conducted
                              ? AppTheme.successGreen
                              : AppTheme.warningOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                if (session.conducted) ...[
                  const Divider(height: 24),

                  // Details row
                  Row(
                    children: [
                      // Duration
                      _DetailItem(
                        icon: Icons.timer_outlined,
                        label: session.durationFormatted,
                      ),
                      const SizedBox(width: 16),

                      // Attendance
                      if (session.attendance != null)
                        _DetailItem(
                          icon: Icons.people_outline_rounded,
                          label: '${session.attendance} present',
                        ),
                    ],
                  ),

                  // Subjects covered
                  if (session.subjectTopics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: session.subjectTopics.map((topic) {
                        return Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 80,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            topic.topic != null && topic.topic!.isNotEmpty
                                ? '${topic.label}: ${topic.topic}'
                                : topic.label,
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ] else if (session.nonConductionReason != null &&
                    session.nonConductionReason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.nonConductionReason!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.mediumText,
                                fontStyle: FontStyle.italic,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Tap indicator
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      session.editable
                          ? Icons.edit_rounded
                          : Icons.visibility_rounded,
                      size: 14,
                      color: session.editable
                          ? AppTheme.primaryGreen.withValues(alpha: 0.6)
                          : AppTheme.mediumText.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.editable ? 'Tap to edit' : 'Tap for details',
                      style: TextStyle(
                        color: session.editable
                            ? AppTheme.primaryGreen.withValues(alpha: 0.6)
                            : AppTheme.mediumText.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ConductionDetailSheet(classId: classId, session: session),
    );
  }
}

/// Detailed bottom sheet showing session breakdown and student attendance + Quran recitation.
class _ConductionDetailSheet extends ConsumerStatefulWidget {
  final int classId;
  final ConductionSession session;

  const _ConductionDetailSheet({required this.classId, required this.session});

  @override
  ConsumerState<_ConductionDetailSheet> createState() =>
      _ConductionDetailSheetState();
}

class _ConductionDetailSheetState
    extends ConsumerState<_ConductionDetailSheet> {
  String _filter = 'all'; // 'all', 'present', 'absent'
  String _search = '';
  bool _showAttendance = true;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dateFormatted = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(session.conductedOn);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: withTabBarInset(
            context,
            const EdgeInsets.fromLTRB(20, 12, 20, 32),
          ),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: session.conducted
                        ? AppTheme.successGreen.withValues(alpha: 0.1)
                        : AppTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Icon(
                    session.conducted
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: session.conducted
                        ? AppTheme.successGreen
                        : AppTheme.warningOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.conducted
                            ? 'Class Conducted'
                            : 'Class Not Conducted',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormatted,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.editable)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(
                        '/classes/${widget.classId}/conduction/${session.id}/edit',
                      );
                    },
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),

            const Divider(height: 28),

            if (session.conducted) ...[
              // Summary cards: Duration, Attendance, Quran
              Row(
                children: [
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: session.durationFormatted,
                    ),
                  ),
                  if (session.attendance != null)
                    Expanded(
                      child: _DetailTile(
                        icon: Icons.people_outline_rounded,
                        label: 'Attendance',
                        value: '${session.attendance} students',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Quran recitation section of the class
              if (session.quranRecitationSurah != null) ...[
                _DetailTile(
                  icon: Icons.auto_stories_rounded,
                  label: 'Quran Class Lesson',
                  value: session.quranRecitationVerse != null
                      ? 'Surah #${session.quranRecitationSurah}, Ayah ${session.quranRecitationVerse}'
                      : 'Surah #${session.quranRecitationSurah}',
                ),
                const SizedBox(height: 12),
              ],

              // Subjects covered
              if (session.subjectTopics.isNotEmpty) ...[
                Text(
                  'Subjects Covered',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: session.subjectTopics.map((topic) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSM,
                              ),
                            ),
                            child: Text(
                              topic.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                topic.topic != null && topic.topic!.isNotEmpty
                                    ? topic.topic!
                                    : 'Topic covered',
                                style: TextStyle(
                                  color: AppTheme.darkText,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Student Attendance & Quran Recitation Section
              _buildAttendanceSection(context),
            ] else ...[
              // Non-conduction reason
              if (session.nonConductionReason != null &&
                  session.nonConductionReason!.isNotEmpty) ...[
                Text(
                  'Reason for Cancellation / Non-conduction',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: AppTheme.warningOrange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session.nonConductionReason!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.darkText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(BuildContext context) {
    final sessionDataAsync = ref.watch(
      conductionSessionProvider((
        classId: widget.classId,
        sessionId: widget.session.id,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with toggle
        InkWell(
          onTap: () => setState(() => _showAttendance = !_showAttendance),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Student Attendance & Recitation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showAttendance
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.mediumText,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (_showAttendance)
          sessionDataAsync.when(
            data: (editData) {
              final attendance = editData.attendance;
              if (attendance.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Center(
                    child: Text(
                      'No individual student attendance records found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ),
                );
              }

              final presentCount = attendance.where((s) => s.present).length;
              final absentCount = attendance.length - presentCount;

              // Filter list
              var filtered = attendance.where((s) {
                if (_filter == 'present') return s.present;
                if (_filter == 'absent') return !s.present;
                return true;
              }).toList();

              if (_search.isNotEmpty) {
                filtered = filtered
                    .where(
                      (s) =>
                          s.name.toLowerCase().contains(_search.toLowerCase()),
                    )
                    .toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips & Search
                  Row(
                    children: [
                      _FilterChip(
                        label: 'All (${attendance.length})',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Present ($presentCount)',
                        selected: _filter == 'present',
                        color: AppTheme.successGreen,
                        onTap: () => setState(() => _filter = 'present'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Absent ($absentCount)',
                        selected: _filter == 'absent',
                        color: AppTheme.errorRed,
                        onTap: () => setState(() => _filter = 'absent'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search input
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search student name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Student list
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No students match the filter',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.mediumText),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        return _StudentAttendanceCard(student: student);
                      },
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Text(
                'Could not load student attendance: ${userMessage(err)}',
                style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

/// Filter chip for attendance filtering.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primaryGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? activeColor : AppTheme.mediumText,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Card showing individual student attendance and Quran para recitation.
class _StudentAttendanceCard extends StatelessWidget {
  final ConductionStudent student;

  const _StudentAttendanceCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: student.present ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: student.present
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Avatar circle
          CircleAvatar(
            radius: 16,
            backgroundColor: student.present
                ? AppTheme.successGreen.withValues(alpha: 0.15)
                : Colors.grey.shade200,
            child: Icon(
              student.present
                  ? Icons.person_rounded
                  : Icons.person_off_outlined,
              size: 18,
              color: student.present
                  ? AppTheme.successGreen
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 12),

          // Student Name + Extra badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: student.present
                              ? AppTheme.darkText
                              : AppTheme.mediumText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (student.extra) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Extra',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF673AB7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  student.present ? 'Present' : 'Absent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: student.present
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                ),
              ],
            ),
          ),

          // Quran Recitation Badge
          if (student.present)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: student.recitation > 0
                    ? const Color(0xFFFFF8E1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(
                  color: student.recitation > 0
                      ? const Color(0xFFFFB300)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 14,
                    color: student.recitation > 0
                        ? const Color(0xFFE65100)
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    student.recitation > 0
                        ? 'Para ${student.recitation}'
                        : 'No Recitation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: student.recitation > 0
                          ? const Color(0xFFE65100)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            const Text('—', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Tile for detail bottom sheet.
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.mediumText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.mediumText),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mediumText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }
}
