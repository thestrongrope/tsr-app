import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_classes.dart';
import '../../../core/theme/app_theme.dart';
import '../../parent/providers/parent_provider.dart';
import '../../parent/widgets/add_parent_dialog.dart';
import '../models/class_manage.dart';
import '../providers/class_manage_provider.dart';
import 'bulk_add_students_dialog.dart';
import 'link_student_dialog.dart';
import 'manage_common.dart';

enum _StudentView { active, removed, quizTakers, transfers }

/// Students tab: the active and removed rosters and, for the super admin, the
/// transfer history. Each action is offered only when the server said the
/// caller holds the permission it needs (the server checks it again).
class ManageStudentsTab extends ConsumerStatefulWidget {
  final int classId;

  const ManageStudentsTab({super.key, required this.classId});

  @override
  ConsumerState<ManageStudentsTab> createState() => _ManageStudentsTabState();
}

class _ManageStudentsTabState extends ConsumerState<ManageStudentsTab> {
  _StudentView _view = _StudentView.active;

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showManageMessage(context, done);
    } catch (e) {
      if (mounted) showManageError(context, e);
    }
  }

  Widget _viewChip(_StudentView view, String label) => ChoiceChip(
    label: Text(label),
    selected: _view == view,
    onSelected: (_) => setState(() => _view = view),
  );

  @override
  Widget build(BuildContext context) {
    final payload = ref.watch(classManageProvider(widget.classId)).payload!;
    final notifier = ref.read(classManageProvider(widget.classId).notifier);
    final can = payload.can;
    final roster = payload.roster;
    final canAddParent = ref.watch(capabilitiesProvider).canAddParents;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          // Chips wrap onto a second line, so every label stays whole.
          child: Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: [
              _viewChip(
                _StudentView.active,
                'Active (${roster.students.length})',
              ),
              _viewChip(
                _StudentView.removed,
                'Removed (${roster.removedStudents.length})',
              ),
              if (can.enrol && roster.mcqStudents.isNotEmpty)
                _viewChip(
                  _StudentView.quizTakers,
                  'Quiz takers (${roster.mcqStudents.length})',
                ),
              if (can.transfer) _viewChip(_StudentView.transfers, 'Transfers'),
            ],
          ),
        ),
        if (can.enrol && _view == _StudentView.active)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
              ),
              child: OutlinedButton.icon(
                key: const Key('bulk-add-students'),
                onPressed: () => _bulkAdd(notifier),
                icon: const Icon(Icons.group_add),
                label: const Text('Add several'),
              ),
            ),
          ),
        Expanded(
          child: switch (_view) {
            _StudentView.active => _ActiveList(
              students: roster.students,
              can: can,
              canAddParent: canAddParent,
              onEdit: (s) => _edit(s, can, notifier),
              onRemove: (s) => _remove(s, notifier),
              onTransfer: (s) => _transfer(s, payload, notifier),
              onAddParent: _addParent,
              onClassAdmin: (s, on) => _run(
                () => notifier.setClassAdmin(s.token, on),
                on ? 'Made MCQ admin' : 'MCQ admin removed',
              ),
            ),
            _StudentView.removed => _RemovedList(
              students: roster.removedStudents,
              canRestore: can.enrol,
              onRestore: (s) => _run(
                () => notifier.restoreStudent(s.token),
                '${s.name} restored',
              ),
            ),
            _StudentView.quizTakers => _CandidateList(
              candidates: roster.mcqStudents,
              onAdd: (c) =>
                  _run(() => notifier.addStudent(c.token), '${c.name} added'),
            ),
            _StudentView.transfers => _TransferList(
              history: roster.transferHistory,
            ),
          },
        ),
      ],
    );
  }

  Future<void> _bulkAdd(ClassManageNotifier notifier) async {
    final added = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkAddStudentsDialog(onSubmit: notifier.bulkAddStudents),
    );
    if (added != null && added > 0 && mounted) {
      showManageMessage(context, '$added student(s) added');
    }
  }

  Future<void> _addParent(ManagedStudent s) async {
    final byToken = ref.read(capabilitiesProvider).canAddParentByToken;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddParentDialog(
        childToken: s.token,
        childName: s.name,
        allowDirectTokenEntry: byToken,
      ),
    );
    if (added == true && mounted) {
      ref.invalidate(childrenProvider);
      showManageMessage(context, 'Parent linked successfully');
    }
  }

  Future<void> _link(ManagedStudent s, ClassManageNotifier notifier) async {
    final linked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LinkStudentDialog(
        extraName: s.name,
        onPreview: (memberToken) => notifier.linkPreview(s.token, memberToken),
        onLink: (memberToken, resolutions) =>
            notifier.linkStudent(s.token, memberToken, resolutions),
      ),
    );
    if (linked == true && mounted) {
      showManageMessage(context, '${s.name} linked to the member');
    }
  }

  Future<void> _edit(
    ManagedStudent s,
    ManageCan can,
    ClassManageNotifier notifier,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditStudentDialog(
        student: s,
        onLink: can.link && s.extraStudent ? () => _link(s, notifier) : null,
      ),
    );
    if (result == null) return;
    await _run(
      () => notifier.updateStudent(
        s.token,
        name: result['name']!,
        email: result['email']!,
        mobile: result['mobile']!,
        notes: result['notes']!,
      ),
      'Saved',
    );
  }

  Future<void> _remove(ManagedStudent s, ClassManageNotifier notifier) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: 'Remove ${s.name}?',
        confirm: 'Remove',
        hint: 'Reason (required)',
      ),
    );
    if (reason == null) return;
    await _run(
      () => notifier.removeStudent(s.token, reason),
      '${s.name} removed',
    );
  }

  Future<void> _transfer(
    ManagedStudent s,
    ClassManagePayload payload,
    ClassManageNotifier notifier,
  ) async {
    final result =
        await showDialog<({int toClassId, String type, String reason})>(
          context: context,
          builder: (_) =>
              _TransferDialog(student: s, destinations: payload.destinations),
        );
    if (result == null) return;
    await _run(
      () => notifier.transferStudent(
        s.token,
        toClassId: result.toClassId,
        type: result.type,
        reason: result.reason,
      ),
      '${s.name} moved',
    );
  }
}

