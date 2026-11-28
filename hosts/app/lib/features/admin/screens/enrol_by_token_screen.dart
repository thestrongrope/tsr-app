import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/tab_bar_inset.dart';
import '../../classes/models/class_model.dart';
import '../../classes/providers/classes_provider.dart';
import '../models/enrol_by_token.dart';
import '../providers/enrol_by_token_provider.dart';
import 'enrol_by_token_details.dart';

const _cannotSave = 'This cannot be saved right now. Nothing was changed.';

/// A token's length is bounded: the server accepts at most 18 digits.
const _maxTokenDigits = 18;

/// What to tell the admin when the enrolment failed. A refusal the server
/// explained keeps its words; a network or server failure says nothing changed.
String enrolFailureMessage(Object error) {
  if (error is EnrolRefusal) return error.message;
  if (error is ApiException && error.isClientError && error.statusCode != 408) {
    return userMessage(error);
  }
  return _cannotSave;
}

/// A super admin looks a member up by token and enrols them in one class
/// (#1050).
class EnrolByTokenScreen extends ConsumerStatefulWidget {
  const EnrolByTokenScreen({super.key});

  @override
  ConsumerState<EnrolByTokenScreen> createState() => _EnrolByTokenScreenState();
}

class _EnrolByTokenScreenState extends ConsumerState<EnrolByTokenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  int? _selectedClassId;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(classesProvider);
      if (state.classes == null && !state.isLoading) {
        ref.read(classesProvider.notifier).loadClasses();
      }
    });
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter a token number';
    final token = int.tryParse(text);
    if (token == null || token <= 0) return 'Enter a valid token number';
    return null;
  }

  void _lookUp() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _selectedClassId = null);
    ref
        .read(memberLookupProvider.notifier)
        .lookup(int.parse(_token.text.trim()));
  }

  Future<void> _confirm(MemberDetails member, ClassModel cls) async {
    if (_enrolling) return;
    setState(() => _enrolling = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(member: member, cls: cls),
      );
      if (ok != true || !mounted) return;
      await ref.read(enrolMemberProvider)(token: member.token, classId: cls.id);
      if (!mounted) return;
      ref.read(memberLookupProvider.notifier).clear();
      _token.clear();
      setState(() => _selectedClassId = null);
      AppSnackBar.showSuccess(
        context,
        message: '${member.name} added to ${cls.code}',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: enrolFailureMessage(e));
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(memberLookupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Enrol by token')),
      body: ListView(
        padding: withTabBarInset(
          context,
          const EdgeInsets.all(AppTheme.spacingLG),
        ),
        children: [
          _tokenForm(lookup.isLoading),
          const SizedBox(height: AppTheme.spacingMD),
          if (lookup.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (lookup.hasError && !lookup.isLoading) _failure(lookup.error!),
          if (lookup.value case final member? when !lookup.isLoading) ...[
            MemberDetailsCard(member: member),
            const SizedBox(height: AppTheme.spacingLG),
            _chooser(member),
          ],
        ],
      ),
    );
  }

  Widget _tokenForm(bool busy) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _token,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_maxTokenDigits),
            ],
            validator: _validate,
            onFieldSubmitted: (_) => busy ? null : _lookUp(),
            decoration: const InputDecoration(
              labelText: 'Token number',
              helperText: 'The number on the member\'s account',
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          FilledButton(
            onPressed: busy ? null : _lookUp,
            child: const Text('Look up'),
          ),
        ],
      ),
    );
  }

  Widget _failure(Object error) {
    if (error is EnrolRefusal) {
      return AppEmptySection(
        icon: Icons.search_off_rounded,
        message: error.message,
      );
    }
    return AppErrorView(error: error, compact: true, onRetry: _lookUp);
  }

  Widget _chooser(MemberDetails member) {
    final classes = ref.watch(classesProvider);
    final all = classes.classes;
    if (all == null) {
      return classes.error != null
          ? AppErrorView(
              error: classes.error!,
              compact: true,
              onRetry: () => ref.read(classesProvider.notifier).refresh(),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final inClasses = {for (final c in member.classesNow) c.id};
    ClassModel? chosen;
    for (final c in all) {
      if (c.id == _selectedClassId && !inClasses.contains(c.id)) chosen = c;
    }
    final target = chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClassChooser(
          member: member,
          classes: all,
          selectedId: _selectedClassId,
          onSelect: (c) => setState(() => _selectedClassId = c.id),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        FilledButton(
          onPressed: target == null || _enrolling
              ? null
              : () => _confirm(member, target),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.member, required this.cls});

  final MemberDetails member;
  final ClassModel cls;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  /// A second tap before the dialog finishes closing would pop the screen too.
  bool _closed = false;

  void _close(bool answer) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(answer);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return AlertDialog(
      title: Text('Enrol ${m.name} (${m.token}) in ${widget.cls.code}?'),
      content: Text(widget.cls.name),
      actions: [
        TextButton(onPressed: () => _close(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => _close(true), child: const Text('Enrol')),
      ],
    );
  }
}
