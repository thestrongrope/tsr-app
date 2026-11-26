import 'package:flutter/material.dart';

/// "All" plus one chip per level; shared by the three reports (#568-#570).
/// [selected] null means all levels.
class LevelFilter extends StatelessWidget {
  const LevelFilter({
    super.key,
    required this.levels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> levels;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final level in levels)
          ChoiceChip(
            label: Text(level),
            selected: selected == level,
            onSelected: (_) => onChanged(level),
          ),
      ],
    );
  }
}
