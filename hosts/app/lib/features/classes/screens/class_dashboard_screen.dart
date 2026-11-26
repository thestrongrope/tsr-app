import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_classes.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/class_notification_settings_sheet.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Main class dashboard screen with multi-class tab support
class ClassDashboardScreen extends ConsumerStatefulWidget {
  const ClassDashboardScreen({super.key});

  @override
  ConsumerState<ClassDashboardScreen> createState() =>
      _ClassDashboardScreenState();
}

class _ClassDashboardScreenState extends ConsumerState<ClassDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load classes on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(classesProvider.notifier).loadClasses();
    });
  }

  void _openClassRequestForm() {
    context.push('/class-registration');
  }

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Classes')),
      body: ContentWidthCap(child: _buildBody(classesState)),
    );
  }

  /// Pull-down: ask the server. If it cannot be reached the list stays as it
  /// was, and the member is told, rather than shown old classes as refreshed.
  Future<void> _pullToRefresh() async {
    await ref.read(classesProvider.notifier).refresh();
    if (!mounted || ref.read(classesProvider).error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not refresh. Showing the classes saved earlier.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildBody(ClassesState state) {
    if (state.isLoading && state.classes == null) {
      return ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SkeletonBox(height: 80),
          SizedBox(height: 12),
          SkeletonBox(height: 80),
          SizedBox(height: 12),
          SkeletonBox(height: 80),
        ],
      );
    }

    if (state.error != null && state.classes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load classes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(state.error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(classesProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!ref.watch(capabilitiesProvider).hasClassList(state.classes)) {
      return EmptyClassState(onRequestClass: _openClassRequestForm);
    }

    final classes = state.classes!;

    // Single class - show its dashboard directly.
    if (classes.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedClassIdProvider.notifier).state = classes.first.id;
      });
      return RefreshIndicator(
        onRefresh: _pullToRefresh,
        child: ClassDashboardContent(classModel: classes.first),
      );
    }

    // Multiple classes - grouped list (Attending / Conducting / Managing).
    return RefreshIndicator(
      onRefresh: _pullToRefresh,
      child: _ClassListBody(classes: classes),
    );
  }
}

/// Grouped class list: Attending first, then Conducting, then Managing, with a
/// search box above them. Tapping a class opens its dashboard.
///
/// Attending leads because it is what most members have; the staff groups
/// follow. A super admin can manage hundreds of classes, so the rows are built
/// lazily and the search narrows them as they type.
class _ClassListBody extends StatefulWidget {
  final List<ClassModel> classes;

  const _ClassListBody({required this.classes});

  @override
  State<_ClassListBody> createState() => _ClassListBodyState();
}

class _ClassListBodyState extends State<_ClassListBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Whether [c] matches what was typed: any word-part of its code, name,
  /// level, teacher, location, city, country or tags, ignoring case.
  bool _matches(ClassModel c) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      c.code,
      c.name,
      c.levelName,
      c.teacherName,
      c.location,
      c.city,
      c.country,
      ...c.tags,
    ].whereType<String>().any((field) => field.toLowerCase().contains(query));
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search classes...',
        hintStyle: TextStyle(color: AppTheme.lightText),
        prefixIcon: Icon(Icons.search, color: AppTheme.mediumText),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.clear, color: AppTheme.mediumText, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.classes.where(_matches).toList();
    final attending = shown.where((c) => c.isAttending).toList();
    final conducting = shown.where((c) => c.isConducting).toList();
    final managing = shown.where((c) => c.isManaging).toList();

    final items = <Widget>[
      _searchField(),
      const SizedBox(height: 16),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No classes match your search',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ..._section(
        classes: attending,
        title: 'Attending',
        subtitle: 'Classes you are enrolled in',
        icon: Icons.people_rounded,
        color: AppTheme.primaryGreen,
      ),
      ..._section(
        classes: conducting,
        title: 'Conducting',
        subtitle: 'Classes you teach',
        icon: Icons.school_rounded,
        color: AppTheme.accentGold,
      ),
      ..._section(
        classes: managing,
        title: 'Managing',
        subtitle: 'Classes you manage',
        icon: Icons.admin_panel_settings_rounded,
        color: AppTheme.secondaryGreen,
        before: _LevelTotals(classes: managing),
      ),
      const SizedBox(height: 32),
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// A header and its cards, or nothing when the group has no classes.
  List<Widget> _section({
    required List<ClassModel> classes,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? before,
  }) {
    if (classes.isEmpty) return const [];
    return [
      ?before,
      _ClassSectionHeader(
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
      ),
      const SizedBox(height: 12),
      for (final c in classes) _ClassCard(classModel: c),
      const SizedBox(height: 24),
    ];
  }
}

