import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';

import '../models/class_student_figures.dart';
import '../providers/class_student_figures_provider.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// A class's students with their attendance, MCQ results and recitation over a
/// range (#692), for whoever may manage the class's MCQs: the mobile
/// counterpart of the web's Class Students page. One range at the top serves
/// all three views, so switching view keeps it.
class ClassStudentFiguresScreen extends ConsumerStatefulWidget {
  final int classId;

  const ClassStudentFiguresScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassStudentFiguresScreen> createState() =>
      _ClassStudentFiguresScreenState();
}

class _ClassStudentFiguresScreenState
    extends ConsumerState<ClassStudentFiguresScreen> {
  /// What the user picked; null until then, and the server uses the last year.
  DateTimeRange? _range;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The app-wide date style, e.g. Oct 18, 2026.
  static String _shown(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  StudentFiguresRequest get _request => (
    classId: widget.classId,
    from: _range == null ? null : _date(_range!.start),
    to: _range == null ? null : _date(_range!.end),
  );

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: now,
      initialDateRange:
          _range ??
          DateTimeRange(
            start: DateTime(now.year - 1, now.month, now.day),
            end: now,
          ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final figures = ref.watch(classStudentFiguresProvider(_request));
    final label = figures.maybeWhen(
      data: (f) =>
          '${_shown(DateTime.parse(f.from))}  to  ${_shown(DateTime.parse(f.to))}',
      orElse: () => _range == null
          ? 'Last year'
          : '${_shown(_range!.start)}  to  ${_shown(_range!.end)}',
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student performance'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'MCQ'),
              Tab(text: 'Recitation'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('studentFiguresRange'),
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(label),
                ),
              ),
            ),
            Expanded(
              child: figures.when(
                loading: () => const ClassLoadingSkeleton(),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () =>
                      ref.invalidate(classStudentFiguresProvider(_request)),
                ),
                data: (f) {
                  if (f.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          f.students.isEmpty
                              ? 'No students in this class.'
                              : 'No attendance, MCQs or recitation in this range.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return TabBarView(
                    children: [
                      _AttendanceTable(figures: f),
                      _McqTable(figures: f),
                      _RecitationTable(figures: f),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A table whose first column (the name) stays in view while the other
/// columns scroll sideways, so a wide table never loses who a row is about.
class _FiguresTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _FiguresTable({required this.headers, required this.rows});

  static const double _nameWidth = 120;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: withTabBarInset(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DataTable(
            key: const Key('figuresNameColumn'),
            columnSpacing: AppTheme.spacingMD,
            columns: [DataColumn(label: Text(headers.first))],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: MediaQuery.textScalerOf(
                          context,
                        ).scale(_nameWidth),
                        child: Text(
                          row.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('figuresScrollingColumns'),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: [
                  for (final header in headers.skip(1))
                    DataColumn(label: Text(header), numeric: true),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        for (final cell in row.skip(1)) DataCell(Text(cell)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  final ClassStudentFigures figures;

  const _AttendanceTable({required this.figures});

  @override
  Widget build(BuildContext context) {
    return _FiguresTable(
      headers: const ['Name', 'Expected', 'Present', 'Attendance'],
      rows: [
        for (final s in figures.students)
          [s.name, '${s.expected}', '${s.present}', '${s.attendance}%'],
      ],
    );
  }
}

class _RecitationTable extends StatelessWidget {
  final ClassStudentFigures figures;

  const _RecitationTable({required this.figures});

  @override
  Widget build(BuildContext context) {
    return _FiguresTable(
      headers: const ['Name', 'Recitation'],
      rows: [
        for (final s in figures.students) [s.name, '${s.recitation}'],
      ],
    );
  }
}

/// Attempted, overall and each topic, as `obtained / max` or as percentages.
class _McqTable extends StatefulWidget {
  final ClassStudentFigures figures;

  const _McqTable({required this.figures});

  @override
  State<_McqTable> createState() => _McqTableState();
}

class _McqTableState extends State<_McqTable> {
  bool _percent = false;

  String _cell(int obtained, int max) =>
      _percent ? '${figurePercent(obtained, max)}%' : '$obtained / $max';

  @override
  Widget build(BuildContext context) {
    final f = widget.figures;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Absolute')),
              ButtonSegment(value: true, label: Text('%')),
            ],
            selected: {_percent},
            onSelectionChanged: (s) => setState(() => _percent = s.first),
          ),
        ),
        Expanded(
          child: _FiguresTable(
            headers: [
              'Name',
              'Attempted',
              'Overall',
              for (final t in f.topics) t.name,
            ],
            rows: [
              for (final s in f.students)
                [
                  s.name,
                  _cell(s.mcqAttempted, f.totalMcqs),
                  _cell(s.mcqCorrect, f.maxTotal),
                  for (final t in f.topics)
                    _cell(s.topicCorrect[t.name] ?? 0, t.max),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
