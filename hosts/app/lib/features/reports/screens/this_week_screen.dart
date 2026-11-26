import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../models/this_week.dart';
import '../providers/reports_provider.dart';
import '../widgets/this_week_alignment_sheet.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The class coordinator's weekly review (#615): one screen for what used to
/// be several reports, in the order a review goes: was the C-form filled, did
/// the class meet, did students attend, what is being taught. Each flagged
/// class leads to its teacher through the CC's own phone and WhatsApp; the app
/// sends nothing. The server decides which classes and teachers the user sees.
class ThisWeekScreen extends ConsumerStatefulWidget {
  const ThisWeekScreen({super.key});

  @override
  ConsumerState<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends ConsumerState<ThisWeekScreen> {
  int? _gender;
  _SummaryFilter? _filter;

  @override
  Widget build(BuildContext context) {
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = ref.watch(capabilitiesProvider).choosesReportsGender;
    final review = ref.watch(thisWeekProvider(_gender));

    return Scaffold(
      appBar: AppBar(title: const Text('This week')),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          if (choosesGender) ...[
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Gents')),
                ButtonSegment(value: 2, label: Text('Ladies')),
              ],
              selected: {_gender ?? review.asData?.value.gender ?? 1},
              onSelectionChanged: (choice) =>
                  setState(() => _gender = choice.first),
            ),
            const SizedBox(height: 12),
          ],
          ...review.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The weekly review could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(thisWeekProvider(_gender)),
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

  List<Widget> _body(ThisWeek data) {
    final s = data.summary;
    final attendance = s.attendance;
    final flaggedRows = _flaggedRows(data);
    final filter = _filter;
    return [
      Text(
        'Week of ${data.weekFrom} to ${data.weekTo}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      // Each number opens the rows behind it; one with no rows is plain text.
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryStat(
            label: '${s.met} of ${s.total} met',
            filter: _SummaryFilter.met,
            selected: filter == _SummaryFilter.met,
            hasRows: data.met.isNotEmpty,
            onPressed: _toggle,
          ),
          if (s.formsMissing > 0)
            _FilterStat(
              label: s.formsMissing == 1
                  ? '1 form missing'
                  : '${s.formsMissing} forms missing',
              selected: filter == _SummaryFilter.formsMissing,
              enabled: data.cform.isNotEmpty,
              onPressed: () => _toggle(_SummaryFilter.formsMissing),
            ),
          _SummaryStat(
            label: attendance == null
                ? 'No attendance yet'
                : '${(attendance * 100).round()}% attended',
            filter: _SummaryFilter.attended,
            selected: filter == _SummaryFilter.attended,
            hasRows: data.attended.isNotEmpty,
            onPressed: _toggle,
          ),
          if (s.flagged > 0)
            _FilterStat(
              label: '${s.flagged} flagged',
              selected: filter == _SummaryFilter.flagged,
              enabled: flaggedRows.isNotEmpty,
              onPressed: () => _toggle(_SummaryFilter.flagged),
            )
          else
            _Stat('${s.flagged} flagged'),
        ],
      ),
      const SizedBox(height: 16),
      if (filter != null)
        ..._filtered(filter, data, flaggedRows)
      else ...[
        if (s.flagged == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('All clear this week'),
          ),
        _Stage(title: 'C-form', stage: 'cform', rows: data.cform),
        _Stage(title: 'Conduction', stage: 'conduction', rows: data.conduction),
        _Stage(title: 'Attendance', stage: 'attendance', rows: data.attendance),
        _Stage(title: 'Alignment', stage: 'alignment', rows: data.alignment),
      ],
    ];
  }

  void _toggle(_SummaryFilter filter) =>
      setState(() => _filter = _filter == filter ? null : filter);

  void _clear() => setState(() => _filter = null);

  List<Widget> _filtered(
    _SummaryFilter filter,
    ThisWeek data,
    List<ThisWeekRow> flaggedRows,
  ) {
    final rows = switch (filter) {
      _SummaryFilter.met => data.met,
      _SummaryFilter.formsMissing => data.cform,
      _SummaryFilter.attended => data.attended,
      _SummaryFilter.flagged => flaggedRows,
    };
    final stage = filter.stage;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Showing: ${filter.description}',
              key: const Key('filter-indicator'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            key: const Key('filter-clear'),
            onPressed: _clear,
            child: const Text('Clear filter'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        AppEmptySection(
          icon: Icons.filter_alt_off_outlined,
          message: 'No classes match this filter',
          actionLabel: 'Clear filter',
          onAction: _clear,
        )
      else
        _Stage(title: filter.title, stage: stage, rows: rows),
    ];
  }
}

/// The summary numbers that open the rows behind them.
enum _SummaryFilter {
  met('classes that met', 'Met', 'met'),
  formsMissing('forms missing', 'C-form', 'cform'),
  attended('classes with attendance marked', 'Attendance', 'attended'),
  flagged('flagged classes', 'Flagged', 'flagged');

  const _SummaryFilter(this.description, this.title, this.stage);

  final String description;
  final String title;

  /// Keys the list, as the stages are keyed.
  final String stage;
}

/// Every class flagged in the C-form, conduction or attendance stage, once:
/// the rows behind the "flagged" number. A class flagged in several stages
/// becomes one row carrying all its reasons.
List<ThisWeekRow> _flaggedRows(ThisWeek data) {
  final byClass = <int, ThisWeekRow>{};
  for (final row in [...data.cform, ...data.conduction, ...data.attendance]) {
    final first = byClass[row.classId];
    byClass[row.classId] = first == null ? row : _merge(first, row);
  }
  return byClass.values.toList();
}

ThisWeekRow _merge(ThisWeekRow a, ThisWeekRow b) {
  final details = [
    a.detail,
    b.detail,
  ].where((d) => d.isNotEmpty).toSet().join('; ');
  return ThisWeekRow(
    classId: a.classId,
    code: a.code,
    level: a.level,
    teacher: a.teacher,
    teacherMobile: a.teacherMobile ?? b.teacherMobile,
    detail: details,
    action: a.action == 'call' || b.action == 'call'
        ? 'call'
        : (a.action ?? b.action),
    quiet: [...a.quiet, ...b.quiet],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// A summary number: tappable when [hasRows], plain text otherwise.
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.filter,
    required this.selected,
    required this.hasRows,
    required this.onPressed,
  });

  final String label;
  final _SummaryFilter filter;
  final bool selected;
  final bool hasRows;
  final void Function(_SummaryFilter) onPressed;

  @override
  Widget build(BuildContext context) => _FilterStat(
    label: label,
    selected: selected,
    enabled: hasRows,
    onPressed: () => onPressed(filter),
  );
}

/// A summary number that can be tapped to filter the list; plain text
/// ([_Stat]) is used instead when there is nothing behind it.
class _FilterStat extends StatelessWidget {
  const _FilterStat({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return _Stat(label);
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Clear filter: $label' : 'Show only: $label',
      excludeSemantics: true,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: FilterChip(
          label: Text(label),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          selected: selected,
          showCheckmark: true,
          onSelected: (_) => onPressed(),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}

/// One stage: a heading and its class rows; nothing when it has none.
class _Stage extends StatelessWidget {
  const _Stage({required this.title, required this.stage, required this.rows});

  final String title;
  final String stage;
  final List<ThisWeekRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      key: Key('stage-$stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '${rows.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in rows) _RowCard(stage: stage, row: row),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RowCard extends ConsumerWidget {
  const _RowCard({required this.stage, required this.row});

  final String stage;
  final ThisWeekRow row;

  /// What the message says; the coordinator can edit it before sending.
  String get _note {
    final what = row.detail.isNotEmpty
        ? row.detail
        : row.quiet
              .map(
                (q) => '${_label(q.subject)} not taught for ${q.weeks} weeks',
              )
              .join('; ');
    return 'Salaam. About class ${row.code}: $what. Could we talk?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launch = ref.read(thisWeekLaunchProvider);
    final mobile = row.teacherMobile;
    final digits = mobile == null ? '' : dialableNumber(mobile);
    final canReach = digits.isNotEmpty && row.action != null;
    final isAlignment = stage == 'alignment';

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                row.code,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(row.level, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (row.teacher.isNotEmpty) Text(row.teacher),
          if (row.detail.isNotEmpty) Text(row.detail),
          for (final q in row.quiet)
            Text('${_label(q.subject)}: not taught for ${q.weeks} weeks'),
          if (canReach && !isAlignment) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (row.action == 'call')
                  FilledButton(
                    onPressed: () =>
                        launch(Uri(scheme: 'tel', path: '+$digits')),
                    child: const Text('Call'),
                  ),
                OutlinedButton(
                  onPressed: () =>
                      launch(Uri.https('wa.me', '/$digits', {'text': _note})),
                  child: const Text('Message'),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Card(
      key: Key('row-$stage-${row.classId}'),
      child: isAlignment
          ? InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                builder: (_) => ThisWeekAlignmentSheet(
                  classId: row.classId,
                  code: row.code,
                ),
              ),
              child: content,
            )
          : content,
    );
  }
}

/// `ahkam` as `Ahkam`.
String _label(String subject) =>
    subject.isEmpty ? subject : subject[0].toUpperCase() + subject.substring(1);
