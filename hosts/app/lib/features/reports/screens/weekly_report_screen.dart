import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/conduction_report.dart' show WeekStatus;
import '../models/weekly_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/month_range.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The weekly report (#569), the mobile counterpart of the web's
/// class_reports_weekly_*.php. The web shows every week of a month range in
/// one wide grid; a phone cannot, so this steps through the range one week at
/// a time and lists each class's result for that week. The figures are the
/// same: the server computes both from MisModel.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  /// The current month and the eleven before it, newest first, as `MM-YYYY`
  /// (the longest range the server answers).
  late final List<String> _months = lastMonths(12);

  int? _gender;
  late String _from = _months.first;
  late String _to = _months.first;
  String? _level;
  String _search = '';
  bool _sharing = false;

  /// The week on show; null until the report arrives, then the current week
  /// (or the last one when the range is in the past).
  int? _weekIndex;

  WeeklyQuery get _query => (gender: _gender, from: _from, to: _to);

  void _setFrom(String month) => setState(() {
    _from = month;
    if (monthKey(_to) < monthKey(month)) _to = month;
    _weekIndex = null;
  });

  void _setTo(String month) => setState(() {
    _to = month;
    if (monthKey(_from) > monthKey(month)) _from = month;
    _weekIndex = null;
  });

  /// Shares the range on screen, narrowed to the level chosen.
  Future<void> _share(WeeklyReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareWeeklyProvider)(
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

  int _currentWeek(WeeklyReport data) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final index = data.weeks.indexWhere(
      (w) => w.from.compareTo(today) <= 0 && today.compareTo(w.to) <= 0,
    );
    return index >= 0 ? index : data.weeks.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(weeklyReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Weekly report'),
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
                _weekIndex = null;
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
                  onPressed: () => ref.invalidate(weeklyReportProvider(_query)),
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

  List<Widget> _body(WeeklyReport data) {
    final classes = [
      for (final c in data.classes)
        if ((_level == null || c.level == _level) &&
            matchesSearch(_search, [c.className, c.teacher]))
          c,
    ];
    // A range where no class has a filled session has nothing to step through.
    if (data.weeks.isEmpty || !data.classes.any((c) => c.hasSessions)) {
      return [const Text('No sessions were recorded in this period.')];
    }

    final index = (_weekIndex ?? _currentWeek(data)).clamp(
      0,
      data.weeks.length - 1,
    );
    final week = data.weeks[index];

    return [
      _WeekStepper(
        label: '${week.month} · ${week.label}',
        range: '${week.from} to ${week.to}',
        onPrevious: index == 0
            ? null
            : () => setState(() => _weekIndex = index - 1),
        onNext: index == data.weeks.length - 1
            ? null
            : () => setState(() => _weekIndex = index + 1),
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
      if (classes.isEmpty)
        Text(
          _search.trim().isEmpty
              ? 'No classes for this level.'
              : 'No classes match your search.',
        )
      else
        for (final c in classes)
          if (index < c.weeks.length)
            _ClassWeekCard(summary: c, cell: c.weeks[index]),
    ];
  }
}

class _WeekStepper extends StatelessWidget {
  const _WeekStepper({
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

class _ClassWeekCard extends StatelessWidget {
  const _ClassWeekCard({required this.summary, required this.cell});

  final WeeklyClass summary;
  final WeeklyCell cell;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (cell.status) {
      WeekStatus.held => (
        cell.sessions > 1 ? 'Held (${cell.sessions})' : 'Held',
        AppTheme.successGreen,
      ),
      WeekStatus.notHeld => ('Not held', AppTheme.errorRed),
      WeekStatus.notFilled => ('Not filled', AppTheme.warningOrange),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${summary.className} · ${summary.level}'),
        subtitle: summary.teacher.isEmpty ? null : Text(summary.teacher),
        trailing: Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
