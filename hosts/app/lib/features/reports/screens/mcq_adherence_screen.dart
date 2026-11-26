import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/mcq_adherence_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// What the class screen needs from the list that opened it: the gender the
/// list answered for, and the class's name for the title.
class McqAdherenceClassArgs {
  const McqAdherenceClassArgs({required this.title, required this.gender});

  final String title;
  final int gender;
}

/// The MCQ adherence report (#595), the mobile counterpart of the web's
/// mcq_adherence_report.php: how closely each class follows the standard MCQs,
/// worst first; a class opens its MCQs. The server decides which classes the
/// user may see.
class McqAdherenceScreen extends ConsumerStatefulWidget {
  const McqAdherenceScreen({super.key});

  @override
  ConsumerState<McqAdherenceScreen> createState() => _McqAdherenceScreenState();
}

class _McqAdherenceScreenState extends ConsumerState<McqAdherenceScreen> {
  int? _gender;
  String? _level;
  String _search = '';
  bool _sharing = false;

  /// The classes the list shows: the level and the search applied.
  List<McqAdherenceClass> _inView(McqAdherenceReport data) => [
    for (final c in data.classes)
      if ((_level == null || c.level == _level) &&
          matchesSearch(_search, [c.className, c.teacher]))
        c,
  ];

  /// Shares the classes in view with their standard MCQs (CSV).
  Future<void> _shareAll(McqAdherenceReport data) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareMcqAdherenceAllProvider)(
        classIds: [for (final c in _inView(data)) c.classId],
        gender: data.gender,
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

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(mcqAdherenceReportProvider(_gender));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('MCQ adherence'),
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
                      ref.invalidate(mcqAdherenceReportProvider(_gender)),
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

  List<Widget> _body(McqAdherenceReport data) {
    if (data.classes.isEmpty) {
      return [const Text('No class has standard MCQs to follow.')];
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
        for (final c in classes) _ClassCard(summary: c, gender: data.gender),
    ];
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.summary, required this.gender});

  final McqAdherenceClass summary;
  final int gender;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final title = '${summary.className} · ${summary.level}';
    final f = summary.figures;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push(
          '${AppRoutes.adminMcqAdherence}/${summary.classId}',
          extra: McqAdherenceClassArgs(title: title, gender: gender),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (summary.teacher.isNotEmpty)
                Text(summary.teacher, style: muted),
              const SizedBox(height: 8),
              Text('Adherence ${f.percentLabel}'),
              Text(
                '${f.conducted} of ${f.expected} conducted · '
                '${f.pending} pending · ${f.skipped} skipped',
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One class's standard MCQs and where it stands on each, with Share.
class McqAdherenceClassScreen extends ConsumerStatefulWidget {
  const McqAdherenceClassScreen({
    super.key,
    required this.classId,
    required this.args,
  });

  final int classId;
  final McqAdherenceClassArgs args;

  @override
  ConsumerState<McqAdherenceClassScreen> createState() =>
      _McqAdherenceClassScreenState();
}

class _McqAdherenceClassScreenState
    extends ConsumerState<McqAdherenceClassScreen> {
  bool _sharing = false;

  McqAdherenceClassQuery get _query =>
      (classId: widget.classId, gender: widget.args.gender);

  Future<void> _share(ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareMcqAdherenceClassProvider)(_query, format);
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
    final detail = ref.watch(mcqAdherenceClassProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.args.title),
        actions: [
          if (detail.asData case AsyncData(
            :final value,
          ) when value.mcqs.isNotEmpty)
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
            const Text('The MCQs could not be loaded.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () =>
                    ref.invalidate(mcqAdherenceClassProvider(_query)),
                child: const Text('Try again'),
              ),
            ),
          ],
          data: (d) => d.mcqs.isEmpty
              ? [const Text('This class has no standard MCQs.')]
              : [
                  Text(
                    'Adherence ${d.figures.percentLabel} · '
                    '${d.figures.conducted} of ${d.figures.expected} conducted',
                  ),
                  const SizedBox(height: 12),
                  for (final m in d.mcqs) _McqTile(mcq: m),
                ],
        ),
      ),
    );
  }
}

class _McqTile extends StatelessWidget {
  const _McqTile({required this.mcq});

  final AdherenceMcq mcq;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final status = switch (mcq.status) {
      'conducted' => 'Conducted',
      'pending' => 'Pending',
      _ => 'Skipped',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(mcq.name),
        subtitle: Text('${mcq.topic} · ${mcq.subject}', style: muted),
        trailing: Text(status),
      ),
    );
  }
}
