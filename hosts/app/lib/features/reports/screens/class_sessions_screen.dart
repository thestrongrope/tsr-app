import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/class_sessions_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// `2026-09-09` as `9 Sep 2026`; anything else is shown as it came.
String _day(String iso) {
  final date = DateTime.tryParse(iso);
  return date == null ? iso : DateFormat('d MMM yyyy').format(date);
}

/// The class sessions report (#592), the mobile counterpart of the web's
/// class_sessions_report.php: each class with its session count and what the
/// last session covered; a class opens its history. The server decides which
/// classes the user may see.
class ClassSessionsScreen extends ConsumerStatefulWidget {
  const ClassSessionsScreen({super.key});

  @override
  ConsumerState<ClassSessionsScreen> createState() =>
      _ClassSessionsScreenState();
}

class _ClassSessionsScreenState extends ConsumerState<ClassSessionsScreen> {
  int? _gender;
  String? _level;
  String _search = '';
  bool _sharing = false;

  /// Shares every permitted class's sessions (CSV) for the gender on screen.
  Future<void> _shareAll(int gender) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareClassSessionsAllProvider)(gender);
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 404) {
          AppSnackBar.showInfo(
            context,
            message: 'There are no sessions to share yet.',
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

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesReportsGender;
    final report = ref.watch(classSessionsReportProvider(_gender));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Class sessions'),
        actions: [
          if (capabilities.canReadReports && report.asData != null)
            PopupMenuButton<int>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: _shareAll,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: report.asData!.value.gender,
                  child: const Text('Share all (CSV)'),
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
                      ref.invalidate(classSessionsReportProvider(_gender)),
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

  List<Widget> _body(ClassSessionsReport data) {
    if (data.classes.isEmpty) {
      return [const Text('There are no classes to show.')];
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

  final ClassSessionsClass summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final last = summary.lastDate;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push(
          '${AppRoutes.adminClassSessions}/${summary.classId}',
          extra: '${summary.className} · ${summary.level}',
        ),
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
              if (summary.teacher.isNotEmpty)
                Text(summary.teacher, style: muted),
              const SizedBox(height: 8),
              Text(
                last == null
                    ? '${summary.totalSessions} sessions'
                    : '${summary.totalSessions} sessions · last ${_day(last)}',
              ),
              if (summary.lastQuran.isNotEmpty)
                Text('Quran: ${summary.lastQuran}', style: muted),
              for (final topic in summary.lastTopics.entries)
                Text('${topic.key}: ${topic.value}', style: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every session recorded for one class, newest first, with Share.
class ClassSessionHistoryScreen extends ConsumerStatefulWidget {
  const ClassSessionHistoryScreen({
    super.key,
    required this.classId,
    this.title,
  });

  final int classId;

  /// The class, as the list named it; the history alone does not carry it.
  final String? title;

  @override
  ConsumerState<ClassSessionHistoryScreen> createState() =>
      _ClassSessionHistoryScreenState();
}

class _ClassSessionHistoryScreenState
    extends ConsumerState<ClassSessionHistoryScreen> {
  bool _sharing = false;

  Future<void> _share(ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareClassSessionsProvider)(widget.classId, format);
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
    final history = ref.watch(classSessionHistoryProvider(widget.classId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.title ?? 'Class sessions'),
        actions: [
          if (history.asData case AsyncData(:final value) when value.isNotEmpty)
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
        children: history.when(
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            const Text('The sessions could not be loaded.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () =>
                    ref.invalidate(classSessionHistoryProvider(widget.classId)),
                child: const Text('Try again'),
              ),
            ),
          ],
          data: (sessions) => sessions.isEmpty
              ? [const Text('No sessions have been recorded for this class.')]
              : [for (final s in sessions) _SessionCard(session: s)],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final ClassSession session;

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
              _day(session.date),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!session.held)
              Text(
                (session.reason ?? '').isEmpty
                    ? 'Not held'
                    : 'Not held: ${session.reason}',
                style: muted,
              ),
            if (session.quran.isNotEmpty)
              Text('Quran: ${session.quran}', style: muted),
            for (final topic in session.topics.entries)
              Text('${topic.key}: ${topic.value}', style: muted),
          ],
        ),
      ),
    );
  }
}
