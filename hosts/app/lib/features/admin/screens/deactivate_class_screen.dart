import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../reports/widgets/report_search.dart';
import '../models/deactivated_classes.dart';
import '../providers/deactivated_classes_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// What the deactivate screen hands back when the list behind it is out of date:
/// the class was deactivated, by this person or by someone else first.
class DeactivationOutcome {
  const DeactivationOutcome(this.message, {required this.byYou});

  final String message;
  final bool byYou;
}

const _generic = 'Something went wrong. Please try again.';

/// Deactivate a class (#618): choose an active class, a type, the date it takes
/// effect and a reason, then confirm. The server does it all in one go or not at
/// all, and says why when it will not.
class DeactivateClassScreen extends ConsumerStatefulWidget {
  const DeactivateClassScreen({super.key});

  @override
  ConsumerState<DeactivateClassScreen> createState() =>
      _DeactivateClassScreenState();
}

class _DeactivateClassScreenState extends ConsumerState<DeactivateClassScreen> {
  static const _maxReason = 300;
  static final _day = DateFormat('yyyy-MM-dd');

  final _reason = TextEditingController();
  String _query = '';
  DeactivationCandidate? _chosen;
  String _type = 'completed';
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready =>
      _chosen != null && _reason.text.trim().isNotEmpty && !_submitting;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2021),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _confirm() async {
    final chosen = _chosen;
    if (chosen == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate this class?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chosen.code,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (chosen.summary.isNotEmpty) Text(chosen.summary),
            const SizedBox(height: 12),
            Text(
              chosen.students == 1
                  ? '1 student will be removed from it.'
                  : '${chosen.students} students will be removed from it.',
            ),
            const SizedBox(height: 8),
            const Text('This cannot be undone from the app.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deactivate(chosen);
  }

  Future<void> _deactivate(DeactivationCandidate chosen) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(deactivateClassProvider)(
        classId: chosen.id,
        type: _type,
        effectiveDate: _day.format(_date),
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(DeactivationOutcome('${chosen.code} deactivated.', byYou: true));
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 409) {
        Navigator.of(context).pop(DeactivationOutcome(e.message, byYou: false));
        return;
      }
      setState(() {
        _submitting = false;
        // The server's words for a refusal or a rolled-back failure: neither
        // names a cause.
        _error =
            e is ApiException && {403, 404, 422, 500}.contains(e.statusCode)
            ? e.message
            : _generic;
      });
    }
  }

  List<Widget> _picker() {
    final chosen = _chosen;
    if (chosen != null) {
      return [
        Card(
          child: ListTile(
            title: Text(
              chosen.code,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                if (chosen.summary.isNotEmpty) chosen.summary,
                '${chosen.students} students',
              ].join(' · '),
            ),
            trailing: TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                      _chosen = null;
                      _query = '';
                    }),
              child: const Text('Change'),
            ),
          ),
        ),
      ];
    }

    final candidates = ref.watch(deactivationCandidatesProvider);
    return [
      ReportSearchField(
        hint: 'Search by code, level, teacher or city',
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: 8),
      ...candidates.when(
        loading: () => const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (_, _) => [
          const Text('The classes could not be loaded.'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () => ref.invalidate(deactivationCandidatesProvider),
              child: const Text('Try again'),
            ),
          ),
        ],
        data: (all) {
          if (all.isEmpty) return const [Text('There are no active classes.')];
          final matches = [
            for (final c in all)
              if (matchesSearch(_query, c.searchFields)) c,
          ].take(50).toList();
          if (matches.isEmpty) return const [Text('No class matches.')];
          return [
            for (final c in matches)
              Card(
                child: ListTile(
                  title: Text(c.code),
                  subtitle: Text(
                    [
                      if (c.summary.isNotEmpty) c.summary,
                      '${c.students} students',
                    ].join(' · '),
                  ),
                  onTap: () => setState(() => _chosen = c),
                ),
              ),
          ];
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Deactivate a class')),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          Text(
            'Deactivating a class makes it inactive, removes its active '
            'students and its schedules. This cannot be undone from the app.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
          ),
          const SizedBox(height: 16),
          Text('Class', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._picker(),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'completed', label: Text('Completed')),
              ButtonSegment(value: 'shutdown', label: Text('Shutdown')),
            ],
            selected: {_type},
            onSelectionChanged: _submitting
                ? null
                : (choice) => setState(() => _type = choice.first),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Effective ${_day.format(_date)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            enabled: !_submitting,
            maxLength: _maxReason,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Why is this class being deactivated?',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: _ready ? _confirm : null,
            child: Text(_submitting ? 'Deactivating…' : 'Deactivate class'),
          ),
        ],
      ),
    );
  }
}
