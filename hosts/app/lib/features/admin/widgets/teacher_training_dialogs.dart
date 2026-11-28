import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/teachers.dart';
import '../providers/teachers_provider.dart';

const _generic = 'Something went wrong. Please try again.';

/// The server's words for a refusal or a rolled-back failure (neither names a
/// cause); a generic line for anything else, such as no connection.
String teacherErrorMessage(Object e) =>
    e is ApiException && {403, 404, 422, 500}.contains(e.statusCode)
    ? e.message
    : _generic;

/// Asks for the comment every batch of changes needs, then sends the batch.
/// Pops with how many teachers were changed; a refusal keeps the dialog open
/// with the comment still in it and the server's words under it.
class SaveTrainingDialog extends ConsumerStatefulWidget {
  const SaveTrainingDialog({super.key, required this.changes});

  final List<TrainingChange> changes;

  @override
  ConsumerState<SaveTrainingDialog> createState() => _SaveTrainingDialogState();
}

class _SaveTrainingDialogState extends ConsumerState<SaveTrainingDialog> {
  final _comments = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final changed = await ref.read(changeTrainingProvider)(
        changes: widget.changes,
        comments: _comments.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(changed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = teacherErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Save ${widget.changes.length} changes'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _comments,
          enabled: !_saving,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Comments'),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving || _comments.text.trim().isEmpty ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}

/// Confirms the import, then runs it. Pops with how many teachers were added.
class ImportTeachersDialog extends ConsumerStatefulWidget {
  const ImportTeachersDialog({super.key, required this.gender});

  final int gender;

  @override
  ConsumerState<ImportTeachersDialog> createState() =>
      _ImportTeachersDialogState();
}

class _ImportTeachersDialogState extends ConsumerState<ImportTeachersDialog> {
  bool _importing = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final added = await ref.read(importTeachersProvider)(
        gender: widget.gender,
      );
      if (!mounted) return;
      Navigator.of(context).pop(added);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = teacherErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import active teachers'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adds every teacher of an active class who has no training record, '
          'trained for the level they teach and the levels below it.',
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _importing ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _importing ? null : _import,
        child: const Text('Import'),
      ),
    ],
  );
}
