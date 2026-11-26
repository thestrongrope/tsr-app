import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/class_manage.dart';
import '../providers/class_manage_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Schedule tab: the class's weekly slots, each with its day, time, timezone
/// and syllabus topics. Saved together with the Details tab.
class ManageScheduleTab extends ConsumerWidget {
  final int classId;

  const ManageScheduleTab({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classManageProvider(classId));
    final draft = state.draft!;
    final lookups = state.payload!.lookups;
    final notifier = ref.read(classManageProvider(classId).notifier);

    void change(int index, ManageSchedule slot) => notifier.editDraft((d) {
      final slots = [...d.schedules];
      slots[index] = slot;
      return d.copyWith(schedules: slots);
    });

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
        if (draft.schedules.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingMD),
            child: AppEmptySection(
              icon: Icons.calendar_month_outlined,
              message: 'This class has no weekly slots yet.',
            ),
          ),
        for (var i = 0; i < draft.schedules.length; i++)
          ManageSlotCard(
            key: ValueKey('slot-$i-${draft.schedules[i].hashCode}'),
            slot: draft.schedules[i],
            lookups: lookups,
            onChanged: (slot) => change(i, slot),
            onRemove: () => notifier.editDraft(
              (d) => d.copyWith(schedules: [...d.schedules]..removeAt(i)),
            ),
          ),
        const SizedBox(height: AppTheme.spacingMD),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add a day'),
          onPressed: () => notifier.editDraft(
            (d) => d.copyWith(
              schedules: [
                ...d.schedules,
                ManageSchedule(
                  day: 1,
                  hour: 19,
                  minute: 0,
                  timezone: d.schedules.isNotEmpty
                      ? d.schedules.first.timezone
                      : 'Asia/Kolkata',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ManageSlotCard extends StatelessWidget {
  final ManageSchedule slot;
  final ManageLookups lookups;
  final ValueChanged<ManageSchedule> onChanged;
  final VoidCallback onRemove;

  /// The syllabus topic chips. The schedule-only screen (#629) leaves them out.
  final bool showTopics;

  const ManageSlotCard({
    super.key,
    required this.slot,
    required this.lookups,
    required this.onChanged,
    required this.onRemove,
    this.showTopics = true,
  });

  @override
  Widget build(BuildContext context) {
    // Web offers quarter hours; keep a slot's own minute selectable if it is
    // something else, so opening the screen never rewrites it.
    final minutes = {0, 15, 30, 45, slot.minute}.toList()..sort();
    final timezones = [
      ...lookups.timezones,
      if (!lookups.timezones.any((t) => t.timezone == slot.timezone))
        ManageTimezone(timezone: slot.timezone, label: slot.timezone),
    ];
    final topicNames = {for (final t in lookups.topics) t.id: t.name};

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: slot.day,
                    decoration: AppTheme.dropdownDecoration(label: 'Day'),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(_weekdays[d - 1]),
                        ),
                    ],
                    onChanged: (v) =>
                        onChanged(slot.copyWith(day: v ?? slot.day)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove this day',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: slot.hour,
                    decoration: AppTheme.dropdownDecoration(label: 'Hour'),
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text(h.toString().padLeft(2, '0')),
                        ),
                    ],
                    onChanged: (v) =>
                        onChanged(slot.copyWith(hour: v ?? slot.hour)),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: slot.minute,
                    decoration: AppTheme.dropdownDecoration(label: 'Minute'),
                    items: [
                      for (final m in minutes)
                        DropdownMenuItem(
                          value: m,
                          child: Text(m.toString().padLeft(2, '0')),
                        ),
                    ],
                    onChanged: (v) =>
                        onChanged(slot.copyWith(minute: v ?? slot.minute)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<String>(
              initialValue: slot.timezone,
              isExpanded: true,
              decoration: AppTheme.dropdownDecoration(label: 'Timezone'),
              items: [
                for (final t in timezones)
                  DropdownMenuItem(
                    value: t.timezone,
                    child: Text(t.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) =>
                  onChanged(slot.copyWith(timezone: v ?? slot.timezone)),
            ),
            if (showTopics) ...[
              const SizedBox(height: AppTheme.spacingMD),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final topic in slot.topics)
                    InputChip(
                      label: Text(
                        topicNames[topic.topicId] ?? 'Topic ${topic.topicId}',
                      ),
                      onDeleted: () => onChanged(
                        slot.copyWith(
                          topics: slot.topics.where((t) => t != topic).toList(),
                        ),
                      ),
                    ),
                  PopupMenuButton<int>(
                    tooltip: 'Add a topic',
                    onSelected: (id) => onChanged(
                      slot.copyWith(
                        topics: [
                          ...slot.topics,
                          ManageTopic(topicId: id),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => [
                      for (final t in lookups.topics)
                        if (!slot.topics.any((s) => s.topicId == t.id))
                          PopupMenuItem(value: t.id, child: Text(t.name)),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.add, size: 18),
                      label: Text('Topic'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
