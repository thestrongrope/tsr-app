import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/whatsapp_reminders.dart';
import '../providers/whatsapp_reminders_provider.dart';
import '../repositories/whatsapp_reminders_repository.dart';
import '../../../core/widgets/tab_bar_inset.dart';

final _when = DateFormat('d MMM y, HH:mm');

String _at(DateTime? time) => time == null ? '' : _when.format(time.toLocal());

/// "Sent 3 · skipped 1 · failed 2".
String runCounts(WhatsappRun run) =>
    'Sent ${run.sent} · skipped ${run.skipped} · failed ${run.failed}';

/// One run: its window, status and counts, and each teacher it handled
/// (#418). A run that is still going is read again every few seconds.
class WhatsappRunScreen extends ConsumerStatefulWidget {
  const WhatsappRunScreen({super.key, required this.runId});

  final int runId;

  @override
  ConsumerState<WhatsappRunScreen> createState() => _WhatsappRunScreenState();
}

class _WhatsappRunScreenState extends ConsumerState<WhatsappRunScreen> {
  static const _pollEvery = Duration(seconds: 3);

  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _pollWhileRunning(WhatsappRun run) {
    if (!run.isRunning || _poll != null) return;
    _poll = Timer(_pollEvery, () {
      _poll = null;
      if (mounted) ref.invalidate(whatsappRunProvider(widget.runId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(whatsappRunProvider(widget.runId));
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: Text('Run #${widget.runId}')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(whatsappErrorWords(e)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(whatsappRunProvider(widget.runId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (d) {
          _pollWhileRunning(d.run);
          final run = d.run;
          return ListView(
            padding: withTabBarInset(context, const EdgeInsets.all(16)),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.dryRun
                            ? '${run.status} · dry run, nothing was sent'
                            : run.status,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(runCounts(run)),
                      if (run.window != null)
                        Text('Window ${run.window}', style: muted),
                      Text(
                        'Started ${_at(run.startedAt)}'
                        '${run.finishedAt == null ? '' : ' · finished ${_at(run.finishedAt)}'}',
                        style: muted,
                      ),
                      if (run.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          run.error!,
                          style: TextStyle(
                            color: run.status == 'failed'
                                ? AppTheme.errorRed
                                : AppTheme.mediumText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                run.isRunning && d.messages.isEmpty
                    ? 'Working on it…'
                    : d.messages.isEmpty
                    ? 'No teacher was handled.'
                    : '${d.messages.length} teachers',
              ),
              const SizedBox(height: 8),
              for (final m in d.messages) _MessageCard(message: m),
            ],
          );
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final WhatsappMessage message;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final failed = message.status == 'failed';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.name ?? message.mobile,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (message.name != null) Text(message.mobile, style: muted),
            const SizedBox(height: 4),
            Text(
              [
                message.status,
                if (message.missing != null) '${message.missing} missing',
                if (message.sentAt != null) _at(message.sentAt),
              ].join(' · '),
            ),
            if (message.error != null)
              Text(
                message.error!,
                style: TextStyle(
                  color: failed ? AppTheme.errorRed : AppTheme.mediumText,
                ),
              ),
            if (message.excerpt != null) Text(message.excerpt!, style: muted),
          ],
        ),
      ),
    );
  }
}
