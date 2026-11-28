import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../reports/widgets/report_search.dart';
import '../models/teachers.dart';
import '../providers/teachers_provider.dart';
import '../widgets/teacher_flags.dart';
import '../widgets/teacher_training_dialogs.dart';
import '../../../core/widgets/tab_bar_inset.dart';

enum _Sort { name, level, classes }

/// The teachers of a gender and the levels each is trained to conduct (#622):
/// the mobile counterpart of the web's Teachers page. Someone who reaches both
/// genders chooses; a gender admin gets their own, whatever the screen asks.
class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  int _gender = 1;
  String _search = '';
  String? _level;
  final Set<String> _trainedFor = {};

  /// null any number of classes; 3 means three or more.
  int? _classCount;
  _Sort _sort = _Sort.name;
  bool _descending = false;

  bool _editing = false;

  /// Flags the admin has switched and not yet saved: teacher token, then level
  /// key to the value it now has. A flag put back as it was is not here.
  final Map<int, Map<String, bool>> _edits = {};

  static const _classCounts = <int?, String>{
    null: 'Any number of classes',
    0: 'No classes',
    1: '1 class',
    2: '2 classes',
    3: '3 or more',
  };

  bool _hasClassCount(TeacherRow t) =>
      _classCount == null ||
      (_classCount == 3 ? t.classes >= 3 : t.classes == _classCount);

  List<TeacherRow> _shown(List<TeacherRow> all) {
    final shown = [
      for (final t in all)
        if (matchesSearch(_search, t.searchFields) &&
            (_level == null || t.level == _level) &&
            _trainedFor.every(t.isTrainedFor) &&
            _hasClassCount(t))
          t,
    ];
    int by(TeacherRow a, TeacherRow b) => switch (_sort) {
      _Sort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _Sort.level => a.level.compareTo(b.level),
      _Sort.classes => a.classes.compareTo(b.classes),
    };
    shown.sort((a, b) {
      final c = by(a, b);
      // Ties fall back to the name, so a sort never shuffles equal rows.
      final r = c != 0
          ? c
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return _descending && c != 0 ? -r : r;
    });
    return shown;
  }

  int get _changedCount => _edits.values.fold(0, (n, e) => n + e.length);

  Map<String, bool> _flagsOf(TeacherRow t) => {...t.flags, ...?_edits[t.token]};

  void _toggle(TeacherRow t, String level) {
    setState(() {
      final now = !(_flagsOf(t)[level] == true);
      final edits = _edits.putIfAbsent(t.token, () => {});
      if (now == t.isTrainedFor(level)) {
        edits.remove(level);
        if (edits.isEmpty) _edits.remove(t.token);
      } else {
        edits[level] = now;
      }
    });
  }

  void _stopEditing() => setState(() {
    _editing = false;
    _edits.clear();
  });

  List<TrainingChange> _changes() => [
    for (final e in _edits.entries)
      for (final f in e.value.entries)
        TrainingChange(token: e.key, level: f.key, added: f.value),
  ];

  Future<void> _save() async {
    final changed = await showDialog<int>(
      context: context,
      builder: (_) => SaveTrainingDialog(changes: _changes()),
    );
    if (changed == null || !mounted) return;
    ref.invalidate(teachersProvider(_gender));
    _stopEditing();
    AppSnackBar.showSuccess(
      context,
      message: changed == 1
          ? '1 teacher updated.'
          : '$changed teachers updated.',
    );
  }

  Future<void> _import(int gender) async {
    final added = await showDialog<int>(
      context: context,
      builder: (_) => ImportTeachersDialog(gender: gender),
    );
    if (added == null || !mounted) return;
    ref.invalidate(teachersProvider(_gender));
    AppSnackBar.showSuccess(
      context,
      message: switch (added) {
        0 => 'No new teachers to import.',
        1 => '1 teacher imported.',
        _ => '$added teachers imported.',
      },
    );
  }

  /// "Ali: +AY −BL" for each teacher with unsaved changes, for the Changed list.
  List<String> _changeLines(TeachersList list) {
    String code(String key) =>
        list.levels.where((l) => l.key == key).firstOrNull?.code ?? key;
    return [
      for (final e in _edits.entries)
        '${list.teachers.where((t) => t.token == e.key).firstOrNull?.name ?? '#${e.key}'}: '
            '${e.value.entries.map((f) => '${f.value ? '+' : '−'}${code(f.key)}').join(' ')}',
    ];
  }

  Future<void> _showChanges(TeachersList list) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Changed: $_changedCount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in _changeLines(list)) Text(l)],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(_edits.clear);
            Navigator.of(ctx).pop();
          },
          child: const Text('Clear all'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    _gender = ref.read(capabilitiesProvider).managedGender ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final chooseGender = ref.watch(capabilitiesProvider).canChooseTeacherGender;
    final data = ref.watch(teachersProvider(_gender));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: [
          if (data.hasValue)
            TextButton(
              onPressed: _editing
                  ? _stopEditing
                  : () => setState(() => _editing = true),
              child: Text(_editing ? 'Cancel' : 'Edit'),
            ),
          if (data.hasValue && !_editing)
            PopupMenuButton<String>(
              onSelected: (_) => _import(data.requireValue.gender),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'import',
                  child: Text('Import active teachers'),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: _editing && data.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _changedCount == 0
                          ? null
                          : () => _showChanges(data.requireValue),
                      child: Text('Changed: $_changedCount'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _changedCount == 0 ? null : _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: ListView(
        // While editing, the bottom bar below already clears the tab bar.
        padding: _editing && data.hasValue
            ? const EdgeInsets.all(16)
            : withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          if (chooseGender) ...[
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Gents')),
                ButtonSegment(value: 2, label: Text('Ladies')),
              ],
              selected: {_gender},
              onSelectionChanged: (choice) => setState(() {
                _gender = choice.first;
                _level = null;
                _trainedFor.clear();
                _edits.clear();
              }),
            ),
            const SizedBox(height: 12),
          ],
          ...data.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The teachers could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(teachersProvider(_gender)),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: _content,
          ),
        ],
      ),
    );
  }

  List<Widget> _content(TeachersList list) {
    final shown = _shown(list.teachers);
    final levels = {
      for (final t in list.teachers)
        if (t.level.isNotEmpty) t.level,
    }.toList()..sort();
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return [
      ReportSearchField(
        hint: 'Search name, class code or token',
        onChanged: (value) => setState(() => _search = value),
      ),
      const SizedBox(height: 8),
      ExpansionTile(
        title: const Text('Filter and sort'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          DropdownButtonFormField<String?>(
            key: const ValueKey('level-filter'),
            initialValue: _level,
            decoration: const InputDecoration(
              labelText: 'Level they attend',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any level')),
              for (final l in levels)
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => setState(() => _level = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            key: const ValueKey('class-count-filter'),
            initialValue: _classCount,
            decoration: const InputDecoration(
              labelText: 'Classes they attend',
              isDense: true,
            ),
            items: [
              for (final e in _classCounts.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _classCount = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final l in list.levels)
                  FilterChip(
                    label: Text('Trained ${l.code}'),
                    selected: _trainedFor.contains(l.key),
                    onSelected: (on) => setState(
                      () => on
                          ? _trainedFor.add(l.key)
                          : _trainedFor.remove(l.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_Sort>(
                  key: const ValueKey('sort'),
                  initialValue: _sort,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: _Sort.name, child: Text('Name')),
                    DropdownMenuItem(value: _Sort.level, child: Text('Level')),
                    DropdownMenuItem(
                      value: _Sort.classes,
                      child: Text('Classes'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _sort = v ?? _Sort.name),
                ),
              ),
              IconButton(
                tooltip: _descending ? 'Descending' : 'Ascending',
                icon: Icon(
                  _descending ? Icons.arrow_downward : Icons.arrow_upward,
                ),
                onPressed: () => setState(() => _descending = !_descending),
              ),
            ],
          ),
        ],
      ),
      TeacherLevelLegend(levels: list.levels),
      const SizedBox(height: 8),
      Text(
        shown.length == list.teachers.length
            ? '${list.teachers.length} teachers'
            : '${shown.length} of ${list.teachers.length} teachers',
      ),
      const SizedBox(height: 8),
      if (list.teachers.isEmpty)
        const Text('There are no teachers for this gender.')
      else if (shown.isEmpty)
        const Text('No teacher matches your search.')
      else
        for (final t in shown)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _editing
                  ? null
                  : () => context.push(AppRoutes.adminTeacherPath(t.token)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      [
                        '#${t.token}',
                        if (t.level.isNotEmpty) t.level,
                        '${t.classes} ${t.classes == 1 ? 'class' : 'classes'}',
                      ].join(' · '),
                      style: muted,
                    ),
                    if (t.conducting.isNotEmpty)
                      Text('Conducts ${t.conducting.join(', ')}', style: muted),
                    const SizedBox(height: 8),
                    TeacherFlags(
                      levels: list.levels,
                      flags: _flagsOf(t),
                      onToggle: _editing ? (key) => _toggle(t, key) : null,
                      changed: _edits[t.token]?.keys.toSet() ?? const {},
                    ),
                  ],
                ),
              ),
            ),
          ),
    ];
  }
}
