import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/class_create.dart';
import '../models/class_manage.dart';
import '../providers/class_create_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

const _generic = 'Something went wrong. Please try again.';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Create a class (#636), the mobile counterpart of web's create-class pages:
/// gender, level, location, city, country, a teacher, tags and one or more
/// weekly slots. Pops with the new class's id. The server checks the permission
/// for the chosen gender and refuses a repeat of the same class within a minute.
class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _location = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  int? _gender;
  int? _levelId;
  ManageOption? _teacher;
  final Set<int> _tags = {};
  final List<ManageSchedule> _slots = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _location.dispose();
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  bool get _ready =>
      _gender != null &&
      _levelId != null &&
      _location.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _country.text.trim().isNotEmpty &&
      _teacher != null &&
      _slots.isNotEmpty &&
      !_submitting;

  Future<void> _create() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await ref.read(createClassProvider)(
        gender: _gender!,
        levelId: _levelId!,
        location: _location.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
        teacher: _teacher!.id,
        tags: _tags.toList(),
        schedules: _slots,
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // The server's words for a refusal name no cause beyond the field.
        _error =
            e is ApiException && {403, 409, 422, 500}.contains(e.statusCode)
            ? e.message
            : _generic;
      });
    }
  }

  Future<void> _pickTeacher() async {
    final picked = await showDialog<ManageOption>(
      context: context,
      builder: (_) => _TeacherSearchDialog(gender: _gender!),
    );
    if (picked != null) setState(() => _teacher = picked);
  }

  void _addSlot(CreateClassOptions options) {
    final zones = options.timezones.map((t) => t.timezone);
    setState(
      () => _slots.add(
        ManageSchedule(
          day: 1,
          hour: 19,
          minute: 0,
          timezone: _slots.isNotEmpty
              ? _slots.first.timezone
              : zones.contains('Asia/Kolkata')
              ? 'Asia/Kolkata'
              : zones.first,
        ),
      ),
    );
  }

  Widget _text(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
    child: TextField(
      controller: controller,
      enabled: !_submitting,
      maxLength: 300,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _form(CreateClassOptions options, List<ManageOption> levels) {
    // A caller who may create for one gender is not asked.
    _gender ??= options.genders.length == 1 ? options.genders.first : null;
    return ListView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.spacingLG),
      ),
      children: [
        if (options.genders.length > 1) ...[
          SegmentedButton<int>(
            emptySelectionAllowed: true,
            segments: [
              for (final g in options.genders)
                ButtonSegment(
                  value: g,
                  label: Text(g == 1 ? 'Gents' : 'Ladies'),
                ),
            ],
            selected: {?_gender},
            onSelectionChanged: _submitting
                ? null
                : (choice) => setState(() {
                    _gender = choice.first;
                    // The teacher pool depends on the gender.
                    _teacher = null;
                  }),
          ),
          const SizedBox(height: AppTheme.spacingMD),
        ],
        DropdownButtonFormField<int>(
          initialValue: _levelId,
          decoration: const InputDecoration(
            labelText: 'Level',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final l in levels)
              DropdownMenuItem(value: l.id, child: Text(l.name)),
          ],
          onChanged: _submitting ? null : (v) => setState(() => _levelId = v),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _text('Location', _location),
        _text('City', _city),
        _text('Country', _country),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Teacher'),
          subtitle: Text(
            _teacher?.name ??
                (_gender == null ? 'Choose a gender first' : 'Not chosen'),
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: _gender != null && !_submitting,
          onTap: _pickTeacher,
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTheme.spacingSM),
        Wrap(
          spacing: AppTheme.spacingSM,
          children: [
            for (final tag in options.tags)
              FilterChip(
                label: Text(tag.name),
                selected: _tags.contains(tag.id),
                onSelected: _submitting
                    ? null
                    : (on) => setState(
                        () => on ? _tags.add(tag.id) : _tags.remove(tag.id),
                      ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLG),
        Text('Weekly slots', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTheme.spacingSM),
        for (var i = 0; i < _slots.length; i++)
          _SlotCard(
            key: ValueKey('slot-$i-${_slots[i].hashCode}'),
            slot: _slots[i],
            timezones: options.timezones,
            enabled: !_submitting,
            onChanged: (slot) => setState(() => _slots[i] = slot),
            onRemove: () => setState(() => _slots.removeAt(i)),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add a day'),
          onPressed: _submitting ? null : () => _addSlot(options),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingSM),
          Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
        ],
        const SizedBox(height: AppTheme.spacingLG),
        FilledButton(
          onPressed: _ready ? _create : null,
          child: Text(_submitting ? 'Creating…' : 'Create class'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(createClassOptionsProvider);
    final levels = ref.watch(classLevelsProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('New class')),
      body: switch ((options, levels)) {
        (AsyncData(value: final o), AsyncData(value: final l)) => _form(o, l),
        (AsyncError(), _) || (_, AsyncError()) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The form could not be loaded.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(createClassOptionsProvider);
                  ref.invalidate(classLevelsProvider);
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  final ManageSchedule slot;
  final List<ManageTimezone> timezones;
  final bool enabled;
  final ValueChanged<ManageSchedule> onChanged;
  final VoidCallback onRemove;

  const _SlotCard({
    super.key,
    required this.slot,
    required this.timezones,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: slot.day,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(_weekdays[d - 1]),
                        ),
                    ],
                    onChanged: enabled
                        ? (v) => onChanged(slot.copyWith(day: v ?? slot.day))
                        : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove this day',
                  onPressed: enabled ? onRemove : null,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: slot.hour,
                    decoration: const InputDecoration(labelText: 'Hour'),
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text(h.toString().padLeft(2, '0')),
                        ),
                    ],
                    onChanged: enabled
                        ? (v) => onChanged(slot.copyWith(hour: v ?? slot.hour))
                        : null,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: slot.minute,
                    decoration: const InputDecoration(labelText: 'Minute'),
                    items: [
                      for (final m in const [0, 15, 30, 45])
                        DropdownMenuItem(
                          value: m,
                          child: Text(m.toString().padLeft(2, '0')),
                        ),
                    ],
                    onChanged: enabled
                        ? (v) =>
                              onChanged(slot.copyWith(minute: v ?? slot.minute))
                        : null,
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: slot.timezone,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Timezone'),
              items: [
                for (final t in timezones)
                  DropdownMenuItem(
                    value: t.timezone,
                    child: Text(t.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: enabled
                  ? (v) =>
                        onChanged(slot.copyWith(timezone: v ?? slot.timezone))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherSearchDialog extends ConsumerStatefulWidget {
  final int gender;

  const _TeacherSearchDialog({required this.gender});

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
      final found = await ref.read(searchNewClassTeachersProvider)(
        widget.gender,
        query.trim(),
      );
      if (mounted) setState(() => _results = found);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : _generic);
      }
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
                  style: const TextStyle(color: AppTheme.errorRed),
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
