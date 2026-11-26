import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/mcq_manage.dart';
import '../providers/mcq_manage_provider.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Copy a quiz between classes without managing either: the app's version of
/// the web's Copy MCQ page (`copy_spot_quiz.php`). Pick the class to copy
/// from, then a topic, then a quiz, then the class to copy to. The server
/// lists only the classes the member holds `mcqs:copy` for.
class McqCopyPickerScreen extends ConsumerStatefulWidget {
  const McqCopyPickerScreen({super.key});

  @override
  ConsumerState<McqCopyPickerScreen> createState() =>
      _McqCopyPickerScreenState();
}

class _McqCopyPickerScreenState extends ConsumerState<McqCopyPickerScreen> {
  int? _fromClassId;
  String? _topic;
  int? _quizId;
  int? _toClassId;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(mcqCopyClassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Copy MCQ')),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(userMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (classes) => classes.isEmpty
            ? const Center(child: Text('No classes to copy between.'))
            : _buildForm(classes),
      ),
    );
  }

  Widget _buildForm(List<McqCopyClass> classes) {
    final fromId = _fromClassId;
    final topic = _topic;
    final quizId = _quizId;

    return ListView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      children: [
        _field<int>(
          label: 'From class',
          value: _fromClassId,
          items: {for (final c in classes) c.id: c.label},
          onChanged: (id) => setState(() {
            _fromClassId = id;
            _topic = null;
            _quizId = null;
          }),
        ),
        if (fromId != null)
          ref
              .watch(mcqCopyTopicsProvider(fromId))
              .when(
                loading: _loading,
                error: (e, _) => _error(e),
                data: (topics) => _field<String>(
                  label: 'Topic',
                  value: _topic,
                  items: {for (final t in topics) t: t},
                  onChanged: (t) => setState(() {
                    _topic = t;
                    _quizId = null;
                  }),
                ),
              ),
        if (fromId != null && topic != null)
          ref
              .watch(mcqCopyQuizzesProvider((classId: fromId, topic: topic)))
              .when(
                loading: _loading,
                error: (e, _) => _error(e),
                data: (quizzes) => _field<int>(
                  label: 'MCQ',
                  value: _quizId,
                  items: {
                    for (final q in quizzes)
                      q.id: '${q.name} - ${_shortDate(q.createdAt)}',
                  },
                  onChanged: (id) => setState(() => _quizId = id),
                ),
              ),
        if (quizId != null) ...[
          _field<int>(
            label: 'To class',
            value: _toClassId,
            items: {
              for (final c in classes)
                if (c.id != fromId) c.id: c.label,
            },
            onChanged: (id) => setState(() => _toClassId = id),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _toClassId == null || _isSubmitting ? null : _copy,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.copy_rounded),
            label: Text(_isSubmitting ? 'Copying…' : 'Copy Quiz'),
          ),
        ],
      ],
    );
  }

  Widget _field<T>({
    required String label,
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$label-$value'),
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _loading() => const Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _error(Object e) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      userMessage(e),
      style: const TextStyle(color: AppTheme.errorRed),
    ),
  );

  /// The date part of an ISO timestamp, "2026-10-01".
  String _shortDate(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;

  Future<void> _copy() async {
    final quizId = _quizId;
    final toClassId = _toClassId;
    if (quizId == null || toClassId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(mcqManageRepositoryProvider).copyQuiz(quizId, toClassId);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: 'Quiz copied successfully');
      setState(() {
        _quizId = null;
        _toClassId = null;
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
