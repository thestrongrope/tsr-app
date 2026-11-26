import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/bulk_add.dart';
import 'manage_common.dart';

/// Sends the list and any choices; answers what the server did (#691).
typedef BulkAddSubmit =
    Future<BulkAddResult> Function(
      List<String> lines,
      Map<int, String> resolutions,
    );

/// Add several students at once: one per line, a name and an optional mobile
/// number. Three steps in one dialog: the list, a confirm step for lines the
/// server flagged (a name already in the class, a mobile that belongs to an
/// existing member), then the per-line result. Pops with the number added.
class BulkAddStudentsDialog extends StatefulWidget {
  final BulkAddSubmit onSubmit;

  const BulkAddStudentsDialog({super.key, required this.onSubmit});

  @override
  State<BulkAddStudentsDialog> createState() => _BulkAddStudentsDialogState();
}

enum _Step { input, confirm, result }

class _BulkAddStudentsDialogState extends State<BulkAddStudentsDialog> {
  final _text = TextEditingController();
  _Step _step = _Step.input;
  bool _busy = false;
  String? _error;
  BulkAddResult? _result;

  /// The choice per flagged line; a default until the user changes it.
  final Map<int, String> _choices = {};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Non-blank lines only, so the line numbers the server reports are the
  /// ones shown here.
  List<String> get _lines => _text.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  Future<void> _send(Map<int, String> resolutions) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(_lines, resolutions);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
        if (result.needsConfirmation) {
          _choices
            ..clear()
            ..addEntries(
              result.lines
                  .where((l) => l.needsChoice)
                  .map(
                    (l) => MapEntry(
                      l.line,
                      l.status == 'mobile_match' ? 'enrol' : 'skip',
                    ),
                  ),
            );
          _step = _Step.confirm;
        } else {
          _step = _Step.result;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = manageErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(switch (_step) {
        _Step.input => 'Add several students',
        _Step.confirm => 'Please confirm',
        _Step.result => 'Result',
      }),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: switch (_step) {
            _Step.input => _inputBody(),
            _Step.confirm => _confirmBody(),
            _Step.result => _resultBody(),
          },
        ),
      ),
      actions: _actions(),
    );
  }

  Widget _inputBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'One student per line: a name, then an optional mobile number '
          'after a comma.',
        ),
        const SizedBox(height: AppTheme.spacingSM),
        TextField(
          key: const Key('bulk-add-field'),
          controller: _text,
          minLines: 6,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Ali Khan, 9800000000\nBilal Hasan',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Nothing was added. $_error',
            key: const Key('bulk-add-error'),
            style: TextStyle(color: AppTheme.errorRed),
          ),
        ],
      ],
    );
  }

  Widget _confirmBody() {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nothing has been added yet.'),
        const SizedBox(height: AppTheme.spacingSM),
        for (final l in result.lines)
          if (l.needsChoice)
            _choiceTile(l)
          else
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Line ${l.line}: ${l.name}'),
              subtitle: Text(
                l.status == 'rejected' ? 'Not added. ${l.reason}' : 'Ready',
              ),
            ),
        if (_error != null)
          Text(
            'Nothing was added. $_error',
            key: const Key('bulk-add-error'),
            style: TextStyle(color: AppTheme.errorRed),
          ),
      ],
    );
  }

  Widget _choiceTile(BulkLineResult l) {
    final isMatch = l.status == 'mobile_match';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMatch
                ? 'Line ${l.line}: that mobile number belongs to '
                      '${l.memberName}. Enrol them instead of adding '
                      '"${l.name}"?'
                : 'Line ${l.line}: "${l.name}" is already in this class (or '
                      'repeated in your list).',
          ),
          SegmentedButton<String>(
            key: Key('bulk-add-choice-${l.line}'),
            showSelectedIcon: false,
            segments: [
              if (isMatch)
                const ButtonSegment(value: 'enrol', label: Text('Enrol them')),
              ButtonSegment(
                value: 'add',
                label: Text(isMatch ? 'Add new' : 'Add anyway'),
              ),
              const ButtonSegment(value: 'skip', label: Text('Skip')),
            ],
            selected: {_choices[l.line]!},
            onSelectionChanged: (s) =>
                setState(() => _choices[l.line] = s.first),
          ),
        ],
      ),
    );
  }

  Widget _resultBody() {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.added > 0
              ? 'Added ${result.added} student(s).'
              : 'Nobody was added. Fix the lines below and try again.',
          key: const Key('bulk-add-summary'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        for (final l in result.lines)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              l.status == 'rejected' ? Icons.error_outline : Icons.check_circle,
              color: l.status == 'rejected'
                  ? AppTheme.errorRed
                  : AppTheme.primaryGreen,
            ),
            title: Text('Line ${l.line}: ${l.name}'),
            subtitle: Text(switch (l.status) {
              'added' => 'Added',
              'enrolled' => 'Existing member enrolled',
              _ => 'Not added. ${l.reason ?? ''}',
            }),
          ),
      ],
    );
  }

  List<Widget> _actions() {
    switch (_step) {
      case _Step.input:
        return [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(0),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('bulk-add-submit'),
            onPressed: _busy || _lines.isEmpty ? null : () => _send({}),
            child: Text(_busy ? 'Adding...' : 'Add'),
          ),
        ];
      case _Step.confirm:
        return [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(0),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('bulk-add-continue'),
            onPressed: _busy ? null : () => _send(Map.of(_choices)),
            child: Text(_busy ? 'Adding...' : 'Continue'),
          ),
        ];
      case _Step.result:
        final added = _result!.added;
        return [
          if (added == 0)
            TextButton(
              key: const Key('bulk-add-back'),
              onPressed: () => setState(() => _step = _Step.input),
              child: const Text('Edit the list'),
            ),
          FilledButton(
            key: const Key('bulk-add-done'),
            onPressed: () => Navigator.of(context).pop(added),
            child: const Text('Done'),
          ),
        ];
    }
  }
}
