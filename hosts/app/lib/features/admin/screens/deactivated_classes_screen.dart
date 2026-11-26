import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../reports/widgets/report_search.dart';
import '../models/deactivated_classes.dart';
import '../providers/deactivated_classes_provider.dart';
import 'deactivate_class_screen.dart';
import '../../../core/widgets/tab_bar_inset.dart';

enum _Segment { deactivated, activity }

/// The classes that have been deactivated, the log of doing it, and the way to
/// deactivate one (#618): the mobile counterpart of the web's Deactivated
/// Classes page. The server shows it to the super admin only.
class DeactivatedClassesScreen extends ConsumerStatefulWidget {
  const DeactivatedClassesScreen({super.key});

  @override
  ConsumerState<DeactivatedClassesScreen> createState() =>
      _DeactivatedClassesScreenState();
}

class _DeactivatedClassesScreenState
    extends ConsumerState<DeactivatedClassesScreen> {
  static final _when = DateFormat('d MMM y, HH:mm');

  _Segment _segment = _Segment.deactivated;
  String _search = '';

  String _at(DateTime? time) =>
      time == null ? '' : ' · ${_when.format(time.toLocal())}';

  Future<void> _deactivate() async {
    final outcome = await Navigator.of(context).push<DeactivationOutcome>(
      MaterialPageRoute(builder: (_) => const DeactivateClassScreen()),
    );
    if (outcome == null || !mounted) return;
    ref.invalidate(deactivatedClassesProvider);
    if (outcome.byYou) {
      AppSnackBar.showSuccess(context, message: outcome.message);
    } else {
      AppSnackBar.showInfo(context, message: outcome.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(deactivatedClassesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Deactivated classes')),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: _deactivate,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Deactivate a class'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_Segment>(
            segments: const [
              ButtonSegment(
                value: _Segment.deactivated,
                label: Text('Deactivated'),
              ),
              ButtonSegment(value: _Segment.activity, label: Text('Activity')),
            ],
            selected: {_segment},
            onSelectionChanged: (choice) =>
                setState(() => _segment = choice.first),
          ),
          const SizedBox(height: 12),
          ...data.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The deactivated classes could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(deactivatedClassesProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: (d) => _segment == _Segment.deactivated
                ? _deactivated(d.deactivated)
                : _activity(d.log),
          ),
        ],
      ),
    );
  }

  List<Widget> _deactivated(List<DeactivatedClass> all) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final shown = [
      for (final c in all)
        if (matchesSearch(_search, c.searchFields)) c,
    ];

    return [
      ReportSearchField(
        hint: 'Search code, level, teacher, reason or who',
        onChanged: (value) => setState(() => _search = value),
      ),
      const SizedBox(height: 12),
      Text(
        shown.length == all.length
            ? '${all.length} deactivated'
            : '${shown.length} of ${all.length} deactivated',
      ),
      const SizedBox(height: 8),
      if (all.isEmpty)
        const Text('No class has been deactivated.')
      else if (shown.isEmpty)
        const Text('No class matches your search.')
      else
        for (final c in shown)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.code} · ${c.typeName}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    [
                      c.level,
                      c.genderName,
                      c.teacher,
                    ].where((p) => p.isNotEmpty).join(' · '),
                    style: muted,
                  ),
                  if (c.effectiveDate.isNotEmpty)
                    Text('Effective ${c.effectiveDate}'),
                  if (c.reason.isNotEmpty) Text(c.reason),
                  Text(
                    'By ${c.performedBy}${_at(c.performedAt)}',
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
    ];
  }

  List<Widget> _activity(List<DeactivationLogEntry> log) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return [
      Text('Latest ${log.length}'),
      const SizedBox(height: 8),
      if (log.isEmpty)
        const Text('No log entries yet.')
      else
        for (final e in log)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.code} · ${e.typeName}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    [
                      e.level,
                      e.genderName,
                    ].where((p) => p.isNotEmpty).join(' · '),
                    style: muted,
                  ),
                  if (e.effectiveDate.isNotEmpty)
                    Text('Effective ${e.effectiveDate}'),
                  if (e.reason.isNotEmpty) Text(e.reason),
                  Text(
                    'By ${e.performedBy}${_at(e.performedAt)}',
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
    ];
  }
}
