import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/standard_mcqs.dart';
import '../providers/standard_mcqs_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Replaces the Standard MCQs from the source sheet (#669), the mobile
/// counterpart of the web's Update MCQs page: tick the languages and levels,
/// then update. Each language and level is replaced as a whole.
///
/// The server decides what happens and says so per pair (`updated` with a quiz
/// count, or `failed` with a reason); a 403, 409 or 422 arrives as the server's
/// own words and is shown as they are.
class StandardMcqsScreen extends ConsumerStatefulWidget {
  const StandardMcqsScreen({super.key});

  @override
  ConsumerState<StandardMcqsScreen> createState() => _StandardMcqsScreenState();
}

class _StandardMcqsScreenState extends ConsumerState<StandardMcqsScreen> {
  final Set<int> _languages = {};
  final Set<int> _levels = {};

  /// True while the update is in flight, so a second tap is not a second run.
  bool _running = false;
  List<StandardMcqResult>? _results;
  String? _error;

  bool get _canUpdate =>
      !_running && _languages.isNotEmpty && _levels.isNotEmpty;

  Future<void> _update() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace the Standard MCQs?'),
        content: const Text(
          'Every question for the chosen languages and levels is replaced '
          'with what the source sheet holds now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() {
      _running = true;
      _results = null;
      _error = null;
    });
    try {
      final results = await ref
          .read(standardMcqsRepositoryProvider)
          .update(languages: _languages.toList(), levels: _levels.toList());
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'That did not work. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _group(
    String title,
    List<McqChoice> choices,
    Set<int> chosen,
    String keyPrefix,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final choice in choices)
          CheckboxListTile(
            key: Key('$keyPrefix-${choice.id}'),
            title: Text(choice.name),
            value: chosen.contains(choice.id),
            onChanged: _running
                ? null
                : (on) => setState(
                    () => on == true
                        ? chosen.add(choice.id)
                        : chosen.remove(choice.id),
                  ),
          ),
      ],
    );
  }

  Widget _result(StandardMcqResult r) {
    final text = r.updated
        ? 'Updated, ${r.quizzes ?? 0} quizzes'
        : 'Failed: ${r.reason ?? 'unknown reason'}';
    return ListTile(
      leading: Icon(
        r.updated ? Icons.check_circle_outline : Icons.error_outline,
        color: r.updated ? Colors.green : Theme.of(context).colorScheme.error,
      ),
      title: Text('${r.language}, ${r.level}'),
      subtitle: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(standardMcqSourcesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Update MCQs')),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException
                      ? e.message
                      : 'The languages and levels could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(standardMcqSourcesProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => ListView(
          padding: withTabBarInset(context, const EdgeInsets.all(16)),
          children: [
            const Text(
              'Replace the Standard MCQs from the source sheet, for every '
              'chosen language and level.',
            ),
            _group('Languages', data.languages, _languages, 'language'),
            _group('Levels', data.levels, _levels, 'level'),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('update-standard-mcqs'),
              onPressed: _canUpdate ? _update : null,
              child: _running
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Updating, this can take a minute'),
                      ],
                    )
                  : const Text('Update'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_results != null) ...[
              const SizedBox(height: 16),
              Text('Result', style: Theme.of(context).textTheme.titleMedium),
              for (final r in _results!) _result(r),
            ],
          ],
        ),
      ),
    );
  }
}
