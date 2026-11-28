import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/active_teachers_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The active teachers report (#598), the mobile counterpart of the web's
/// active_teachers_report.php: each teacher of the classes the user may see,
/// with what they conduct and what they attend. The server decides which
/// classes those are.
class ActiveTeachersScreen extends ConsumerStatefulWidget {
  const ActiveTeachersScreen({super.key});

  @override
  ConsumerState<ActiveTeachersScreen> createState() =>
      _ActiveTeachersScreenState();
}

class _ActiveTeachersScreenState extends ConsumerState<ActiveTeachersScreen> {
  int? _gender;
  String _search = '';
  bool _sharing = false;

  /// Shares the report on screen as a file.
  Future<void> _share(ActiveTeachersReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareActiveTeachersProvider)(data.gender, format);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'The file could not be prepared. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(activeTeachersReportProvider(_gender));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Active teachers'),
        actions: [
          if (report.asData case AsyncData(:final value))
            PopupMenuButton<ReportFormat>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: (format) => _share(value, format),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ReportFormat.xlsx,
                  child: Text('Share as Excel'),
                ),
                PopupMenuItem(
                  value: ReportFormat.pdf,
                  child: Text('Share as PDF'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          if (choosesGender) ...[
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Gents')),
                ButtonSegment(value: 2, label: Text('Ladies')),
              ],
              selected: {_gender ?? report.asData?.value.gender ?? 1},
              onSelectionChanged: (choice) =>
                  setState(() => _gender = choice.first),
            ),
            const SizedBox(height: 12),
          ],
          ReportSearchField(
            hint: 'Search by name, token or class',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 12),
          ...report.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The report could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(activeTeachersReportProvider(_gender)),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: _body,
          ),
        ],
      ),
    );
  }

  List<Widget> _body(ActiveTeachersReport data) {
    if (data.teachers.isEmpty) {
      return [const Text('There are no active teachers to show.')];
    }
    final teachers = [
      for (final t in data.teachers)
        if (matchesSearch(_search, [
          t.name,
          '${t.token}',
          t.conductingClasses,
          t.attendingClass,
          t.selfTeacher,
          t.maxLevel,
        ]))
          t,
    ];

    return [
      if (teachers.isEmpty)
        const Text('No teachers match your search.')
      else
        for (final t in teachers) _TeacherCard(teacher: t),
    ];
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher});

  final ActiveTeacher teacher;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teacher.name,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('Token ${teacher.token}', style: muted),
            const SizedBox(height: 8),
            Text(
              'Conducts ${teacher.totalClasses}: ${teacher.conductingClasses}',
            ),
            Text('Highest level ${teacher.maxLevel}', style: muted),
            if (teacher.attendingClass.isNotEmpty)
              Text(
                'Attends ${teacher.attendingClass}'
                '${teacher.selfTeacher.isEmpty ? '' : ' (${teacher.selfTeacher})'}',
                style: muted,
              ),
          ],
        ),
      ),
    );
  }
}
