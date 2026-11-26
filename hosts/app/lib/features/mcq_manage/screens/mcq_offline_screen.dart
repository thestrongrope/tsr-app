import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/mcq_offline.dart';
import '../providers/mcq_manage_provider.dart';

/// Records the answers of students who take an MCQ without a phone (#409):
/// choose the students, step through the questions marking who got each one
/// right, keep the result on the device, and submit when ready. Only right
/// answers are marked; a question left unmarked counts as wrong.
class McqOfflineScreen extends ConsumerStatefulWidget {
  final int quizId;

  const McqOfflineScreen({super.key, required this.quizId});

  @override
  ConsumerState<McqOfflineScreen> createState() => _McqOfflineScreenState();
}

class _McqOfflineScreenState extends ConsumerState<McqOfflineScreen> {
  bool _showAll = false;
  bool _submitting = false;
  final Set<int> _chosen = {};

  // Set while stepping through the questions.
  List<OfflineStudent>? _recording;
  int _step = 0;
  final Map<int, Set<int>> _marks = {};

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareSheet(String name) async {
    try {
      await ref.read(shareMcqSheetProvider)(widget.quizId, name);
    } catch (_) {
      if (mounted) _say('Could not get the question sheet.');
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await ref
        .read(offlinePendingProvider(widget.quizId).notifier)
        .submit();
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.error != null) {
      _say('Could not submit. Your answers are still saved on this device.');
    } else if (result.conflicts.isNotEmpty) {
      ref.invalidate(mcqOfflineProvider(widget.quizId));
      _say(
        '${result.conflicts.length} student(s) had already submitted and keep '
        'their answers. The rest are still saved here; submit again.',
      );
    } else {
      ref.invalidate(mcqOfflineProvider(widget.quizId));
      ref.invalidate(mcqScoresProvider(widget.quizId));
      _say('Submitted answers for ${result.saved} student(s).');
    }
  }

  Future<void> _finishRecording() async {
    final recording = _recording!;
    await ref.read(offlinePendingProvider(widget.quizId).notifier).record({
      for (final s in recording) s.token: _marks[s.token] ?? <int>{},
    });
    if (!mounted) return;
    setState(() {
      _recording = null;
      _chosen.clear();
      _marks.clear();
    });
    _say('Saved on this device for ${recording.length} student(s).');
  }

  @override
  Widget build(BuildContext context) {
    // Watched in both stages so the pending list is not disposed while the
    // teacher steps through the questions.
    ref.watch(offlinePendingProvider(widget.quizId));
    final async = ref.watch(mcqOfflineProvider(widget.quizId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Offline answers')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Offline answers')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load this MCQ.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(mcqOfflineProvider(widget.quizId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) =>
          _recording == null ? _buildPicker(data) : _buildStepper(data),
    );
  }

  Widget _buildPicker(McqOfflineData data) {
    final pending = ref.watch(offlinePendingProvider(widget.quizId));
    final shown = data.students
        .where((s) => _showAll || s.isOffline || s.submitted)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(data.quizName.isEmpty ? 'Offline answers' : data.quizName),
        actions: [
          IconButton(
            tooltip: 'Question sheet',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _shareSheet(data.quizName),
          ),
        ],
      ),
      body: Column(
        children: [
          if (pending.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pending.length} student(s) saved on this device, '
                      'not yet submitted',
                    ),
                  ),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Submit ${pending.length}'),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('Show all students'),
            subtitle: const Text('Otherwise only students without a phone'),
            value: _showAll,
            onChanged: (v) => setState(() => _showAll = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No students without a phone.'))
                : ListView(
                    children: [
                      for (final s in shown)
                        CheckboxListTile(
                          value: _chosen.contains(s.token),
                          onChanged: s.submitted
                              ? null
                              : (v) => setState(() {
                                  v == true
                                      ? _chosen.add(s.token)
                                      : _chosen.remove(s.token);
                                }),
                          title: Text(s.name),
                          subtitle: s.submitted
                              ? const Text('Already submitted')
                              : pending.containsKey(s.token)
                              ? const Text('Saved on this device')
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _chosen.isEmpty || data.questions.isEmpty
                ? null
                : () => setState(() {
                    _recording = [
                      for (final s in data.students)
                        if (_chosen.contains(s.token)) s,
                    ];
                    _step = 0;
                    _marks.clear();
                  }),
            child: Text(
              _chosen.isEmpty
                  ? 'Choose students'
                  : 'Record answers (${_chosen.length})',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(McqOfflineData data) {
    final students = _recording!;
    final question = data.questions[_step];
    final isLast = _step == data.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_step + 1} of ${data.questions.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Back to students',
          onPressed: () => setState(() => _recording = null),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final option in question.options)
            ListTile(
              dense: true,
              leading: Icon(
                option.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: option.isCorrect ? AppTheme.primaryGreen : null,
              ),
              title: Text(option.text),
            ),
          const Divider(height: 32),
          Text(
            'Who answered correctly?',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final s in students)
            CheckboxListTile(
              value: (_marks[s.token] ?? const <int>{}).contains(question.id),
              onChanged: (v) => setState(() {
                final marks = _marks.putIfAbsent(s.token, () => <int>{});
                v == true ? marks.add(question.id) : marks.remove(question.id);
              }),
              title: Text(s.name),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_step > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: isLast
                    ? _finishRecording
                    : () => setState(() => _step++),
                child: Text(isLast ? 'Save on this device' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
