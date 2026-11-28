import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/deletion_requests.dart';
import '../providers/deletion_requests_provider.dart';
import '../repositories/deletion_requests_repository.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The account-deletion queue (#416), the mobile counterpart of the web's
/// Deletion Requests page: filter by status, send the member their
/// confirmation and record it, hold for prize delivery, raise one from an
/// emailed address, and complete, which cannot be undone.
///
/// The server decides what each request may do (`canComplete`,
/// `confirmation`) and enforces it; this screen only shows it.
class DeletionRequestsScreen extends ConsumerStatefulWidget {
  const DeletionRequestsScreen({super.key});

  @override
  ConsumerState<DeletionRequestsScreen> createState() =>
      _DeletionRequestsScreenState();
}

class _DeletionRequestsScreenState
    extends ConsumerState<DeletionRequestsScreen> {
  String? _status;

  /// True while an action is in flight, so a second tap is not a second send.
  bool _busy = false;

  Future<void> _act(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (message != null && mounted) {
        AppSnackBar.showSuccess(context, message: message);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: e is ApiException
              ? e.message
              : 'That did not work. Please try again.',
        );
      }
    } finally {
      // Whatever happened, show the queue as the server now has it.
      ref.invalidate(deletionQueueProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  DeletionRequestsRepository get _repo =>
      ref.read(deletionRequestsRepositoryProvider);

  Future<String?> _askText({
    required String title,
    required String label,
    required String confirm,
    String? hint,
    String initial = '',
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _raise() async {
    final email = await _askText(
      title: 'Raise from an email',
      label: 'Email address on their account',
      confirm: 'Raise request',
      hint: 'Check the person emailing is who they say they are first.',
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || email.isEmpty) return;
    await _act(() async {
      final raised = await _repo.raise(email);
      final r = raised.request;
      return raised.created
          ? 'Opened request #${r.id} for ${r.memberName}. Check this is the right person.'
          : '${r.memberName} already has request #${r.id} open.';
    });
  }

  Future<void> _hold(DeletionRequest r) async {
    final note = await _askText(
      title: 'Hold for prize delivery',
      label: 'Why we are holding it (the member reads this)',
      confirm: 'Hold',
      initial: r.operatorNote ?? '',
    );
    if (note == null) return;
    await _act(() async {
      await _repo.hold(r.id, note);
      return 'Request #${r.id} is now awaiting prize delivery.';
    });
  }

  Future<void> _confirmationSent(DeletionRequest r) => _act(() async {
    await _repo.confirmationSent(r.id);
    return 'Confirmation recorded for request #${r.id}. It can now be completed.';
  });

  Future<void> _complete(DeletionRequest r) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete request #${r.id}?'),
        content: Text(
          'This deletes ${r.memberName}\'s sign-in account and anonymises '
          'their record. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Complete deletion'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _act(() async {
      await _repo.complete(r.id);
      return 'Request #${r.id} completed. The member has been anonymised.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(deletionQueueProvider(_status));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Deletion requests'),
        actions: [
          IconButton(
            tooltip: 'Raise from an email',
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _raise,
          ),
        ],
      ),
      body: queue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The deletion requests could not be loaded.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(deletionQueueProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(DeletionQueue queue) {
    return ListView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('All (${queue.total})'),
              selected: _status == null,
              onSelected: (_) => setState(() => _status = null),
            ),
            for (final s in deletionStatuses)
              ChoiceChip(
                label: Text('${deletionStatusLabel(s)} (${queue.count(s)})'),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (queue.requests.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nothing here.')),
          ),
        for (final r in queue.requests)
          _RequestCard(
            request: r,
            busy: _busy,
            onHold: () => _hold(r),
            onConfirmationSent: () => _confirmationSent(r),
            onComplete: () => _complete(r),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onHold,
    required this.onConfirmationSent,
    required this.onComplete,
  });

  final DeletionRequest request;
  final bool busy;
  final VoidCallback onHold;
  final VoidCallback onConfirmationSent;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${r.id} · ${r.memberName.isEmpty ? 'Unknown' : r.memberName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(deletionStatusLabel(r.status))),
                if (r.isDemo) const Chip(label: Text('Reviewer demo')),
              ],
            ),
            const SizedBox(height: 8),
            _line('Email', r.contactEmail),
            _line('Via', r.source),
            _line('Requested', r.requestedAt),
            _line('Their reason', r.reason),
            _line('Note shown in the app', r.operatorNote),
            _line('Confirmation sent', r.confirmationSentAt ?? 'not yet'),
            _line('Handled by', r.handledByName),
            if (r.isHeld) _prizeBox(r),
            if (r.isLive) ..._actions(context),
            if (!r.isLive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  r.status == 'completed'
                      ? 'Completed. Nothing more to do.'
                      : 'Cancelled by the member. Nothing more to do.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text('$label: $value'),
    );
  }

  /// The postal code and mobile on file: completing clears both, so they are
  /// shown to whoever is deciding whether delivery is finished.
  Widget _prizeBox(DeletionRequest r) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(8),
    color: Colors.amber.shade100,
    child: Text(
      'Prize delivery. Postal code / address on file: ${r.memberZip ?? '—'}, '
      'mobile ${r.memberMobile ?? '—'}. Completing clears both.',
    ),
  );

  List<Widget> _actions(BuildContext context) {
    final r = request;
    final mail = r.confirmation;
    return [
      const Divider(height: 24),
      OutlinedButton(
        onPressed: busy ? null : onHold,
        child: const Text('Hold for prize delivery'),
      ),
      if (mail != null) ...[
        const SizedBox(height: 12),
        const Text(
          'Step 1: send the confirmation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('To ${mail.to}, subject "${mail.subject}".'),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade200,
          child: SelectableText(mail.body),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _copy(context, mail.to, 'Address copied'),
              child: const Text('Copy address'),
            ),
            TextButton(
              onPressed: () => _copy(
                context,
                '${mail.subject}\n\n${mail.body}',
                'Email text copied',
              ),
              child: const Text('Copy email text'),
            ),
          ],
        ),
        ElevatedButton(
          onPressed: busy ? null : onConfirmationSent,
          child: const Text('I have sent this confirmation'),
        ),
      ],
      const SizedBox(height: 12),
      const Text(
        'Step 2: complete',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      if (r.isDemo)
        const Text(
          'This belongs to the reviewer demo accounts and cannot be completed. '
          'Cancel it instead, or run the cohort teardown after the review.',
        )
      else if (!r.confirmationSent)
        const Text(
          'Record the confirmation first. Completing clears the email '
          'address, after which it cannot be sent.',
        )
      else if (r.canComplete)
        ElevatedButton(
          onPressed: busy ? null : onComplete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Complete deletion'),
        )
      else
        const Text('This request cannot be completed.'),
    ];
  }

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) AppSnackBar.showInfo(context, message: message);
  }
}