class _ActiveList extends StatelessWidget {
  final List<ManagedStudent> students;
  final ManageCan can;
  final bool canAddParent;
  final ValueChanged<ManagedStudent> onEdit;
  final ValueChanged<ManagedStudent> onRemove;
  final ValueChanged<ManagedStudent> onTransfer;
  final ValueChanged<ManagedStudent> onAddParent;
  final void Function(ManagedStudent, bool) onClassAdmin;

  const _ActiveList({
    required this.students,
    required this.can,
    required this.canAddParent,
    required this.onEdit,
    required this.onRemove,
    required this.onTransfer,
    required this.onAddParent,
    required this.onClassAdmin,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(child: Text('No students in this class.'));
    }
    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = students[i];
        final contact = [s.mobile, s.email].whereType<String>().join(' · ');
        return ListTile(
          title: Text(s.name),
          subtitle: Text(
            ['Token ${s.token}', if (contact.isNotEmpty) contact].join('\n'),
          ),
          isThreeLine: contact.isNotEmpty,
          leading: s.mcqAdmin
              ? Tooltip(
                  message: 'MCQ admin',
                  child: Icon(
                    Icons.verified_user,
                    color: AppTheme.primaryGreen,
                  ),
                )
              : const Icon(Icons.person_outline),
          trailing: PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  onEdit(s);
                case 'admin':
                  onClassAdmin(s, !s.mcqAdmin);
                case 'transfer':
                  onTransfer(s);
                case 'remove':
                  onRemove(s);
                case 'add_parent':
                  onAddParent(s);
              }
            },
            itemBuilder: (_) => [
              if (can.update)
                const PopupMenuItem(value: 'edit', child: Text('Edit details')),
              if (can.setClassAdmin)
                PopupMenuItem(
                  value: 'admin',
                  child: Text(
                    s.mcqAdmin ? 'Remove MCQ admin' : 'Make MCQ admin',
                  ),
                ),
              if (can.transfer)
                const PopupMenuItem(value: 'transfer', child: Text('Transfer')),
              if (can.enrol)
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              if (canAddParent)
                const PopupMenuItem(
                  value: 'add_parent',
                  child: Text('Add parent'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RemovedList extends StatelessWidget {
  final List<RemovedStudent> students;
  final bool canRestore;
  final ValueChanged<RemovedStudent> onRestore;

  const _RemovedList({
    required this.students,
    required this.canRestore,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(child: Text('No removed students.'));
    }
    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = students[i];
        return ListTile(
          title: Text(s.name),
          subtitle: Text(
            [
              'Token ${s.token}',
              if (s.removedReason != null) s.removedReason!,
              if (s.removedByName != null) 'by ${s.removedByName}',
            ].join('\n'),
          ),
          isThreeLine: s.removedReason != null,
          trailing: canRestore
              ? TextButton(
                  onPressed: () => onRestore(s),
                  child: const Text('Restore'),
                )
              : null,
        );
      },
    );
  }
}

/// Members who took the class's quizzes without being enrolled, as on web's MCQ tab.
class _CandidateList extends StatelessWidget {
  final List<AddCandidate> candidates;
  final ValueChanged<AddCandidate> onAdd;

  const _CandidateList({required this.candidates, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = candidates[i];
        return ListTile(
          title: Text(c.name),
          subtitle: Text('Token ${c.token}'),
          trailing: TextButton(
            onPressed: () => onAdd(c),
            child: const Text('Add'),
          ),
        );
      },
    );
  }
}

class _TransferList extends StatelessWidget {
  final List<TransferRecord> history;

