import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/teachers.dart';
import '../providers/teachers_provider.dart';
import '../widgets/teacher_flags.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// One teacher (#622): contact details, the levels they are trained to conduct,
/// their classes now and before, and the history of their training. Reached from
/// the list. The server answers 404 for a teacher that does not exist and for
/// one the caller may not see, and the screen says so without saying which.
class TeacherDetailScreen extends ConsumerWidget {
  const TeacherDetailScreen({super.key, required this.token});

  final int token;

  /// The levels, in the web's order, named as the list names them.
  static const _levels = [
    TeacherLevel(key: 'salman', code: 'SM', name: 'Salman'),
    TeacherLevel(key: 'abuzar', code: 'AG', name: 'Abuzar'),
    TeacherLevel(key: 'miqdad', code: 'MK', name: 'Miqdad'),
    TeacherLevel(key: 'ammar', code: 'AY', name: 'Ammar'),
    TeacherLevel(key: 'bilal', code: 'BL', name: 'Bilal'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherDetailProvider(token));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: Text(data.value?.name ?? 'Teacher')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e is ApiException && e.statusCode == 404
                    ? 'This teacher could not be opened.'
                    : 'The teacher could not be loaded.',
              ),
              if (!(e is ApiException && e.statusCode == 404)) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(teacherDetailProvider(token)),
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
        data: (t) => _Body(teacher: t),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.teacher});

  final TeacherDetail teacher;

  @override
  Widget build(BuildContext context) {
    final t = teacher;
    final heading = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    // Each section folds away; the long ones about the past start folded.
    Widget section(String title, List<Widget> children, {bool open = true}) =>
        ExpansionTile(
          title: Text(title, style: heading),
          initiallyExpanded: open,
          tilePadding: EdgeInsets.zero,
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: children,
        );

    return ListView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      children: [
        Text('#${t.token}'),
        if (t.email != null) Text(t.email!),
        if (t.mobile != null) Text(t.mobile!),
        if (t.address.isNotEmpty) Text(t.address),
        section('Trained to conduct', [
          const SizedBox(height: 8),
          TeacherFlags(levels: TeacherDetailScreen._levels, flags: t.flags),
          const SizedBox(height: 4),
          const TeacherLevelLegend(levels: TeacherDetailScreen._levels),
          if (!t.trained) const Text('Not trained for any level yet.'),
        ]),
        section('Conducting', _classes(t.conducting, 'No classes right now.')),
        section('Attending', _classes(t.attending, 'No classes right now.')),
        section(
          'Conducted before',
          _classes(t.conducted, 'None.'),
          open: false,
        ),
        section('Attended before', _classes(t.attended, 'None.'), open: false),
        section('Training history', [
          if (t.history.isEmpty) const Text('No history yet.'),
          for (final h in t.history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(h.comments),
              subtitle: Text(
                [h.by, h.on].where((p) => p.isNotEmpty).join(' · '),
              ),
            ),
        ]),
      ],
    );
  }

  List<Widget> _classes(List<TeacherClass> classes, String none) => [
    if (classes.isEmpty) Text(none),
    for (final c in classes) _ClassCard(c),
  ];
}

class _ClassCard extends StatelessWidget {
  const _ClassCard(this.c);

  final TeacherClass c;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.code} · ${c.level}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (c.place.isNotEmpty) Text(c.place, style: muted),
            if (c.teacher != null) Text('Teacher ${c.teacher}', style: muted),
            if (c.startedOn != null || c.endedOn != null)
              Text(
                [
                  if (c.startedOn != null) 'From ${c.startedOn}',
                  if (c.endedOn != null) 'to ${c.endedOn}',
                ].join(' '),
                style: muted,
              ),
            for (final s in c.schedules) Text(s, style: muted),
            if (c.comments != null) Text(c.comments!),
            if (c.removedBy != null)
              Text('Removed by ${c.removedBy}', style: muted),
          ],
        ),
      ),
    );
  }
}
