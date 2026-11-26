import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/mcq_summary_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What the class screen needs from the list that opened it: the period and
/// gender the list answered for, and the class's name for the title.
class McqSummaryClassArgs {
  const McqSummaryClassArgs({
    required this.title,
    required this.gender,
    required this.from,
    required this.to,
  });

  final String title;
  final int gender;
  final String from;
  final String to;
}

/// The MCQ summary (#594), the mobile counterpart of the web's
/// mcq_summary_report.php: each class that published MCQs in a period, opening
/// on the last 30 days; a class opens its students. The server decides which
/// classes the user may see.
class McqSummaryScreen extends ConsumerStatefulWidget {
  const McqSummaryScreen({super.key});

  @override
  ConsumerState<McqSummaryScreen> createState() => _McqSummaryScreenState();
}

class _McqSummaryScreenState extends ConsumerState<McqSummaryScreen> {
  int? _gender;
  // The last 30 days, as the web page opens.
  late DateTime _to = DateTime.now();
  late DateTime _from = _to.subtract(const Duration(days: 30));
  String? _level;
  String _search = '';
  bool _sharing = false;

  /// The classes the list shows: the level and the search applied.
  List<McqSummaryClass> _inView(McqSummaryReport data) => [
    for (final c in data.classes)
      if ((_level == null || c.level == _level) &&
          matchesSearch(_search, [c.className, c.teacher]))
        c,
  ];

  /// Shares the classes in view with their students (CSV).
  Future<void> _shareAll(McqSummaryReport data) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareMcqSummaryAllProvider)(
        classIds: [for (final c in _inView(data)) c.classId],
        gender: data.gender,
        from: data.from,
        to: data.to,
      );
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 404) {
          AppSnackBar.showInfo(context, message: 'There is nothing to share.');
        } else {
          AppSnackBar.showError(
            context,
            message: 'The file could not be prepared. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  McqSummaryQuery get _query =>
      (gender: _gender, from: _date(_from), to: _date(_to));

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
    final report = ref.watch(mcqSummaryReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('MCQ summary'),
        actions: [
          if (capabilities.canReadReports &&
              report.asData != null &&
              _inView(report.asData!.value).isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: (_) => _shareAll(report.asData!.value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('Share all (CSV)')),
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
            hint: 'Search classes',
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
                      ref.invalidate(mcqSummaryReportProvider(_query)),
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

  List<Widget> _body(McqSummaryReport data) {
    if (data.classes.isEmpty) {
      return [const Text('No class published MCQs in this period.')];
    }
    final classes = _inView(data);

    return [
      if (data.levels.length > 1) ...[
        LevelFilter(
          levels: data.levels,
          selected: _level,
          onChanged: (level) => setState(() => _level = level),
        ),
        const SizedBox(height: 12),
      ],
      if (classes.isEmpty)
        Text(
          _search.trim().isEmpty
              ? 'No classes for this level.'
              : 'No classes match your search.',
        )
      else
        for (final c in classes)
          _ClassCard(
            summary: c,
            args: McqSummaryClassArgs(
              title: '${c.className} · ${c.level}',
              gender: data.gender,
              from: data.from,
              to: data.to,
            ),
          ),
    ];
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.summary, required this.args});

  final McqSummaryClass summary;
  final McqSummaryClassArgs args;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push(
          '${AppRoutes.adminMcqSummary}/${summary.classId}',
          extra: args,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                args.title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (summary.teacher.isNotEmpty)
                Text(summary.teacher, style: muted),
              const SizedBox(height: 8),
              Text('${summary.mcqs} MCQs · ${summary.students} students'),
            ],
          ),
        ),
      ),
    );
  }
}

/// One class's students over the period, with Share.
class McqSummaryClassScreen extends ConsumerStatefulWidget {
  const McqSummaryClassScreen({
    super.key,
    required this.classId,
    required this.args,
  });

  final int classId;
  final McqSummaryClassArgs args;

  @override
  ConsumerState<McqSummaryClassScreen> createState() =>
      _McqSummaryClassScreenState();
}

class _McqSummaryClassScreenState extends ConsumerState<McqSummaryClassScreen> {
  bool _sharing = false;

  McqSummaryClassQuery get _query => (
    classId: widget.classId,
    gender: widget.args.gender,
    from: widget.args.from,
    to: widget.args.to,
  );

  Future<void> _share(ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareMcqSummaryClassProvider)(_query, format);
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
    final detail = ref.watch(mcqSummaryClassProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.args.title),
        actions: [
          if (detail.asData case AsyncData(
            :final value,
          ) when value.students.isNotEmpty)
            PopupMenuButton<ReportFormat>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: _share,
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
        children: detail.when(
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            const Text('The students could not be loaded.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () =>
                    ref.invalidate(mcqSummaryClassProvider(_query)),
                child: const Text('Try again'),
              ),
            ),
          ],
          data: (d) => d.students.isEmpty
              ? [const Text('No students to show for this class.')]
              : [
                  Text(
                    '${widget.args.from} to ${widget.args.to} · ${d.mcqs} MCQs',
                  ),
                  const SizedBox(height: 12),
                  for (final s in d.students)
                    _StudentCard(
                      student: s,
                      mcqs: d.mcqs,
                      maxMarks: d.maxMarks,
                    ),
                ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.mcqs,
    required this.maxMarks,
  });

  final McqStudent student;
  final int mcqs;
  final int maxMarks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final percent = student.percent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student.name,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Attempted ${student.attempted} / $mcqs · '
              'Pending ${student.pending}',
            ),
            Text(
              percent == null
                  ? 'Score —'
                  : 'Score ${student.correct} / $maxMarks ($percent%)',
            ),
            for (final t in student.topics)
              Text(
                '${t.topic}: ${t.correct == null ? '—' : '${t.correct} / ${t.max}'}',
                style: muted,
              ),
          ],
        ),
      ),
    );
  }
}