  const _TransferList({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No transfers for this class.'));
    }
    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final t = history[i];
        return ListTile(
          title: Text(t.studentName),
          subtitle: Text(
            [
              '${t.type}: ${t.fromClassCode} → ${t.toClassCode}',
              if (t.reason != null) t.reason!,
              [
                t.transferredBy,
                t.transferredAt,
              ].whereType<String>().join(' · '),
            ].where((l) => l.isNotEmpty).join('\n'),
          ),
          isThreeLine: true,
        );
      },
    );
  }
}

class _EditStudentDialog extends StatefulWidget {
  final ManagedStudent student;

  /// Set only for a super admin looking at an extra student (#1135).
  final VoidCallback? onLink;

  const _EditStudentDialog({required this.student, this.onLink});

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  late final _name = TextEditingController(text: widget.student.name);
  late final _email = TextEditingController(text: widget.student.email ?? '');
  late final _mobile = TextEditingController(text: widget.student.mobile ?? '');
  late final _notes = TextEditingController(text: widget.student.notes ?? '');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c, {int lines = 1}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
          child: TextField(
            controller: c,
            maxLines: lines,
            decoration: InputDecoration(labelText: label),
          ),
        );
    return AlertDialog(
      title: const Text('Edit student'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field('Name', _name),
            field('Email', _email),
            field('Mobile', _mobile),
            field('Notes', _notes, lines: 3),
            if (widget.onLink != null)
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onLink!();
                },
                child: const Text('Link to an existing member'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'mobile': _mobile.text.trim(),
            'notes': _notes.text.trim(),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String confirm;
  final String hint;

  const _ReasonDialog({
    required this.title,
    required this.confirm,
    required this.hint,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLength: 500,
        decoration: InputDecoration(labelText: widget.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_reason.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final ManagedStudent student;
  final List<TransferDestination> destinations;

  const _TransferDialog({required this.student, required this.destinations});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  int? _to;
  String _type = 'transfer';
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Move ${widget.student.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _to,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'To class'),
              items: [
                for (final d in widget.destinations)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      '${d.code} · ${d.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'transfer', label: Text('Transfer')),
                ButtonSegment(value: 'promotion', label: Text('Promote')),
                ButtonSegment(value: 'demotion', label: Text('Demote')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            TextField(
              controller: _reason,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _to == null
              ? null
              : () => Navigator.of(context).pop((
                  toClassId: _to!,
                  type: _type,
                  reason: _reason.text.trim(),
                )),
          child: const Text('Move'),
        ),
      ],
    );
  }
}
