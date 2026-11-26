import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/teachers.dart';

/// The five levels as the web shows them (SM, AG, MK, AY, BL) with their names,
/// so the short codes on every row can be read.
class TeacherLevelLegend extends StatelessWidget {
  const TeacherLevelLegend({super.key, required this.levels});

  final List<TeacherLevel> levels;

  @override
  Widget build(BuildContext context) => Text(
    levels.map((l) => '${l.code} ${l.name}').join(' · '),
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
  );
}

/// A teacher's five training flags as chips, trained ones filled. With
/// [onToggle] each chip switches its flag (the list's edit mode); [changed]
/// holds the level keys whose flag differs from what is saved.
class TeacherFlags extends StatelessWidget {
  const TeacherFlags({
    super.key,
    required this.levels,
    required this.flags,
    this.onToggle,
    this.changed = const {},
  });

  final List<TeacherLevel> levels;
  final Map<String, bool> flags;
  final ValueChanged<String>? onToggle;
  final Set<String> changed;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      for (final l in levels)
        _chip(
          l,
          trained: flags[l.key] == true,
          edited: changed.contains(l.key),
        ),
    ],
  );

  Widget _chip(TeacherLevel l, {required bool trained, required bool edited}) {
    final label = '${l.name} ${trained ? 'trained' : 'not trained'}';
    final side = edited
        ? const BorderSide(color: Colors.orange, width: 2)
        : null;
    final avatar = Icon(
      trained ? Icons.check : Icons.remove,
      size: 16,
      semanticLabel: label,
    );
    final toggle = onToggle;
    if (toggle == null) {
      return Chip(
        key: ValueKey('flag-${l.key}'),
        label: Text(l.code),
        visualDensity: VisualDensity.compact,
        backgroundColor: trained ? AppTheme.lightGreen : Colors.transparent,
        avatar: avatar,
        side: side,
      );
    }
    return ActionChip(
      key: ValueKey('flag-${l.key}'),
      label: Text(l.code),
      visualDensity: VisualDensity.compact,
      backgroundColor: trained ? AppTheme.lightGreen : Colors.transparent,
      avatar: avatar,
      side: side,
      onPressed: () => toggle(l.key),
    );
  }
}
