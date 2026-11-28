import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_error_view.dart';
import '../models/models.dart';
import '../providers/parent_provider.dart';

/// Screen displaying a child's attendance and quiz performance in a class (#633).
class ChildClassPerformanceScreen extends ConsumerStatefulWidget {
  final int childToken;
  final int classId;

  const ChildClassPerformanceScreen({
    super.key,
    required this.childToken,
    required this.classId,
  });

  @override
  ConsumerState<ChildClassPerformanceScreen> createState() =>
      _ChildClassPerformanceScreenState();
}

class _ChildClassPerformanceScreenState
    extends ConsumerState<ChildClassPerformanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ChildPerformanceFilter get _filter => ChildPerformanceFilter(
        childToken: widget.childToken,
        classId: widget.classId,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final performanceAsync = ref.watch(childPerformanceProvider(_filter));
    final attendanceAsync = ref.watch(childAttendanceHistoryProvider(_filter));
    final scoresAsync = ref.watch(childScoresProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Quiz Scores'),
          ],
        ),
      ),
      body: performanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () {
            ref.invalidate(childPerformanceProvider(_filter));
            ref.invalidate(childAttendanceHistoryProvider(_filter));
            ref.invalidate(childScoresProvider(_filter));
          },
        ),
        data: (performance) {
          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Attendance
              _buildAttendanceTab(theme, performance.attendance, attendanceAsync),
              // Tab 2: Quiz Scores
              _buildScoresTab(theme, performance.quizzes, scoresAsync),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttendanceTab(
    ThemeData theme,
    ChildAttendanceSummary summary,
    AsyncValue<List<ChildAttendanceHistory>> historyAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(childPerformanceProvider(_filter));
        ref.invalidate(childAttendanceHistoryProvider(_filter));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(
            theme: theme,
            title: 'Attendance Overview',
            icon: Icons.calendar_today,
            metrics: [
              _MetricItem(
                label: 'Attendance',
                value: summary.percentageFormatted,
                highlight: true,
              ),
              _MetricItem(
                label: 'Attended',
                value: summary.ratioFormatted,
              ),
              _MetricItem(
                label: 'Recitation',
                value: '${summary.totalRecitation} min',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Session History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          historyAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load session history.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            data: (history) {
              if (history.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No attendance records found.'),
                  ),
                );
              }
              return Column(
                children: history.map((session) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        session.present
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: session.present ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      title: Text(
                        session.date,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: session.recitation > 0
                          ? Text('Recitation: ${session.recitation} min')
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: session.present
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          session.present ? 'Present' : 'Absent',
                          style: TextStyle(
                            color: session.present ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScoresTab(
    ThemeData theme,
    ChildQuizSummary summary,
    AsyncValue<List<ChildScoreModel>> scoresAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(childPerformanceProvider(_filter));
        ref.invalidate(childScoresProvider(_filter));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(
            theme: theme,
            title: 'Quiz Overview',
            icon: Icons.quiz_outlined,
            metrics: [
              _MetricItem(
                label: 'Average Score',
                value: summary.averageFormatted,
                highlight: true,
              ),
              _MetricItem(
                label: 'Quizzes Attempted',
                value: '${summary.quizzesAttempted}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quiz Results',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          scoresAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load quiz scores.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            data: (scores) {
              if (scores.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No quiz records found.'),
                  ),
                );
              }
              return Column(
                children: scores.map((score) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        score.quizName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: score.attemptedOn.isNotEmpty
                          ? Text('Attempted: ${score.attemptedOn}')
                          : null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            score.percentageFormatted,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            score.scoreFormatted,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<_MetricItem> metrics,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: metrics.map((m) {
                return Column(
                  children: [
                    Text(
                      m.value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: m.highlight
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final bool highlight;

  const _MetricItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });
}
