import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/subject_conduction_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/month_range.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The subject conduction report (#590), the mobile counterpart of the web's
/// class_subject_conduction_report.php: for each class, the topic taught in
/// each subject in each week it was held, opening on the current month. The
/// server decides which classes the user may see.
class SubjectConductionScreen extends ConsumerStatefulWidget {
  const SubjectConductionScreen({super.key});

  @override
  ConsumerState<SubjectConductionScreen> createState() =>
      _SubjectConductionScreenState();
}

class _SubjectConductionScreenState
    extends ConsumerState<SubjectConductionScreen> {
  /// The current month and the 23 before it, newest first.
  late final List<String> _months = lastMonths(24);

  int? _gender;
  late String _from = _months.first;
  late String _to = _months.first;
  String? _level;
  int? _classId;
  String _search = '';
  bool _sharing = false;

  SubjectConductionQuery get _query => (gender: _gender, from: _from, to: _to);

  void _setFrom(String month) => setState(() {
    _from = month;
    if (monthKey(_to) < monthKey(month)) _to = month;
  });

  void _setTo(String month) => setState(() {
    _to = month;
    if (monthKey(_from) > monthKey(month)) _from = month;
  });

  /// Shares the period on screen, narrowed to the level and class chosen.
  Future<void> _share(SubjectConductionReport data, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareSubjectConductionProvider)(
        (gender: data.gender, from: _from, to: _to),
        _level,
        _classId,
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
    final report = ref.watch(subjectConductionReportProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Subject conduction'),
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
                _classId = null;
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
                      ref.invalidate(subjectConductionReportProvider(_query)),
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

  String _emptyMessage({required bool hasClassChosen}) {
    if (_search.trim().isNotEmpty) return 'No classes match your search.';
    if (hasClassChosen) return 'No sessions for this class in this period.';
    return 'No classes for this level.';
  }

  List<Widget> _body(SubjectConductionReport data) {
    if (!data.hasSessions) {
      return [const Text('No classes were held in this period.')];
    }
    // The class chosen, if it is still one of this report's.
    final chosen = _level == null
        ? null
        : data.classChoices
              .where((c) => c.classId == _classId && c.level == _level)
              .firstOrNull;
    final levelChoices = [
      for (final c in data.classChoices)
        if (c.level == _level) c,
    ];
    final classes = [
      for (final c in data.classes)
        if ((_level == null || c.level == _level) &&
            (chosen == null || c.className == chosen.className) &&
            matchesSearch(_search, [c.className, c.teacher]))
          c,
    ];

    return [
      if (data.levels.length > 1) ...[
        LevelFilter(
          levels: data.levels,
          selected: _level,
          onChanged: (level) => setState(() {
            _level = level;
            _classId = null;
          }),
        ),
        const SizedBox(height: 12),
      ],
      if (_level != null && levelChoices.isNotEmpty) ...[
        DropdownButtonFormField<int?>(
          key: ValueKey('class-$_level-$_classId'),
          initialValue: chosen?.classId,
          decoration: const InputDecoration(labelText: 'Class'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All classes'),
            ),
            for (final c in levelChoices)
              DropdownMenuItem<int?>(
                value: c.classId,
                child: Text('${c.className} · ${c.teacher}'),
              ),
          ],
          onChanged: (id) => setState(() => _classId = id),
        ),
        const SizedBox(height: 12),
      ],
      if (classes.isEmpty)
        Text(_emptyMessage(hasClassChosen: chosen != null))
      else
        for (final c in classes) _ClassCard(subjectClass: c),
    ];
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.subjectClass});

  final SubjectClass subjectClass;

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
            Text(
              '${subjectClass.className} · ${subjectClass.level}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subjectClass.teacher.isNotEmpty)
              Text(subjectClass.teacher, style: muted),
            for (final w in subjectClass.weeks) ...[
              const SizedBox(height: 12),
              Text(
                'Held ${w.heldOn}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              _Topic(subject: 'Arabic', topic: w.arabic),
              _Topic(subject: 'Aqaed', topic: w.aqaed),
              _Topic(subject: 'Ahkam', topic: w.ahkam),
              _Topic(subject: 'Akhlaq', topic: w.akhlaq),
              _Topic(subject: 'Other', topic: w.other),
            ],
          ],
        ),
      ),
    );
  }
}

/// A subject and what it covered; a dash for a subject not taught that week.
class _Topic extends StatelessWidget {
  const _Topic({required this.subject, required this.topic});

  final String subject;
  final String topic;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    return Text('$subject: ${topic.isEmpty ? '—' : topic}', style: muted);
  }
}
