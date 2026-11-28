import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';
import '../models/class_manage.dart';
import '../providers/class_schedule_provider.dart';
import '../widgets/class_loading_skeleton.dart';
import '../widgets/manage_common.dart';
import '../widgets/manage_schedule_tab.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// A class's day, time and timezone, for its teacher and MCQ admin (#629).
/// Only the schedule: details, roster and teacher stay with Manage Class.
class ClassScheduleScreen extends ConsumerWidget {
  final int classId;

  const ClassScheduleScreen({super.key, required this.classId});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(classScheduleProvider(classId).notifier).save();
      if (context.mounted) showManageMessage(context, 'Schedule saved');
    } catch (e) {
      if (context.mounted) showManageError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classScheduleProvider(classId));
    final notifier = ref.read(classScheduleProvider(classId).notifier);
    final lookups = ManageLookups(timezones: state.timezones);

    void change(int index, ManageSchedule slot) {
      final slots = [...state.draft];
      slots[index] = slot;
      notifier.edit(slots);
    }

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('You have unsaved changes to this schedule.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Class Schedule')),
        body: state.isLoading
            ? const ClassLoadingSkeleton()
            : state.error != null
            // The provider keeps the sentence it already worded; wrapping it
            // lets the shared error view show it unchanged.
            ? AppErrorView(
                error: ApiException(state.error!, 400),
                onRetry: notifier.load,
              )
            : ListView(
                // While dirty, the save bar below already clears the tab bar.
                padding: state.isDirty
                    ? const EdgeInsets.all(AppTheme.spacingLG)
                    : withTabBarInset(
                        context,
                        const EdgeInsets.all(AppTheme.spacingLG),
                      ),
                children: [
                  if (state.draft.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacingLG,
                      ),
                      child: Text('This class has no weekly slots yet.'),
                    ),
                  for (var i = 0; i < state.draft.length; i++)
                    ManageSlotCard(
                      key: ValueKey('slot-$i-${state.draft[i].hashCode}'),
                      slot: state.draft[i],
                      lookups: lookups,
                      showTopics: false,
                      onChanged: (slot) => change(i, slot),
                      onRemove: () =>
                          notifier.edit([...state.draft]..removeAt(i)),
                    ),
                  const SizedBox(height: AppTheme.spacingMD),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add a day'),
                    onPressed: () => notifier.edit([
                      ...state.draft,
                      ManageSchedule(
                        day: 1,
                        hour: 19,
                        minute: 0,
                        timezone: state.draft.isNotEmpty
                            ? state.draft.first.timezone
                            : 'Asia/Kolkata',
                      ),
                    ]),
                  ),
                ],
              ),
        bottomNavigationBar: state.isDirty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: FilledButton(
                    onPressed: state.isSaving
                        ? null
                        : () => _save(context, ref),
                    child: state.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save schedule'),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
