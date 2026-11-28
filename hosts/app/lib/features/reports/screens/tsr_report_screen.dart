import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/tsr_report.dart';
import '../providers/reports_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// TSR at a glance (#580), the mobile counterpart of the web's
/// tsr_summary_report.php: per level, how many classes held a session or set an
/// MCQ, and their attendance and recitation, over a period. Tapping a level
/// lists its classes. The server decides which classes the user may see.
class TsrReportScreen extends ConsumerStatefulWidget {
  const TsrReportScreen({super.key});

  @override
  ConsumerState<TsrReportScreen> createState() => _TsrReportScreenState();
}

class _TsrReportScreenState extends ConsumerState<TsrReportScreen> {
  int? _gender;
  // The last 14 days, as the web page opens.
  late DateTime _to = DateTime.now();
  late DateTime _from = _to.subtract(const Duration(days: 14));
  bool _sharing = false;

  TsrQuery get _query => (gender: _gender, from: _date(_from), to: _date(_to));

  /// Shares the report on screen as a file.
  Future<void> _share(TsrReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareTsrProvider)((
        gender: data.gender,
        from: _date(_from),
        to: _date(_to),
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

  void _showClasses(TsrSection section, TsrLevelRow level) {
    final classes = section.classesOf(level.level);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: withTabBarInset(
            context,
            const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
          children: [
            Text(
              '${section.title} · ${level.level}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (classes.isEmpty)
              const Text('No classes to show for this level.')
            else
              for (final c in classes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.className),
                  subtitle: c.teacher.isEmpty ? null : Text(c.teacher),
                  trailing: Text(c.detail),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(tsrReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('TSR at a glance'),
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
          OutlinedButton.icon(
            onPressed: _pickDates,
            icon: const Icon(Icons.date_range),
            label: Text('${_date(_from)} to ${_date(_to)}'),
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
                  onPressed: () => ref.invalidate(tsrReportProvider(_query)),
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

  List<Widget> _body(TsrReport data) {
    if (!data.hasClasses) {
      return [const Text('No classes were found in this period.')];
    }
    return [
      for (final section in data.sections)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final level in section.levels)
                  ListTile(
                    dense: true,
                    title: Text(level.level),
                    trailing: Text(level.summary),
                    onTap: () => _showClasses(section, level),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}
