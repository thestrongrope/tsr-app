import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';
import '../providers/feedback_queue_provider.dart';
import '../repositories/feedback_repository.dart';
import '../services/feedback_queue_store.dart';

/// Write a message to the team. Online it is sent and confirmed; offline it is
/// kept on the phone and sent later. A failed online send keeps the text.
class SendFeedbackScreen extends ConsumerStatefulWidget {
  const SendFeedbackScreen({super.key});

  @override
  ConsumerState<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends ConsumerState<SendFeedbackScreen> {
  final _controller = TextEditingController();

  // One id per message, kept across a failed attempt so a resend cannot
  // create a second copy on the server.
  String _clientId = newClientId();
  bool _sending = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    if (ref.read(isOfflineProvider)) {
      await ref.read(feedbackQueueProvider.notifier).enqueue(_clientId, text);
      _finish('Saved. It will be sent when you are back online.');
      return;
    }
    try {
      await ref.read(feedbackRepositoryProvider).send(_clientId, text);
      _finish('Received. Thank you.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = userMessage(e);
      });
    }
  }

  void _finish(String notice) {
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _sending = false;
      _clientId = newClientId();
      _notice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(feedbackQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          TextField(
            controller: _controller,
            maxLines: 8,
            maxLength: FeedbackRepository.maxLength,
            enabled: !_sending,
            decoration: const InputDecoration(
              hintText: 'Tell us what is working and what is not.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          const Text(
            'Your message is sent with your account, so we know who wrote it. '
            'Only our team can read it.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSM),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSM),
              child: Text(_notice!),
            ),
          const SizedBox(height: AppTheme.spacingMD),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: const Text('Send'),
          ),
          for (final item in pending) _PendingItem(item: item),
        ],
      ),
    );
  }
}

class _PendingItem extends ConsumerWidget {
  const _PendingItem({required this.item});

  final QueuedFeedback item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.read(feedbackQueueProvider.notifier);
    return Card(
      margin: const EdgeInsets.only(top: AppTheme.spacingMD),
      child: ListTile(
        title: Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.failed ? 'Not sent: ${item.error}' : 'Waiting to be sent',
        ),
        trailing: Wrap(
          children: [
            if (item.failed)
              TextButton(
                onPressed: () => queue.retry(item.clientId),
                child: const Text('Retry'),
              ),
            TextButton(
              onPressed: () => queue.discard(item.clientId),
              child: const Text('Discard'),
            ),
          ],
        ),
      ),
    );
  }
}
