import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/app_error_view.dart';
import '../models/models.dart';
import '../providers/parent_provider.dart';

/// What the invite [code] says: `GET /me/children/link/{code}`.
///
/// No automatic retry: Riverpod's default keeps the screen loading for about 40
/// seconds before an offline failure shows. A failure is shown at once, with a
/// Retry button.
final parentInvitePreviewProvider = FutureProvider.autoDispose
    .family<ParentInvitePreview, String>(
      (ref, code) => ref.read(parentRepositoryProvider).inspectInvite(code),
      retry: (retryCount, error) => null,
    );

const _relationships = <String, String>{
  'father': 'Father',
  'mother': 'Mother',
  'guardian': 'Guardian',
};

/// Why accepting was refused, as the server reports it.
enum _Refusal { gone, notAllowed, alreadyLinked, removed }

_Refusal? _refusalFor(Object error) {
  if (error is! ApiException) return null;
  switch (error.statusCode) {
    case 410:
    case 404:
      return _Refusal.gone;
    case 422:
      return _Refusal.notAllowed;
    case 409:
      return _Refusal.alreadyLinked;
    case 403:
      return _Refusal.removed;
    default:
      return null;
  }
}

const _goneMessage =
    'This invite has expired, has already been used or was cancelled. '
    'Ask for a new one.';

String _refusalMessage(_Refusal refusal) {
  switch (refusal) {
    case _Refusal.gone:
      return _goneMessage;
    case _Refusal.notAllowed:
      return 'You cannot accept this invite with this account.';
    case _Refusal.alreadyLinked:
      return 'You are already linked to this child.';
    case _Refusal.removed:
      return 'The child removed you earlier. Ask an admin for a new invite.';
  }
}

/// A parent-invite link (#1122): shows whose parent the invite makes you and
/// accepts it. A signed-out person signs in first and returns here.
class ParentInviteScreen extends ConsumerStatefulWidget {
  const ParentInviteScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ParentInviteScreen> createState() => _ParentInviteScreenState();
}

class _ParentInviteScreenState extends ConsumerState<ParentInviteScreen> {
  String? _relationship;
  bool _accepting = false;
  _Refusal? _refusal;

  Future<void> _accept() async {
    final relationship = _relationship;
    if (relationship == null || _accepting) return;
    setState(() => _accepting = true);
    try {
      await ref
          .read(parentRepositoryProvider)
          .acceptInvite(widget.code, relationship);
    } catch (e) {
      if (!mounted) return;
      final refusal = _refusalFor(e);
      setState(() {
        _accepting = false;
        _refusal = refusal;
      });
      if (refusal == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(childrenProvider);
    context.go(AppRoutes.myChildren);
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(parentInvitePreviewProvider(widget.code));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Parent invite')),
      body: preview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () =>
              ref.invalidate(parentInvitePreviewProvider(widget.code)),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(ParentInvitePreview invite) {
    if (invite.state == 'not_found') {
      return const _Message(
        'We could not find this invite. The link may be wrong.',
      );
    }
    if (!invite.isValid) return const _Message(_goneMessage);

    final refusal = _refusal;
    if (refusal == _Refusal.alreadyLinked) {
      return _Message(
        _refusalMessage(refusal!),
        action: OutlinedButton(
          onPressed: () => context.go(AppRoutes.myChildren),
          child: const Text('See my children'),
        ),
      );
    }
    if (refusal != null) return _Message(_refusalMessage(refusal));

    return _AcceptForm(
      firstName: invite.firstName,
      relationship: _relationship,
      accepting: _accepting,
      onRelationship: (value) => setState(() => _relationship = value),
      onAccept: _accept,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2XL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (action != null) ...[
            const SizedBox(height: AppTheme.spacingLG),
            action!,
          ],
        ],
      ),
    ),
  );
}

class _AcceptForm extends StatelessWidget {
  const _AcceptForm({
    required this.firstName,
    required this.relationship,
    required this.accepting,
    required this.onRelationship,
    required this.onAccept,
  });

  final String? firstName;
  final String? relationship;
  final bool accepting;
  final ValueChanged<String> onRelationship;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? 'a member' : name;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      children: [
        Text(
          'You have been invited to become a parent or guardian of $who.',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacingLG),
        Text('Your relationship', style: textTheme.titleSmall),
        const SizedBox(height: AppTheme.spacingSM),
        Wrap(
          spacing: AppTheme.spacingSM,
          children: [
            for (final entry in _relationships.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: relationship == entry.key,
                onSelected: (_) => onRelationship(entry.key),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing2XL),
        ElevatedButton(
          onPressed: relationship == null || accepting ? null : onAccept,
          child: accepting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept'),
        ),
      ],
    );
  }
}
