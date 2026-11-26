import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/permissions/capabilities.dart';
import '../../../../core/permissions/capabilities_home.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../classes/models/class_model.dart';
import '../../../classes/providers/classes_provider.dart';

/// One Home shortcut for a teacher: where it goes and what it needs.
class _Shortcut {
  final String label;
  final IconData icon;
  final String permission;
  final String Function(int classId) path;

  const _Shortcut({
    required this.label,
    required this.icon,
    required this.permission,
    required this.path,
  });
}

String _conductionPath(int classId) => '/classes/$classId/conduction/add';
String _announcementPath(int classId) => '/classes/$classId/notifications/send';

const _recordConduction = _Shortcut(
  label: 'Record conduction',
  icon: Icons.fact_check_outlined,
  permission: 'sessions:create',
  path: _conductionPath,
);

const _classAnnouncement = _Shortcut(
  label: 'Class announcement',
  icon: Icons.campaign_outlined,
  permission: 'notifications:send',
  path: _announcementPath,
);

/// Record conduction and Class announcement (#737, #749). Each shows only when
/// the member teaches a class they may do it for. Until the class list is
/// known (loading, or failed) the permissions stand in, so a tap can say why
/// nothing opened (#970).
class TeachingShortcuts extends ConsumerWidget {
  const TeachingShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitiesProvider);
    final shortcuts = [
      for (final s in [_recordConduction, _classAnnouncement])
        if (capabilities.offersTeachingShortcut(s.permission)) s,
    ];
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
      child: Row(
        children: [
          for (var i = 0; i < shortcuts.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _open(context, ref, shortcuts[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(shortcuts[i].icon),
                        const SizedBox(width: 8),
                        Expanded(child: Text(shortcuts[i].label)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<ClassModel> _eligible(WidgetRef ref, _Shortcut shortcut) =>
      ref.read(capabilitiesProvider).teachingClasses(shortcut.permission);

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    _Shortcut shortcut,
  ) async {
    final state = ref.read(classesProvider);
    if (state.isLoading) {
      AppSnackBar.showInfo(context, message: 'Loading your classes...');
      return;
    }
    if (state.classes == null) {
      _showLoadError(context, ref, state.error);
      return;
    }
    final eligible = _eligible(ref, shortcut);
    if (eligible.isEmpty) {
      AppSnackBar.showInfo(context, message: 'You have no classes to act on.');
      return;
    }
    final chosen = eligible.length == 1
        ? eligible.first
        : await showTeachingClassPicker(context, eligible, shortcut.label);
    if (chosen == null || !context.mounted) return;
    if (!_eligible(ref, shortcut).any((c) => c.id == chosen.id)) {
      AppSnackBar.showWarning(
        context,
        message: 'That class is no longer available for this action.',
      );
      return;
    }
    ref.read(selectedClassIdProvider.notifier).state = chosen.id;
    context.push(shortcut.path(chosen.id));
  }

  void _showLoadError(BuildContext context, WidgetRef ref, String? error) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Could not load your classes.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => ref.read(classesProvider.notifier).loadClasses(),
          ),
        ),
      );
  }
}

/// Asks which class. Shared by both shortcuts.
Future<ClassModel?> showTeachingClassPicker(
  BuildContext context,
  List<ClassModel> classes,
  String title,
) {
  return showModalBottomSheet<ClassModel>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '$title: which class?',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final c in classes)
            ListTile(
              title: Text(c.name),
              onTap: () => Navigator.of(sheetContext).pop(c),
            ),
        ],
      ),
    ),
  );
}
