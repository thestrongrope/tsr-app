import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/app_error_view.dart';
import '../models/class_access.dart';
import '../providers/class_access_provider.dart';

const maxClassAccessReason = 300;

/// Shown when the member changed under the admin; the screen reloads them.
const memberChangedMessage =
    'This member was just changed by someone else. '
    'Open them again to see the current access.';

const _cannotSave = 'This cannot be saved right now. Nothing was changed.';

/// What to tell the admin when a write failed. A refusal the server explained
/// keeps its words; a network or server failure says nothing changed.
String classAccessSaveFailure(Object error) {
  if (error is ApiException && error.isClientError && error.statusCode != 408) {
    return userMessage(error);
  }
  return _cannotSave;
}

enum AddAccessOutcome { saved, memberChanged }

/// Choose the gender and levels, see the classes they reach, give a reason and
/// confirm. The preview's class ids go back with the request, so the server can
/// tell when the classes changed since they were shown.
class AddClassAccessSheet extends ConsumerStatefulWidget {
  const AddClassAccessSheet({
    super.key,
    required this.token,
    required this.version,
    required this.onWritten,
  });

  final int token;
  final String version;

  /// Called once the server has answered a write that reached it (saved, or
  /// the member had changed), even if the sheet was dismissed meanwhile, so
  /// the screen can read the member again.
  final VoidCallback onWritten;

  @override
  ConsumerState<AddClassAccessSheet> createState() =>
      _AddClassAccessSheetState();
}

class _AddClassAccessSheetState extends ConsumerState<AddClassAccessSheet> {
  final _reason = TextEditingController();
  final _levels = <int>{};
  final _cities = <String>{};
  final _countries = <String>{};
  final _tags = <String>{};
  int? _gender;
  ClassPreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _chooseGender(int id) => setState(() {
    _gender = id;
    _preview = null;
    _error = null;
  });

  void _toggleLevel(int id, bool on) => setState(() {
    on ? _levels.add(id) : _levels.remove(id);
    _preview = null;
    _error = null;
  });

  void _toggleName(Set<String> chosen, String name, bool on) => setState(() {
    on ? chosen.add(name) : chosen.remove(name);
    _preview = null;
    _error = null;
  });

  List<AccessFilter> get _filters => [
    AccessFilter('level', _levels.toList()..sort()),
    if (_cities.isNotEmpty) AccessFilter('city', _cities.toList()..sort()),
    if (_countries.isNotEmpty)
      AccessFilter('country', _countries.toList()..sort()),
    if (_tags.isNotEmpty) AccessFilter('tag', _tags.toList()..sort()),
  ];

  Future<void> _showPreview(int gender) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await ref.read(previewAccessProvider)(
        gender: gender,
        filters: _filters,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(int gender, ClassPreview shown) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(grantAccessProvider)(
        token: widget.token,
        gender: gender,
        filters: _filters,
        reason: _reason.text.trim(),
        version: widget.version,
        previewHash: shown.previewHash,
      );
      widget.onWritten();
      if (mounted) Navigator.of(context).pop(AddAccessOutcome.saved);
    } on PreviewChanged catch (changed) {
      if (!mounted) return;
      setState(() {
        _preview = changed.preview;
        _error =
            'The classes changed since the preview. Check the new list, '
            'then add again.';
      });
    } on MemberChanged {
      widget.onWritten();
      if (mounted) Navigator.of(context).pop(AddAccessOutcome.memberChanged);
    } catch (e) {
      if (mounted) setState(() => _error = classAccessSaveFailure(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(accessOptionsProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppTheme.spacingLG,
          right: AppTheme.spacingLG,
          top: AppTheme.spacingLG,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLG,
        ),
        child: options.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTheme.spacingXL),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(accessOptionsProvider),
          ),
          data: _form,
        ),
      ),
    );
  }

  Widget _form(AccessOptions options) {
    final theme = Theme.of(context);
    if (options.genders.isEmpty) {
      return const Text('Your access does not reach any gender.');
    }
    final gender =
        _gender ??
        (options.genders.length == 1 ? options.genders.first.id : null);
    final preview = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add class access', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingMD),
        Text('Gender', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppTheme.spacingSM),
        if (options.genders.length == 1)
          Text(options.genders.first.name)
        else
          Wrap(
            spacing: AppTheme.spacingSM,
            children: [
              for (final g in options.genders)
                ChoiceChip(
                  label: Text(g.name),
                  selected: gender == g.id,
                  onSelected: (_) => _chooseGender(g.id),
                ),
            ],
          ),
        const SizedBox(height: AppTheme.spacingMD),
        Text('Levels', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppTheme.spacingSM),
        Wrap(
          spacing: AppTheme.spacingSM,
          children: [
            for (final l in options.levels)
              FilterChip(
                label: Text(l.name),
                selected: _levels.contains(l.id),
                onSelected: (on) => _toggleLevel(l.id, on),
              ),
          ],
        ),
        ..._nameChoices('City', options.cities, _cities),
        ..._nameChoices('Country', options.countries, _countries),
        ..._nameChoices('Tag', options.tags, _tags),
        const SizedBox(height: AppTheme.spacingMD),
        OutlinedButton(
          onPressed: gender == null || _levels.isEmpty || _busy
              ? null
              : () => _showPreview(gender),
          child: const Text('Preview classes'),
        ),
        if (preview != null && gender != null) ..._confirm(gender, preview),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingSM),
          Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
        ],
      ],
    );
  }

  /// An optional chip row for one name field; nothing when there is nothing to choose.
  List<Widget> _nameChoices(
    String label,
    List<String> names,
    Set<String> chosen,
  ) {
    if (names.isEmpty) return const [];
    final theme = Theme.of(context);
    return [
      const SizedBox(height: AppTheme.spacingMD),
      Text('$label (optional)', style: theme.textTheme.titleSmall),
      const SizedBox(height: AppTheme.spacingSM),
      Wrap(
        spacing: AppTheme.spacingSM,
        children: [
          for (final n in names)
            FilterChip(
              label: Text(n),
              selected: chosen.contains(n),
              onSelected: (on) => _toggleName(chosen, n, on),
            ),
        ],
      ),
    ];
  }

  List<Widget> _confirm(int gender, ClassPreview preview) {
    final theme = Theme.of(context);
    if (preview.classes.isEmpty) {
      return [
        const SizedBox(height: AppTheme.spacingMD),
        const Text('This reaches no class. Choose other levels or places.'),
      ];
    }
    final more = preview.count - preview.classes.length;
    return [
      const SizedBox(height: AppTheme.spacingMD),
      Text(
        'Reaches ${preview.count} ${preview.count == 1 ? 'class' : 'classes'}',
        style: theme.textTheme.titleSmall,
      ),
      for (final c in preview.classes)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(c.name),
          subtitle: Text(c.code),
        ),
      if (more > 0) Text('and $more more'),
      const SizedBox(height: AppTheme.spacingMD),
      TextField(
        controller: _reason,
        maxLength: maxClassAccessReason,
        maxLines: 2,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Why is this being added?',
        ),
      ),
      const SizedBox(height: AppTheme.spacingSM),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _reason.text.trim().isEmpty || _busy
              ? null
              : () => _add(gender, preview),
          child: const Text('Add access'),
        ),
      ),
    ];
  }
}
