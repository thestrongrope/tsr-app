import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/class_manage_provider.dart';
import '../widgets/class_loading_skeleton.dart';
import '../widgets/manage_common.dart';
import '../widgets/manage_details_tab.dart';
import '../widgets/manage_schedule_tab.dart';
import '../widgets/manage_students_tab.dart';

/// Manage a class (#402): the mobile counterpart of the web's edit-class page,
/// with the same three tabs. Details and Schedule are saved together; student
/// actions save as they are made.
class ClassManageScreen extends ConsumerWidget {
  final int classId;

  /// The tab to open on: 0 Details, 1 Schedule, 2 Students.
  final int initialTab;

  /// The Schedule tab, opened by the dashboard's schedule card.
  static const scheduleTab = 1;

  /// The Students tab, opened by the dashboard's Class Students tile.
  static const studentsTab = 2;

  const ClassManageScreen({
    super.key,
    required this.classId,
    this.initialTab = 0,
  });

  String _sentence(String text) => text.endsWith('.') ? text : '$text.';

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(classManageProvider(classId).notifier).save();
      if (context.mounted) {
        AppSnackBar.showSuccess(context, message: 'Class saved');
      }
    } catch (e) {
      // The draft stays as the teacher left it, so they can fix and save again.
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          message:
              'Not saved. ${_sentence(manageErrorText(e))} Your changes are kept.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classManageProvider(classId));
    final payload = state.payload;

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('You have unsaved changes to this class.'),
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
      child: DefaultTabController(
        length: 3,
        initialIndex: initialTab,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              payload == null ? 'Manage class' : payload.classInfo.code,
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'Schedule'),
                Tab(text: 'Students'),
              ],
            ),
          ),
          body: _body(context, ref, state),
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
                          : const Text('Save changes'),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ClassManageState state) {
    if (state.payload == null) {
      if (state.isLoading) return const ClassLoadingSkeleton();
      // The provider keeps the sentence it already worded; wrapping it lets
      // the shared error view show it unchanged.
      return AppErrorView(
        error: ApiException(state.error ?? 'Could not load this class.', 400),
        onRetry: ref.read(classManageProvider(classId).notifier).load,
      );
    }
    return TabBarView(
      children: [
        ManageDetailsTab(classId: classId),
        ManageScheduleTab(classId: classId),
        ManageStudentsTab(classId: classId),
      ],
    );
  }
}

/// A teacher's roster (class-students:read): who is in the class, to look at.
/// Names only; contact details are for those who may edit the class.
class ClassRosterScreen extends ConsumerWidget {
  final int classId;

  const ClassRosterScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(classRosterProvider(classId));
    return Scaffold(
      appBar: AppBar(title: const Text('Class students')),
      body: roster.when(
        loading: () => const ClassLoadingSkeleton(),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(classRosterProvider(classId)),
        ),
        data: (students) {
          if (students.isEmpty) {
            return const Center(child: Text('No students in this class.'));
          }
          return ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => ListTile(
              leading: students[i].mcqAdmin
                  ? Icon(Icons.verified_user, color: AppTheme.primaryGreen)
                  : const Icon(Icons.person_outline),
              title: Text(students[i].name),
              subtitle: Text('Token ${students[i].token}'),
            ),
          );
        },
      ),
    );
  }
}
