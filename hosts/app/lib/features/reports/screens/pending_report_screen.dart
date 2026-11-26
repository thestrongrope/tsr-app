import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_datetime.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/pending_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/month_range.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Pending work (#584): each teacher with class forms not filled and MCQs
/// copied but not conducted, class by class, most pending first. It is the
/// list the CC team builds by hand in the teachers' groups. The server decides
/// which classes the user may see.
class PendingReportScreen extends ConsumerStatefulWidget {
  const PendingReportScreen({super.key});

  @override
  ConsumerState<PendingReportScreen> createState() =>
      _PendingReportScreenState();
}

class _PendingReportScreenState extends ConsumerState<PendingReportScreen> {
  /// The current month and the eleven before it, newest first.
  late final List<String> _months = lastMonths(12);

  int? _gender;
  // The previous and the current month, as the server's default.
  late String _from = _months[1];
  late String _to = _months.first;
  String? _level;
  String _search = '';
  bool _sharing = false;

  PendingQuery get _query => (gender: _gender, from: _from, to: _to);

  void _setFrom(String month) => setState(() {
    _from = month;
    if (monthKey(_to) < monthKey(month)) _to = month;
  });

  void _setTo(String month) => setState(() {
    _to = month;
    if (monthKey(_from) > monthKey(month)) _from = month;
  });

  /// Shares the report on screen, narrowed to the level chosen.
  Future<void> _share(PendingReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(sharePendingProvider)(
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

  /// Shows the reminder that would go to [teacher] and, only if the member
  /// confirms, sends it. The first call is a preview that sends nothing.
  Future<void> _remind(PendingTeacher teacher) async {
    final nudge = ref.read(nudgeTeacherProvider);
    final PendingNudge preview;
    try {
      preview = await nudge(_query, teacher.token, send: false);
    } catch (e) {
      _failed(e, 'The reminder could not be prepared. Please try again.');
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remind ${preview.teacher}?'),
        content: SingleChildScrollView(
          child: Text(
            preview.alreadyReminded
                ? 'Already reminded${preview.lastReminded == null ? '' : ' at ${formatApiLocalDateTime(preview.lastReminded)}'}. '
                      'Please try again tomorrow.'
                : preview.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(preview.alreadyReminded ? 'OK' : 'Cancel'),
          ),
          if (!preview.alreadyReminded)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await nudge(_query, teacher.token, send: true);
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Reminder sent to ${preview.teacher}.',
        );
      }
    } catch (e) {
      _failed(e, 'The reminder could not be sent. Please try again.');
    }
  }

  /// Says why, when the server gave a reason (already reminded, too many
  /// reminders), otherwise [fallback]; the screen stays as it was.
  void _failed(Object error, String fallback) {
    if (!mounted) return;
    final reason = error is ApiException && error.statusCode == 429
        ? error.message
        : fallback;
    AppSnackBar.showError(context, message: reason);
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(pendingReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Pending work'),
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
                  label: 'Forms from',
                  value: _from,
                  months: _months,
                  onChanged: _setFrom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MonthDropdown(
                  label: 'to',
                  value: _to,
                  months: _months,
                  onChanged: _setTo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ReportSearchField(
            hint: 'Search teachers or classes',
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
                      ref.invalidate(pendingReportProvider(_query)),
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

  List<Widget> _body(PendingReport data) {
    if (data.teachers.isEmpty) {
      return [const Text('Nothing is pending in this period.')];
    }
    // Narrow to the level first, so a teacher's totals count only its classes.
    final teachers = [
      for (final t in data.teachers.map((t) => t.inLevel(_level)))
        if (t.classes.isNotEmpty &&
            matchesSearch(_search, [
              t.name,
              ...t.classes.map((c) => c.className),
            ]))
          t,
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
      if (teachers.isEmpty)
        Text(
          _search.trim().isEmpty
              ? 'Nothing is pending for this level.'
              : 'No teachers or classes match your search.',
        )
      else ...[
        Text(
          '${teachers.length} teachers · '
          '${teachers.fold(0, (s, t) => s + t.notFilled)} forms · '
          '${teachers.fold(0, (s, t) => s + t.mcqPending)} MCQs pending',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
        ),
        const SizedBox(height: 8),
        for (final t in teachers)
          _TeacherCard(teacher: t, onRemind: () => _remind(t)),
      ],
    ];
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher, required this.onRemind});

  final PendingTeacher teacher;
  final VoidCallback onRemind;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    teacher.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onRemind,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Remind'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${teacher.notFilled} forms not filled · '
              '${teacher.mcqPending} MCQs pending',
            ),
            const SizedBox(height: 8),
            for (final c in teacher.classes)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${c.className} · ${c.level}')),
                    Text(
                      '${c.notFilled} forms · ${c.mcqPending} MCQs',
                      style: muted,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
