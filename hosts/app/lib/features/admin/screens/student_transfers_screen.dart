import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../models/student_transfers.dart';
import '../providers/student_transfers_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Move many students between classes at once, and read the log of past moves
/// (#420). Super admin only; the server enforces `students:transfer`.
class StudentTransfersScreen extends StatelessWidget {
  const StudentTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfers & Promotions'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Move'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(children: [_MoveTab(), _HistoryTab()]),
      ),
    );
  }
}

class _MoveTab extends ConsumerStatefulWidget {
  const _MoveTab();

  @override
  ConsumerState<_MoveTab> createState() => _MoveTabState();
}

class _MoveTabState extends ConsumerState<_MoveTab> {
  int _gender = 0;
  String _level = '';
  TransferClass? _source;
  TransferClass? _destination;
  final Set<int> _chosen = {};
  String _studentQuery = '';
  String? _type;
  final _reason = TextEditingController();
  bool _moving = false;
  TransferResult? _result;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Changing the filters starts the choice again, as on the web page.
  void _resetChoice() {
    _source = null;
    _destination = null;
    _chosen.clear();
    _studentQuery = '';
    _result = null;
  }

  Future<void> _pickClass({required bool destination}) async {
    final all = ref.read(transferClassesProvider).value;
    if (all == null) return;
    final picked = await showModalBottomSheet<TransferClass>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _ClassPicker(
        title: destination ? 'To class' : 'From class',
        classes: filterTransferClasses(
          all.classes,
          gender: destination && _source != null ? _source!.gender : _gender,
          level: _level,
          activeOnly: destination,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (destination) {
        _destination = picked;
      } else {
        _source = picked;
        _chosen.clear();
        _studentQuery = '';
        _result = null;
        // A destination of the other gender would be refused.
        if (_destination != null && _destination!.gender != picked.gender) {
          _destination = null;
        }
      }
    });
  }

