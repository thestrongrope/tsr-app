import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen showing detailed performance metrics for a class
class ClassPerformanceScreen extends ConsumerStatefulWidget {
  final int classId;

  const ClassPerformanceScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassPerformanceScreen> createState() =>
      _ClassPerformanceScreenState();
}

class _ClassPerformanceScreenState extends ConsumerState<ClassPerformanceScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _startDate;
  DateTime? _endDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onDateRangeSelected(DateTimeRange range) {
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ClassPerformanceFilter(
      classId: widget.classId,
      startDate: _startDate,
      endDate: _endDate,
    );
    final performanceAsync = ref.watch(classPerformanceProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classPerformanceProvider(filter));
          ref.invalidate(classAttendanceProvider(filter));
          ref.invalidate(classQuizHistoryProvider(filter));
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateRangeHeader(
                        startDate: _startDate,
                        endDate: _endDate,
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDateRange:
                                _startDate != null && _endDate != null
                                ? DateTimeRange(
                                    start: _startDate!,
                                    end: _endDate!,
                                  )
                                : null,
                          );
                          if (picked != null) {
                            _onDateRangeSelected(picked);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.insights,
                            color: AppTheme.primaryGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Overview',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      performanceAsync.when(
                        data: (performance) =>
                            _OverviewGrid(performance: performance),
                        loading: () => const SkeletonBox(height: 120),
                        error: (e, _) => AppErrorView(
                          error: e,
                          compact: true,
                          onRetry: () =>
                              ref.invalidate(classPerformanceProvider(filter)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: const [
                      Tab(text: 'Attendance'),
                      Tab(text: 'Quiz'),
                      Tab(text: 'Quran Para'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _AttendanceTab(filter: filter),
              _QuizTab(filter: filter),
              _ParaTab(filter: filter),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRangeHeader extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;

  const _DateRangeHeader({
    required this.startDate,
    required this.endDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final text = startDate != null && endDate != null
        ? '${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}'
        : 'Select Date Range';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date Range',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final ClassPerformance performance;

  const _OverviewGrid({required this.performance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _KpiItem(
                title: 'Attendance',
                value: '${performance.attendancePercent.round()}%',
                icon: Icons.calendar_today,
                color: Colors.green.shade600,
                lightColor: Colors.green.shade50,
              ),
            ),
            const VerticalDivider(width: 1, indent: 8, endIndent: 8),
            Expanded(
              child: _KpiItem(
                title: 'Quiz Avg',
                value: '${performance.quizAverageScore.round()}%',
                icon: Icons.quiz_outlined,
                color: Colors.orange.shade600,
                lightColor: Colors.orange.shade50,
              ),
            ),
            const VerticalDivider(width: 1, indent: 8, endIndent: 8),
            Expanded(
              child: _KpiItem(
                title: 'Classes',
                value: '${performance.attendedSessions}',
                icon: Icons.class_outlined,
                color: Colors.blue.shade600,
                lightColor: Colors.blue.shade50,
              ),
            ),
            const VerticalDivider(width: 1, indent: 8, endIndent: 8),
            Expanded(
              child: _KpiItem(
                title: 'Para',
                value: '${performance.totalRecitation}',
                icon: Icons.menu_book,
                color: Colors.purple.shade600,
                lightColor: Colors.purple.shade50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.lightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: lightColor, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AttendanceTab extends ConsumerWidget {
  final ClassPerformanceFilter filter;

  const _AttendanceTab({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(classAttendanceProvider(filter));

    return attendanceAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text("No attendance records found"));
        }
        return ListView.builder(
          padding: withTabBarInset(context, const EdgeInsets.all(16)),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            final dateStr = DateFormat('MMM d, yyyy').format(item.conductedOn);

            return _ActivityCard(
              title: dateStr,
              subtitle: '',
              status: item.present ? "Present" : "Absent",
              statusColor: item.present
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              icon: Icons.check_circle_outline,
              iconColor: item.present
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              iconColorInternal: item.present ? Colors.green : Colors.red,
              onTap: () {},
            );
          },
        );
      },
      loading: () => const ClassLoadingSkeleton(rows: 3),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(classAttendanceProvider(filter)),
      ),
    );
  }
}

class _QuizTab extends ConsumerWidget {
  final ClassPerformanceFilter filter;

  const _QuizTab({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(classQuizHistoryProvider(filter));

    return quizAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text("No quiz records found"));
        }
        return ListView.builder(
          padding: withTabBarInset(context, const EdgeInsets.all(16)),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return _ActivityCard(
              title: item.quizName,
              subtitle: "Marks: ${item.score}/${item.total}",
              status: "${item.percent.toStringAsFixed(0)}%",
              statusColor: item.percent >= 60
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              icon: Icons.assignment_outlined,
              iconColor: Colors.orange.shade50,
              iconColorInternal: Colors.orange,
              onTap: () {
                context.pushNamed(
                  'quizResult',
                  pathParameters: {'quizId': item.quizId.toString()},
                );
              },
            );
          },
        );
      },
      loading: () => const ClassLoadingSkeleton(rows: 3),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(classQuizHistoryProvider(filter)),
      ),
    );
  }
}

class _ParaTab extends ConsumerWidget {
  final ClassPerformanceFilter filter;

  const _ParaTab({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(classAttendanceProvider(filter));

    return attendanceAsync.when(
      data: (list) {
        final paraList = list.where((a) => a.recitation > 0).toList();

        if (paraList.isEmpty) {
          return const Center(child: Text("No recitation records found"));
        }
        return ListView.builder(
          padding: withTabBarInset(context, const EdgeInsets.all(16)),
          itemCount: paraList.length,
          itemBuilder: (context, index) {
            final item = paraList[index];
            final dateStr = DateFormat('MMM d, yyyy').format(item.conductedOn);

            return _ActivityCard(
              title: dateStr,
              subtitle: '',
              status: "${item.recitation} Para",
              statusColor: Colors.blue.shade700,
              icon: Icons.menu_book_outlined,
              iconColor: Colors.blue.shade50,
              iconColorInternal: Colors.blue,
              onTap: () {},
            );
          },
        );
      },
      loading: () => const ClassLoadingSkeleton(rows: 3),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(classAttendanceProvider(filter)),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final IconData icon;
  final Color iconColor;
  final Color iconColorInternal;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.iconColor,
    required this.iconColorInternal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColorInternal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
