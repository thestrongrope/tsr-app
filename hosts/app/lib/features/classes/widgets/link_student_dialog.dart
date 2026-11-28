import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../admin/screens/enrol_by_token_details.dart';
import '../models/class_manage.dart';
import 'manage_common.dart';

typedef LinkPreviewLoader = Future<LinkPreview> Function(int memberToken);
typedef LinkSubmit =
    Future<void> Function(int memberToken, List<LinkResolution> resolutions);

/// Link an extra student to the member they really are (#1135). Two screens in
/// one dialog: a token and Find, then the member card, the extra student's
/// classes and one row per conflict. Nothing changes until Confirm, which stays
/// disabled until every conflict has a choice. Pops true once linked.
class LinkStudentDialog extends StatefulWidget {
  final String extraName;
  final LinkPreviewLoader onPreview;
  final LinkSubmit onLink;

  const LinkStudentDialog({
    super.key,
    required this.extraName,
    required this.onPreview,
    required this.onLink,
  });

  @override
  State<LinkStudentDialog> createState() => _LinkStudentDialogState();
}

class _LinkStudentDialogState extends State<LinkStudentDialog> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;
  LinkPreview? _preview;

  /// `kind:itemId` to `member` or `extra`.
  final Map<String, String> _choices = {};

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  int? get _memberToken => int.tryParse(_token.text.trim());

  String _key(LinkConflict c) => '${c.kind}:${c.itemId}';

  bool get _allChosen =>
      _preview!.conflicts.every((c) => _choices.containsKey(_key(c)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on LinkRecordsChanged catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = e.preview;
        _choices.clear();
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = manageErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _find() async {
    final token = _memberToken;
    if (token == null) return;
    await _run(() async {
      final preview = await widget.onPreview(token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _choices.clear();
      });
    });
  }

  Future<void> _confirm() async {
    final preview = _preview!;
    final resolutions = [
      for (final c in preview.conflicts)
        LinkResolution(
          kind: c.kind,
          itemId: c.itemId,
          keep: _choices[_key(c)]!,
        ),
    ];
    await _run(() async {
      await widget.onLink(preview.member.token, resolutions);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      title: const Text(_linkLabel),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview == null) ..._findBody() else ..._previewBody(preview),
              if (_error != null) ...[
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  _error!,
                  key: const Key('link-error'),
                  style: TextStyle(color: AppTheme.errorRed),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (preview == null)
          FilledButton(
            key: const Key('link-find'),
            onPressed: _busy || _memberToken == null ? null : _find,
            child: const Text('Find'),
          )
        else
          FilledButton(
            key: const Key('link-confirm'),
            onPressed: _busy || !_allChosen ? null : _confirm,
            child: const Text('Confirm'),
          ),
      ],
    );
  }

  List<Widget> _findBody() => [
    Text('Enter the token number of the member ${widget.extraName} really is.'),
    const SizedBox(height: AppTheme.spacingSM),
    TextField(
      key: const Key('link-token-field'),
      controller: _token,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Member token',
        border: OutlineInputBorder(),
      ),
    ),
  ];

  List<Widget> _previewBody(LinkPreview preview) => [
    MemberDetailsCard(member: preview.member),
    const SizedBox(height: AppTheme.spacingMD),
    Text(
      '${preview.extra.name} (token ${preview.extra.token}) is in:',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    if (preview.extra.classes.isEmpty) const Text('No classes.'),
    for (final c in preview.extra.classes)
      Text('${c.code}: ${c.name}${c.current ? '' : ' (left)'}'),
    const SizedBox(height: AppTheme.spacingSM),
    const Text(
      'Confirming moves all their records to the member and removes '
      'the extra student. This cannot be undone.',
    ),
    if (preview.conflicts.isNotEmpty) ...[
      const SizedBox(height: AppTheme.spacingMD),
      const Text(
        'Both have a record for these. Choose which to keep.',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      for (final c in preview.conflicts) _conflictRow(c),
    ],
  ];

  Widget _conflictRow(LinkConflict c) {
    String side(Map<String, dynamic> fields) =>
        fields.entries.map((e) => '${e.key}: ${e.value ?? '-'}').join(', ');
    return Padding(
      key: Key('link-choice-${c.kind}-${c.itemId}'),
      padding: const EdgeInsets.only(top: AppTheme.spacingSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [c.kind, if (c.classCode != null) c.classCode, c.label].join(' · '),
          ),
          Text('Member: ${side(c.member)}'),
          Text('Extra student: ${side(c.extra)}'),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'member', label: Text("Keep member's")),
              ButtonSegment(
                value: 'extra',
                label: Text("Keep extra student's"),
              ),
            ],
            selected: {if (_choices[_key(c)] != null) _choices[_key(c)]!},
            onSelectionChanged: (chosen) => setState(() {
              if (chosen.isEmpty) {
                _choices.remove(_key(c));
              } else {
                _choices[_key(c)] = chosen.first;
              }
            }),
          ),
        ],
      ),
    );
  }
}

const _linkLabel = 'Link to an existing member';
