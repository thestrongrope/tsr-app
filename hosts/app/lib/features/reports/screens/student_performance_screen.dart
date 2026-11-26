import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/student_performance.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// How the students are ordered.
enum StudentSort {
  tsrScore('TSR score'),
  attendance('Attendance'),
  mcqPerformance('MCQ performance'),
  recitation('Recitation'),
  name('Name');

  const StudentSort(this.label);

  final String label;
}

/// [students] in the order asked for: the best first, or A to Z for the name.
/// Ties fall back to name then token, so the order never shifts between loads
/// (the server leaves tied scores in no particular order).
List<StudentPerformance> sortStudents(
  List<StudentPerformance> students,
  StudentSort sort,
) {
  num figure(StudentPerformance s) => switch (sort) {
    StudentSort.tsrScore => s.tsrScore,
    StudentSort.attendance => s.attendance,
    StudentSort.mcqPerformance => s.mcqPerformance,
    StudentSort.recitation => s.recitation,
    StudentSort.name => 0,
  };

  return [...students]..sort((a, b) {
    final byFigure = figure(b).compareTo(figure(a));
    if (byFigure != 0) return byFigure;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.token.compareTo(b.token);
  });
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The student performance report (#578), the mobile counterpart of the web's
/// student_performance_report.php: how each student of the classes the user may
/// see is doing over a period. The server decides which students those are.
class StudentPerformanceScreen extends ConsumerStatefulWidget {
  const StudentPerformanceScreen({super.key});

  @override
  ConsumerState<StudentPerformanceScreen> createState() =>
      _StudentPerformanceScreenState();
}

class _StudentPerformanceScreenState
    extends ConsumerState<StudentPerformanceScreen> {
  int? _gender;
  // The last 30 days, as the web page opens.
  late DateTime _to = DateTime.now();
  late DateTime _from = _to.subtract(const Duration(days: 30));
  String? _level;
  String? _class;
  String _search = '';
  StudentSort _sort = StudentSort.tsrScore;
  bool _sharing = false;

  StudentsQuery get _query =>
      (gender: _gender, from: _date(_from), to: _date(_to));

  /// Shares the report on screen as a file.
  Future<void> _share(StudentsReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareStudentsProvider)(
        (gender: data.gender, from: _date(_from), to: _date(_to)),
        _level,
        _class,
        format,
      );
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

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2021, 11),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) return;
    setState(() {
      _from = range.start;
      _to = range.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(studentsReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Student performance'),
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
              onSelectionChanged: (choice) => setState(() {
                _gender = choice.first;
                _level = null;
                _class = null;
              }),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _pickDates,
            icon: const Icon(Icons.date_range),
            label: Text('${_date(_from)} to ${_date(_to)}'),
          ),
          const SizedBox(height: 12),
          ReportSearchField(
            hint: 'Search by token, name or class',
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
                      ref.invalidate(studentsReportProvider(_query)),
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

  List<Widget> _body(StudentsReport data) {
    if (data.students.isEmpty) {
      return [const Text('No students were found in this period.')];
    }
    final classes = [
      for (final c in data.classes)
        if (_level == null || c.level == _level) c,
    ];
    final students = sortStudents([
      for (final s in data.students)
        if ((_level == null || s.level == _level) &&
            (_class == null || s.className == _class) &&
            matchesSearch(_search, [s.token, s.name, s.className]))
          s,
    ], _sort);

    return [
      if (data.levels.length > 1) ...[
        LevelFilter(
          levels: data.levels,
          selected: _level,
          onChanged: (level) => setState(() {
            _level = level;
            _class = null;
          }),
        ),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _class,
              key: ValueKey('class-$_level-$_class'),
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final c in classes)
                  DropdownMenuItem(
                    value: c.className,
                    child: Text(c.className),
                  ),
              ],
              onChanged: (value) => setState(() => _class = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<StudentSort>(
              initialValue: _sort,
              decoration: const InputDecoration(labelText: 'Order by'),
              items: [
                for (final s in StudentSort.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sort = value);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (students.isEmpty)
        Text(
          _search.trim().isEmpty
              ? 'No students for this selection.'
              : 'No students match your search.',
        )
      else
        for (final s in students) _StudentCard(student: s),
    ];
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});

  final StudentPerformance student;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '#${student.token} · ${student.className} · ${student.level}',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Attendance ${student.attendance}% · '
                    '${student.sessions} sessions',
                  ),
                  Text(
                    'MCQs ${student.mcqAttempted}% attempted of '
                    '${student.totalMcqs} · ${student.mcqPerformance}% correct',
                    style: muted,
                  ),
                  Text(
                    'Recitation ${student.recitation} · '
                    '${student.recitationAvg.toStringAsFixed(2)} per session',
                    style: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  '${student.tsrScore}%',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('TSR score', style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
