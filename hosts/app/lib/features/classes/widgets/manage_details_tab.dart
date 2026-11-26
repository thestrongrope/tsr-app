import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/class_manage.dart';
import '../providers/class_manage_provider.dart';
import 'manage_common.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Details tab of the manage-a-class screen: the class fields web's edit page
/// lets an admin change. Code, name, level and gender are shown, not edited.
class ManageDetailsTab extends ConsumerWidget {
  final int classId;

  const ManageDetailsTab({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classManageProvider(classId));
    final payload = state.payload!;
    final draft = state.draft!;
    final notifier = ref.read(classManageProvider(classId).notifier);
    final info = payload.classInfo;
    final lookups = payload.lookups;

    // A new payload (first load, after a save) gives every field its initial
    // value again; typing changes the draft without rebuilding the field.
    final fieldKey = ObjectKey(payload);

    Widget text(
      String label,
      String? value,
      ClassDraft Function(ClassDraft d, String v) apply, {
      int maxLines = 1,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
        child: TextFormField(
          key: ValueKey('$label-${fieldKey.hashCode}'),
          initialValue: value ?? '',
          maxLines: maxLines,
          maxLength: 300,
          decoration: AppTheme.dropdownDecoration(
            label: label,
          ).copyWith(counterText: ''),
          onChanged: (v) => notifier.editDraft((d) => apply(d, v)),
        ),
      );
    }

    return ListView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          AppTheme.spacingLG,
          AppTheme.screenPadding,
          AppTheme.spacing3XL,
        ),
      ),
      children: [
        AppSurfaceCard(
          child: Column(
            children: [
              ManageFact(label: 'Class', value: '${info.code} · ${info.name}'),
              ManageFact(label: 'Level', value: info.levelName),
              ManageFact(label: 'Gender', value: info.genderName),
              if (info.joinUrl != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Join link'),
                  subtitle: Text(info.joinUrl!),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copy',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: info.joinUrl!),
                      );
                      if (context.mounted) {
                        showManageMessage(context, 'Link copied');
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Class details'),
        const SizedBox(height: AppTheme.spacingMD),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey('language-${fieldKey.hashCode}'),
                initialValue:
                    lookups.languages.any((l) => l.id == draft.languageId)
                    ? draft.languageId
                    : null,
                decoration: AppTheme.dropdownDecoration(label: 'Language'),
                items: [
                  for (final l in lookups.languages)
                    DropdownMenuItem(value: l.id, child: Text(l.name)),
                ],
                onChanged: (v) =>
                    notifier.editDraft((d) => d.copyWith(languageId: v)),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              _StartedOn(
                value: draft.startedOn,
                onChanged: (v) =>
                    notifier.editDraft((d) => d.copyWith(startedOn: v)),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Offline', label: Text('Offline')),
                    ButtonSegment(value: 'Online', label: Text('Online')),
                  ],
                  selected: {draft.format},
                  onSelectionChanged: (s) =>
                      notifier.editDraft((d) => d.copyWith(format: s.first)),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              text(
                'Address',
                draft.address,
                (d, v) => d.copyWith(address: v),
                maxLines: 3,
              ),
              text('City', draft.city, (d, v) => d.copyWith(city: v)),
              text('Country', draft.country, (d, v) => d.copyWith(country: v)),
              text(
                'Location',
                draft.location,
                (d, v) => d.copyWith(location: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Teacher'),
        const SizedBox(height: AppTheme.spacingMD),
        _TeacherField(classId: classId, draft: draft),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Tags'),
        const SizedBox(height: AppTheme.spacingMD),
        AppSurfaceCard(
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppTheme.spacingSM,
              runSpacing: AppTheme.spacingSM,
              children: [
                for (final tag in lookups.tags)
                  FilterChip(
                    label: Text(tag.name),
                    selected: draft.tags.contains(tag.id),
                    onSelected: (on) => notifier.editDraft(
                      (d) => d.copyWith(
                        tags: on
                            ? [...d.tags, tag.id]
                            : d.tags.where((t) => t != tag.id).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StartedOn extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _StartedOn({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: AppTheme.dropdownDecoration(label: 'Started on'),
      child: Row(
        children: [
          Expanded(child: Text(value ?? 'Not set')),
          TextButton(
            onPressed: () async {
              final initial = DateTime.tryParse(value ?? '') ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(manageDate(picked));
            },
            child: const Text('Change'),
          ),
          if (value != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}

class _TeacherField extends ConsumerWidget {
  final int classId;
  final ClassDraft draft;

  const _TeacherField({required this.classId, required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(draft.teacherName ?? 'Token ${draft.teacher}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showDialog<ManageOption>(
            context: context,
            builder: (_) => _TeacherSearchDialog(classId: classId),
          );
          if (picked == null) return;
          ref
              .read(classManageProvider(classId).notifier)
              .editDraft(
                (d) => d.copyWith(teacher: picked.id, teacherName: picked.name),
              );
        },
      ),
    );
  }
}

class _TeacherSearchDialog extends ConsumerStatefulWidget {
  final int classId;

  const _TeacherSearchDialog({required this.classId});

  @override
  ConsumerState<_TeacherSearchDialog> createState() =>
      _TeacherSearchDialogState();
}

class _TeacherSearchDialogState extends ConsumerState<_TeacherSearchDialog> {
  List<ManageOption> _results = const [];
  bool _searching = false;
  String? _error;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await ref
          .read(classManageProvider(widget.classId).notifier)
          .searchTeachers(query.trim());
      if (mounted) setState(() => _results = found);
    } catch (e) {
      if (mounted) setState(() => _error = manageErrorText(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose a teacher'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name or token',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              onChanged: _search,
            ),
            if (_searching) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppTheme.errorRed),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in _results)
                    ListTile(
                      title: Text(t.name),
                      subtitle: Text('Token ${t.id}'),
                      onTap: () => Navigator.of(context).pop(t),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