  Future<void> _confirmAndMove() async {
    final source = _source!;
    final destination = _destination!;
    final type = _type!;
    final count = _chosen.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${transferTypes[type]} $count student(s)?'),
        content: Text(
          'From ${source.code} to ${destination.code}. '
          'This is recorded in the transfer history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _moving = true);
    try {
      final result = await ref.read(moveStudentsProvider)(
        fromClassId: source.id,
        toClassId: destination.id,
        type: type,
        reason: _reason.text.trim(),
        tokens: _chosen.toList(),
      );
      if (!mounted) return;
      ref.invalidate(transferStudentsProvider(source.id));
      ref.invalidate(transferClassesProvider);
      setState(() {
        _result = result;
        // What did not move stays chosen, so it can be looked at or retried.
        _chosen
          ..clear()
          ..addAll(result.failed.map((f) => f.token));
      });
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } catch (_) {
      if (mounted) _say('Could not reach the server. Nothing was moved.');
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(transferClassesProvider);
    return classes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load the classes.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(transferClassesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) => _buildForm(data),
    );
  }

  Widget _buildForm(TransferClasses data) {
    final ready =
        _source != null &&
        _destination != null &&
        _type != null &&
        _chosen.isNotEmpty &&
        !_moving;

    return ListView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('All')),
                  DropdownMenuItem(value: 1, child: Text('Gents')),
                  DropdownMenuItem(value: 2, child: Text('Ladies')),
                ],
                onChanged: (v) => setState(() {
                  _gender = v ?? 0;
                  _resetChoice();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(
                  labelText: 'Level',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All')),
                  for (final l in data.levels)
                    DropdownMenuItem(value: l, child: Text(l)),
                ],
                onChanged: (v) => setState(() {
                  _level = v ?? '';
                  _resetChoice();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ClassField(
          label: 'From class',
          selected: _source,
          onTap: () => _pickClass(destination: false),
        ),
        const SizedBox(height: 12),
        _ClassField(
          label: 'To class',
          selected: _destination,
          onTap: () => _pickClass(destination: true),
        ),
        if (_source != null) ...[
          const SizedBox(height: 16),
          _buildRoster(_source!),
        ],
        const SizedBox(height: 16),
        Text('Type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final e in transferTypes.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: _type == null ? <String>{} : {_type!},
          onSelectionChanged: (s) =>
              setState(() => _type = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reason,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: ready ? _confirmAndMove : null,
          child: _moving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _chosen.isEmpty
                      ? 'Move students'
                      : 'Move ${_chosen.length} student(s)',
                ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _ResultCard(result: _result!),
        ],
      ],
    );
  }

  Widget _buildRoster(TransferClass source) {
    final roster = ref.watch(transferStudentsProvider(source.id));
    return roster.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Column(
        children: [
          const Text('Could not load the students.'),
          TextButton(
            onPressed: () =>
                ref.invalidate(transferStudentsProvider(source.id)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (students) {
        if (students.isEmpty) {
          return Text('${source.code} has no students to move.');
        }
        final shown = [
          for (final s in students)
            if (s.matches(_studentQuery)) s,
        ];
        final allShown =
            shown.isNotEmpty && shown.every((s) => _chosen.contains(s.token));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (students.first.fromDeactivation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${source.code} was deactivated. These are the students it '
                  'had at that time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search students',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _studentQuery = v),
            ),
            CheckboxListTile(
              value: allShown,
              onChanged: (v) => setState(() {
                for (final s in shown) {
                  v == true ? _chosen.add(s.token) : _chosen.remove(s.token);
                }
              }),
              title: Text('Select all (${shown.length})'),
              subtitle: Text('${_chosen.length} selected'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            for (final s in shown)
              CheckboxListTile(
                value: _chosen.contains(s.token),
                onChanged: (v) => setState(() {
                  v == true ? _chosen.add(s.token) : _chosen.remove(s.token);
                }),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(s.name),
                subtitle: Text(
                  [
                    '#${s.token}',
                    s.email,
                    s.mobile,
                    if (s.fromDeactivation) 'from deactivation',
                  ].whereType<String>().join(' · '),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ClassField extends StatelessWidget {
  const _ClassField({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final TransferClass? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: selected == null
            ? const Text('Choose a class')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${selected!.code} — ${selected!.name}'),
                  Text(
                    [
                      selected!.subtitle,
                      '${selected!.students} students',
                      if (!selected!.active) 'deactivated',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ClassPicker extends StatefulWidget {
  const _ClassPicker({required this.title, required this.classes});

  final String title;
  final List<TransferClass> classes;

  @override
  State<_ClassPicker> createState() => _ClassPickerState();
}

class _ClassPickerState extends State<_ClassPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final shown = filterTransferClasses(widget.classes, query: _query);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '${widget.title}: code, teacher, city, country',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('No classes match.'))
                  : ListView(
                      children: [
                        for (final c in shown)
                          ListTile(
                            title: Text('${c.code} — ${c.name}'),
                            subtitle: Text(
                              [
                                c.subtitle,
                                '${c.students} students',
                                if (!c.active) 'deactivated',
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            onTap: () => Navigator.pop(context, c),
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final TransferResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moved ${result.moved.length}, not moved ${result.failed.length}',
              style: textTheme.titleMedium,
            ),
            if (result.moved.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Moved', style: textTheme.titleSmall),
              for (final m in result.moved) Text(m.label),
            ],
            if (result.failed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Not moved', style: textTheme.titleSmall),
              for (final f in result.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${f.label}: ${f.reason ?? 'could not be moved'}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  final _search = TextEditingController();
  final List<TransferHistoryEntry> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    final query = _search.text.trim();
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(transferHistoryLoaderProvider)(query, page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _total = result.total;
        _page = page;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMM y, HH:mm');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search student, class, reason or admin',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _load(reset: true),
              ),
            ),
            onSubmitted: (_) => _load(reset: true),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_error!),
                TextButton(
                  onPressed: () => _load(reset: _items.isEmpty),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _items.isEmpty && !_loading && _error == null
              ? const Center(child: Text('No transfers found.'))
              : ListView(
                  children: [
                    for (final e in _items)
                      ListTile(
                        title: Text(
                          '${e.studentName} (#${e.studentToken}): '
                          '${transferTypes[e.type] ?? e.type}, '
                          '${e.fromCode} → ${e.toCode}',
                        ),
                        subtitle: Text(
                          [
                            if (e.transferredAt != null)
                              format.format(e.transferredAt!),
                            'by ${e.transferredBy}',
                            if (e.reason != null) e.reason!,
                          ].join(' · '),
                        ),
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_items.length < _total)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: () => _load(reset: false),
                          child: Text(
                            'Load more (${_items.length} of $_total)',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