/// Classes and students per level, over the managed classes in view, so a
/// search recounts them. Students are the server's counts, as the web shows.
class _LevelTotals extends StatelessWidget {
  final List<ClassModel> classes;

  const _LevelTotals({required this.classes});

  @override
  Widget build(BuildContext context) {
    final byLevel = <int, List<ClassModel>>{};
    for (final c in classes) {
      byLevel.putIfAbsent(c.level, () => []).add(c);
    }
    final levels = byLevel.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final level in levels)
            Chip(
              label: Text(_totalLabel(byLevel[level]!)),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  String _totalLabel(List<ClassModel> inLevel) {
    final name = inLevel.first.levelName ?? 'Level ${inLevel.first.level}';
    final students = inLevel.fold<int>(
      0,
      (sum, c) => sum + (c.studentCount ?? 0),
    );
    return '$name: ${inLevel.length} ${inLevel.length == 1 ? 'class' : 'classes'}, '
        '$students ${students == 1 ? 'student' : 'students'}';
  }
}

class _ClassSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ClassSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassModel classModel;

  const _ClassCard({required this.classModel});

  @override
  Widget build(BuildContext context) {
    final isGents = classModel.isGents;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: classModel.isConducting
              ? AppTheme.accentGold.withValues(alpha: 0.4)
              : AppTheme.lightGreen,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/classes/${classModel.id}/dashboard');
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Class logo: the class code's initials on a gender-tinted
              // gradient, so each class reads as its own badge.
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isGents
                        ? [AppTheme.primaryGreen, AppTheme.secondaryGreen]
                        : [AppTheme.accentGold, const Color(0xFFB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Text(
                  _classInitials(classModel.code),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            classModel.levelName ?? 'Level ${classModel.level}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkText,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (classModel.code.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              classModel.code,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                            ),
                          ),
                        ],
                        if (classModel.isConducting) ...[
                          const SizedBox(width: 8),
                          const _ConductingBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      classModel.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        classModel.levelName ?? 'Level ${classModel.level}',
                        classModel.teacherName ?? 'No teacher assigned',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                    if (classModel.studentCount != null)
                      Text(
                        '${classModel.studentCount} '
                        '${classModel.studentCount == 1 ? 'student' : 'students'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                    if (classModel.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tag in classModel.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First two letters of a class code, used as the class logo initials.
String _classInitials(String code) {
  final letters = code.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length >= 2) return letters.substring(0, 2).toUpperCase();
  if (letters.isNotEmpty) return letters.toUpperCase();
  return code.isNotEmpty ? code.substring(0, 1).toUpperCase() : 'C';
}

class _ConductingBadge extends StatelessWidget {
  const _ConductingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_rounded, size: 12, color: Color(0xFFB8860B)),
          SizedBox(width: 3),
          Text(
            'Teaching',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB8860B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Content for a single class dashboard
class ClassDashboardContent extends ConsumerWidget {
  final ClassModel classModel;

  const ClassDashboardContent({super.key, required this.classModel});

  Color get _classColor =>
      classModel.isGents ? AppTheme.primaryGreen : AppTheme.accentGold;

  String? get _teacherDisplay {
    final name = classModel.teacherName?.trim();
    final mobile = classModel.teacherMobile?.trim();
    final hasName = name != null && name.isNotEmpty;
    final hasMobile = mobile != null && mobile.isNotEmpty;

    if (hasName && hasMobile) {
      return '$name ($mobile)';
    } else if (hasName) {
      return name;
    } else if (hasMobile) {
      return mobile;
    }
    return null;
  }

  double _normalizePercentage(double value) {
    if (value > 1.0) return value;
    return value * 100;
  }

  /// Where a card leads for this person, or null when they cannot edit the
  /// class. Editors (classes:update) open the manage screen on the card's own
  /// tab; the class's teacher and MCQ admin (classes:schedule) open only the
  /// schedule, from either card (#797).
  String? _editPath(WidgetRef ref, {required bool scheduleCard}) {
    final capabilities = ref.watch(capabilitiesProvider);
    if (capabilities.canUpdateClass(
      classModel.id,
      classGender: classModel.gender,
    )) {
      final manage = '/classes/${classModel.id}/manage';
      if (scheduleCard) return '$manage?tab=schedule';
      return manage;
    }
    if (capabilities.canEditSchedule(
      classModel.id,
      classGender: classModel.gender,
    )) {
      return '/classes/${classModel.id}/schedule';
    }
    return null;
  }

  VoidCallback? _openEditor(BuildContext context, String? path) {
    if (path == null) return null;
    return () => context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulePath = _editPath(ref, scheduleCard: true);
    final detailsPath = _editPath(ref, scheduleCard: false);
    // Performance is a student metric; skip the fetch entirely for staff (the
    // class teacher, or someone who manages the class), who have no
    // attendance/quiz rows here.
    final isStaff = classModel.isStaff;
    final performanceAsync = isStaff
        ? null
        : ref.watch(
            classPerformanceProvider(
              ClassPerformanceFilter(classId: classModel.id),
            ),
          );

    return SingleChildScrollView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Header Card
          ClassHeaderCard(
            classCode: classModel.code,
            className: classModel.levelName ?? 'Level ${classModel.level}',
            teacherName: classModel.teacherName,
            level: classModel.levelName,
            color: _classColor,
          ),

          const SizedBox(height: 24),

          // Quick Actions Section
          _SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 16),

          // Conduction quick action (teachers/admins only)
          _ConductionQuickAction(classModel: classModel),

          // MCQ management quick action (teachers/admins only)
          _McqManageQuickAction(classModel: classModel),

          // Class notification quick action (teachers/admins only)
          _ClassNotificationQuickAction(classModel: classModel),

          // Scheduled class events (teachers/admins only)
          _ClassEventsQuickAction(classModel: classModel),

          // Manage the class, or just look at its students (#402)
          _ManageClassQuickAction(classModel: classModel),

          // How each student is doing, for whoever manages the class's MCQs (#692)
          _StudentFiguresQuickAction(classModel: classModel),

          // Share the join link (class teacher only)
          _ShareJoinLinkQuickAction(classModel: classModel),

          Row(
            children: [
              // 'Take Quiz' is a student action — hidden for staff, who
              // manage quizzes instead.
              if (!isStaff) ...[
                Expanded(
                  child: _QuickActionCard(
                    title: 'Take Quiz',
                    subtitle: 'Practise a quiz',
                    icon: Icons.quiz_outlined,
                    iconColor: const Color(0xFF5C6BC0), // Indigo
                    backgroundColor: const Color(0xFFE8EAF6),
                    onTap: () {
                      context.push('/classes/${classModel.id}/quizzes');
                    },
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: _QuickActionCard(
                  title: 'Syllabus',
                  subtitle: 'Download PDFs',
                  icon: Icons.menu_book_outlined,
                  iconColor: const Color(0xFFFF7043), // Deep Orange
                  backgroundColor: const Color(0xFFFBE9E7),
                  onTap: () {
                    context.push(
                      '/classes/${classModel.id}/syllabus/${classModel.level}',
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: 'Guide',
                  subtitle: 'Read the level guide',
                  icon: Icons.auto_stories_outlined,
                  iconColor: const Color(0xFF26A69A), // Teal
                  backgroundColor: const Color(0xFFE0F2F1),
                  onTap: () {
                    context.push('/classes/${classModel.id}/guide');
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 20),

          // Performance Overview Section — student metric, hidden for staff
          // who have no attendance/quiz rows here.
          if (!isStaff) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(title: 'Performance Overview'),
                TextButton(
                  onPressed: () {
                    context.push('/classes/${classModel.id}/performance');
                  },
                  child: const Text('View all'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            performanceAsync!.when(
              data: (performance) {
                final attendanceVal = _normalizePercentage(
                  performance.attendancePercent,
                );
                final quizVal = _normalizePercentage(
                  performance.quizAverageScore,
                );

                return Row(
                  children: [
                    Expanded(
                      child: _PerformanceMetricCard(
                        title: 'Attendance',
                        value: '${attendanceVal.toInt()}%',
                        progress: attendanceVal / 100,
                        icon: Icons.check_circle_outline,
                        color: AppTheme.successGreen,
                        backgroundColor: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PerformanceMetricCard(
                        title: 'Quiz Average',
                        value: '${quizVal.toStringAsFixed(1)}%',
                        progress: quizVal / 100,
                        icon: Icons.bar_chart_outlined,
                        color: const Color(0xFFFF7043),
                        backgroundColor: const Color(0xFFFFF3E0),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SkeletonBox(height: 120),
              error: (error, _) => AppErrorView(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(
                  classPerformanceProvider(
                    ClassPerformanceFilter(classId: classModel.id),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],

          // Class Schedule Info
          InfoCard(
            title: 'Class Schedule',
            icon: Icons.schedule,
            items: _buildScheduleItems(),
            onTap: _openEditor(context, schedulePath),
            trailing: classModel.schedules.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                    tooltip: 'Reminder Settings',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      showClassNotificationSettings(
                        context,
                        ref,
                        hasConductingClasses: ref
                            .read(capabilitiesProvider)
                            .hasConductionReminders(
                              ref.read(classesProvider).classes,
                            ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 20),

          // Class Details Info
          InfoCard(
            title: 'Class Details',
            icon: Icons.info_outline,
            onTap: _openEditor(context, detailsPath),
            items: [
              InfoItem(label: 'Format', value: classModel.displayFormat),
              InfoItem(label: 'Location', value: classModel.displayLocation),
              if (classModel.teacherMobile != null)
                InfoItem(label: 'Teacher', value: classModel.teacherMobile!),
              if (_teacherDisplay != null)
                InfoItem(label: 'Teacher', value: _teacherDisplay!),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<InfoItem> _buildScheduleItems() {
    if (classModel.schedules.isEmpty) {
      return [const InfoItem(label: 'Schedule', value: 'Not set')];
    }

    return classModel.schedules.map((schedule) {
      return InfoItem(
        label: schedule.dayName,
        value: schedule.timeFormatted,
        icon: Icons.access_time,
      );
    }).toList();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius2XL),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.cardPaddingLarge),
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.radius2XL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final double progress;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _PerformanceMetricCard({
    required this.title,
    required this.value,
    required this.progress,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLarge),
      // Removed fixed height to avoid overflow, using dynamic layout
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Use min size
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 24, // Explicit size if needed or use theme
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0), // Ensure bounded
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}

/// A quick action card for class conduction, only shown to teachers/admins.
class _ConductionQuickAction extends ConsumerWidget {
  final ClassModel classModel;

  const _ConductionQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(capabilitiesProvider)
        .canRecordConduction(classModel.id, classGender: classModel.gender);
    if (!canManage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/classes/${classModel.id}/conduction');
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFF1565C0),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Conduction',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage attendance & session records',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quick action card for MCQ management, only shown to teachers/admins.
class _McqManageQuickAction extends ConsumerWidget {
  final ClassModel classModel;

  const _McqManageQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(capabilitiesProvider)
        .canManageMcqs(classModel.id, classGender: classModel.gender);
    if (!canManage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/classes/${classModel.id}/mcq/manage');
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.accentGold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: Color(0xFFB8860B),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MCQ Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create, publish & track class quizzes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quick action card for sending class notifications, shown to teachers/admins.
class _ClassNotificationQuickAction extends ConsumerWidget {
  final ClassModel classModel;

  const _ClassNotificationQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canNotify = ref
        .watch(capabilitiesProvider)
        .canSendNotification(classModel.id, classGender: classModel.gender);
    if (!canNotify) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/classes/${classModel.id}/notifications/send');
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: AppTheme.primaryGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Notification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Send push alerts to students of this class',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scheduled class events: the weekly reminders students keep on their phones.
class _ClassEventsQuickAction extends ConsumerWidget {
  final ClassModel classModel;

  const _ClassEventsQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(capabilitiesProvider)
        .canSendNotification(classModel.id, classGender: classModel.gender);
    if (!canManage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/classes/${classModel.id}/scheduled-events'),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.event_repeat,
                  color: AppTheme.primaryGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Events',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekly reminders students can keep on their phones',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Manage Class for whoever may edit the class (#402), and Class Students for
/// anyone who may see its students: editors land on the manage screen's
/// Students tab, a teacher who may only look gets the read-only roster.
class _ManageClassQuickAction extends ConsumerWidget {
  final ClassModel classModel;

  const _ManageClassQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitiesProvider);
    final canEdit = capabilities.canUpdateClass(
      classModel.id,
      classGender: classModel.gender,
    );
    final canReadStudents = capabilities.canReadStudents(
      classModel.id,
      classGender: classModel.gender,
    );
    if (!canEdit && !canReadStudents) {
      return const SizedBox.shrink();
    }

    final String studentsPath;
    if (canEdit) {
      studentsPath = '/classes/${classModel.id}/manage?tab=students';
    } else {
      studentsPath = '/classes/${classModel.id}/students';
    }

    return Column(
      children: [
        if (canEdit)
          _tile(
            context,
            title: 'Edit class',
            subtitle: 'Details, schedule and students',
            path: '/classes/${classModel.id}/manage',
            icon: Icons.edit_note_rounded,
          )
        else if (capabilities.canEditSchedule(
          classModel.id,
          classGender: classModel.gender,
        ))
          _tile(
            context,
            title: 'Edit class',
            subtitle: 'Set the day and time of your class',
            path: '/classes/${classModel.id}/schedule',
            icon: Icons.event_repeat_rounded,
          ),
        _tile(
          context,
          title: 'Class Students',
          subtitle: 'See who is in this class',
          path: studentsPath,
          icon: Icons.people_alt_rounded,
        ),
      ],
    );
  }

  static Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String path,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(path),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Student Performance for whoever may manage the class's MCQs (#692): each
/// current student's attendance, MCQ results and recitation over a range.
class _StudentFiguresQuickAction extends ConsumerWidget {
  final ClassModel classModel;

  const _StudentFiguresQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSee = ref
        .watch(capabilitiesProvider)
        .canManageMcqs(classModel.id, classGender: classModel.gender);
    if (!canSee) return const SizedBox.shrink();

    return _ManageClassQuickAction._tile(
      context,
      title: 'Student Performance',
      subtitle: 'Attendance, MCQs and recitation by student',
      path: '/classes/${classModel.id}/students/performance',
      icon: Icons.insights_rounded,
    );
  }
}

/// A quick action card for sharing the class join link. The server sends
/// `joinUrl` to the class teacher only, so no permission check is needed here.
class _ShareJoinLinkQuickAction extends StatelessWidget {
  final ClassModel classModel;

  const _ShareJoinLinkQuickAction({required this.classModel});

  @override
  Widget build(BuildContext context) {
    final joinUrl = classModel.joinUrl;
    if (joinUrl == null || joinUrl.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          SharePlus.instance.share(
            ShareParams(
              text:
                  'Join my class ${classModel.code} on The Strong Rope:\n'
                  '$joinUrl',
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  Icons.share_rounded,
                  color: AppTheme.primaryGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Join Link',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invite students to join this class',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
