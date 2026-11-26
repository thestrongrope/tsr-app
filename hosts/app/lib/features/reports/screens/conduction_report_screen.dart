import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/conduction_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// What the share menu offers: the week on screen as a file, or every week's
/// detail rows (#679).
enum ConductionShare { excel, pdf, allWeeks }

/// The conduction report (#568), the mobile counterpart of the web's
/// class_reports_conduction.php: how each class did in a chosen week, and over
/// the weeks before it. The server decides which classes the user may see.
class ConductionReportScreen extends ConsumerStatefulWidget {
  const ConductionReportScreen({super.key});

  @override
  ConsumerState<ConductionReportScreen> createState() =>
      _ConductionReportScreenState();
}

class _ConductionReportScreenState
    extends ConsumerState<ConductionReportScreen> {
  // Null year and week ask for the last completed week.
  int? _gender;
  int? _year;
  int? _week;
  String? _level;
  String _search = '';
  bool _sharing = false;

  ConductionQuery get _query =>
      (gender: _gender, year: _year, week: _week, level: null);

  /// Shares the file for the week on screen, narrowed to the level chosen.
  Future<void> _share(ConductionReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareConductionProvider)((
        gender: data.gender,
        year: data.year,
        week: data.week,
        level: _level,
      ), format);
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

  /// Shares every week's detail rows (CSV), whatever level is chosen.
  Future<void> _shareAllWeeks(ConductionReport data) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareConductionAllWeeksProvider)((
        gender: data.gender,
        year: data.year,
        week: data.week,
        level: null,
      ));
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 404) {
          AppSnackBar.showInfo(
            context,
            message: 'There is no data to share yet.',
          );
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

  void _goTo(WeekRef week) {
    setState(() {
      _year = week.year;
      _week = week.week;
    });
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(conductionReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Conduction report'),
        actions: [
          if (report.asData case AsyncData(:final value))
            PopupMenuButton<ConductionShare>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: (choice) => switch (choice) {
                ConductionShare.excel => _share(value, ReportFormat.xlsx),
                ConductionShare.pdf => _share(value, ReportFormat.pdf),
                ConductionShare.allWeeks => _shareAllWeeks(value),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ConductionShare.excel,
                  child: Text('Share as Excel'),
                ),
                PopupMenuItem(
                  value: ConductionShare.pdf,
                  child: Text('Share as PDF'),
                ),
                PopupMenuItem(
                  value: ConductionShare.allWeeks,
                  child: Text('Share all weeks (CSV)'),
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
                      ref.invalidate(conductionReportProvider(_query)),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: (data) => _body(data),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(ConductionReport data) {
    final previous = data.previous;
    final next = data.next;
    final classes = [
      for (final c in data.classes)
        if ((_level == null || c.level == _level) &&
            matchesSearch(_search, [c.className, c.teacher]))
          c,
    ];
    final weekRows = [
      for (final r in data.lastWeek)
        if ((_level == null || r.level == _level) &&
            matchesSearch(_search, [r.className, r.teacher]))
          r,
    ];

    return [
      _WeekPicker(
        label: 'Week ${data.week}',
        range: data.weekOf,
        onPrevious: previous == null ? null : () => _goTo(previous),
        onNext: next == null ? null : () => _goTo(next),
      ),
      const SizedBox(height: 12),
      if (data.levels.length > 1) ...[
        LevelFilter(
          levels: data.levels,
          selected: _level,
          onChanged: (level) => setState(() => _level = level),
        ),
        const SizedBox(height: 12),
      ],
      _Heading('This week'),
      if (weekRows.isEmpty)
        Text(
          _search.trim().isEmpty
              ? 'No classes were expected to meet this week.'
              : 'No classes match your search.',
        )
      else
        for (final row in weekRows) _WeekRowCard(row: row),
      const SizedBox(height: 16),
      _Heading(
        data.summaryStart.isEmpty
            ? 'Overall'
            : 'Overall, ${data.summaryStart} to ${data.summaryEnd}',
      ),
      if (classes.isEmpty)
        Text(
          _search.trim().isEmpty
              ? 'No classes to summarise.'
              : 'No classes match your search.',
        )
      else
        for (final c in classes) _ClassCard(summary: c),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.label,
    required this.range,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final String range;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous week',
        icon: const Icon(Icons.chevron_left),
        onPressed: onPrevious,
      ),
      Expanded(
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (range.isNotEmpty)
              Text(
                range,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Next week',
        icon: const Icon(Icons.chevron_right),
        onPressed: onNext,
      ),
    ],
  );
}

class _WeekRowCard extends StatelessWidget {
  const _WeekRowCard({required this.row});

  final ConductionWeekRow row;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (row.status) {
      WeekStatus.held => ('Held', AppTheme.successGreen),
      WeekStatus.notHeld => ('Not held', AppTheme.errorRed),
      WeekStatus.notFilled => ('Not filled', AppTheme.warningOrange),
    };
    final detail = [
      if (row.status == WeekStatus.held && (row.conductedOn ?? '').isNotEmpty)
        row.conductedOn!,
      if (row.status == WeekStatus.held && row.attendance != null)
        '${row.attendance} present',
      if (row.status == WeekStatus.held && row.duration != null)
        '${row.duration} min',
      if (row.status == WeekStatus.notHeld && (row.reason ?? '').isNotEmpty)
        row.reason!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${row.className} · ${row.level}'),
        subtitle: Text([row.teacher, if (detail.isNotEmpty) detail].join('\n')),
        isThreeLine: detail.isNotEmpty,
        trailing: Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.summary});

  final ConductionClass summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${summary.className} · ${summary.level}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (summary.neverHeld)
                  const Chip(
                    label: Text('Never held'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (summary.teacher.isNotEmpty)
              Text(
                summary.teacher,
                style: textTheme.bodySmall?.copyWith(
                  color: AppTheme.mediumText,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Conduction ${summary.percentConduction}% · '
              'Attendance ${summary.percentAttendance}%',
            ),
            Text(
              'Held ${summary.conducted} of ${summary.expected} · '
              '${summary.notFilled} not filled · '
              '${summary.notConducted} not held',
              style: textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
          ],
        ),
      ),
    );
  }
}
