import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/summary_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/month_range.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The class summary (#570), the mobile counterpart of the web's
/// class_reports_summary_*.php: each class rolled up over a period, opening on
/// the last three months. The server decides which classes the user may see.
class SummaryReportScreen extends ConsumerStatefulWidget {
  const SummaryReportScreen({super.key});

  @override
  ConsumerState<SummaryReportScreen> createState() =>
      _SummaryReportScreenState();
}

class _SummaryReportScreenState extends ConsumerState<SummaryReportScreen> {
  /// The current month and the 23 before it, newest first.
  late final List<String> _months = lastMonths(24);

  int? _gender;
  // Three months back to now, as the web page opens.
  late String _from = _months[3];
  late String _to = _months.first;
  String? _level;
  String _search = '';
  bool _sharing = false;

  SummaryQuery get _query => (gender: _gender, from: _from, to: _to);

  void _setFrom(String month) => setState(() {
    _from = month;
    if (monthKey(_to) < monthKey(month)) _to = month;
  });

  void _setTo(String month) => setState(() {
    _to = month;
    if (monthKey(_from) > monthKey(month)) _from = month;
  });

  /// Shares the period on screen, narrowed to the level chosen.
  Future<void> _share(SummaryReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareSummaryProvider)(
        (gender: data.gender, from: _from, to: _to),
        _level,
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

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(summaryReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Class summary'),
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
              }),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: MonthDropdown(
                  label: 'From',
                  value: _from,
                  months: _months,
                  onChanged: _setFrom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MonthDropdown(
                  label: 'To',
                  value: _to,
                  months: _months,
                  onChanged: _setTo,
                ),
              ),
            ],
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
                      ref.invalidate(summaryReportProvider(_query)),
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

  List<Widget> _body(SummaryReport data) {
    if (!data.hasSessions) {
      return [const Text('No sessions were recorded in this period.')];
    }
    final classes = [
      for (final c in data.classes)
        if ((_level == null || c.level == _level) &&
            matchesSearch(_search, [c.className, c.teacher]))
          c,
    ];

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
        for (final c in classes) _ClassCard(summary: c),
    ];
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.summary});

  final SummaryClass summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final subjects = summary.subjects;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.className} · ${summary.level}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (summary.teacher.isNotEmpty) Text(summary.teacher, style: muted),
            const SizedBox(height: 8),
            Text(
              'Conduction ${summary.percentConduction}% · '
              'Attendance ${summary.percentAttendance}%',
            ),
            Text(
              'Held ${summary.conducted} of ${summary.expected} · '
              '${summary.notFilled} not filled · '
              '${summary.notConducted} not held',
              style: muted,
            ),
            Text(
              'Avg ${summary.avgStudents} students · '
              '${summary.avgDuration} min',
              style: muted,
            ),
            if (subjects != null) ...[
              const SizedBox(height: 8),
              Text(
                'Arabic ${_figure(subjects.arabic)} · '
                'Aqaed ${_figure(subjects.aqaed)} · '
                'Ahkam ${_figure(subjects.ahkam)} · '
                'Akhlaq ${_figure(subjects.akhlaq)} · '
                'Other ${_figure(subjects.other)}',
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _figure(SubjectFigure f) => '${f.count} (${f.percent}%)';
}
