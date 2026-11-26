import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/whatsapp_reminders.dart';
import '../providers/whatsapp_reminders_provider.dart';
import '../repositories/whatsapp_reminders_repository.dart';
import '../widgets/whatsapp_link_card.dart';
import 'whatsapp_reminder_screen.dart';
import 'whatsapp_run_screen.dart';
import '../../../core/widgets/tab_bar_inset.dart';

enum _Segment { reminders, runs }

/// The WhatsApp reminders, their recent runs, and a test message (#418): the
/// mobile counterpart of the web's WhatsApp admin page. The server shows it to
/// those who hold `whatsapp:manage`. The card at the top shows the WhatsApp link
/// and opens the screen to link it (#693).
class WhatsappRemindersScreen extends ConsumerStatefulWidget {
  const WhatsappRemindersScreen({super.key});

  @override
  ConsumerState<WhatsappRemindersScreen> createState() =>
      _WhatsappRemindersScreenState();
}

class _WhatsappRemindersScreenState
    extends ConsumerState<WhatsappRemindersScreen> {
  static final _when = DateFormat('d MMM y, HH:mm');

  _Segment _segment = _Segment.reminders;

  Future<void> _edit(WhatsappReminder reminder) async {
    final saved = await Navigator.of(context).push<WhatsappReminder>(
      MaterialPageRoute(
        builder: (_) => WhatsappReminderScreen(reminder: reminder),
      ),
    );
    if (!mounted) return;
    // A run started from the editor is listed here too.
    ref.invalidate(whatsappRunsProvider);
    if (saved != null) {
      ref.invalidate(whatsappRemindersProvider);
      AppSnackBar.showSuccess(context, message: '${saved.name} saved.');
    }
  }

  Future<void> _sendTest() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const _SendTestDialog(),
    );
    if (sent != true || !mounted) return;
    ref.invalidate(whatsappRunsProvider);
    AppSnackBar.showSuccess(context, message: 'Test message sent.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('WhatsApp reminders'),
        actions: [
          IconButton(
            tooltip: 'Send a test message',
            icon: const Icon(Icons.send_outlined),
            onPressed: _sendTest,
          ),
        ],
      ),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          const WhatsappLinkCard(),
          SegmentedButton<_Segment>(
            segments: const [
              ButtonSegment(
                value: _Segment.reminders,
                label: Text('Reminders'),
              ),
              ButtonSegment(value: _Segment.runs, label: Text('Recent runs')),
            ],
            selected: {_segment},
            onSelectionChanged: (choice) =>
                setState(() => _segment = choice.first),
          ),
          const SizedBox(height: 12),
          ..._segment == _Segment.reminders ? _reminders() : _runs(),
        ],
      ),
    );
  }

  List<Widget> _failed(String what, VoidCallback retry, Object error) => [
    Text(
      error is FormatException
          ? 'The $what could not be loaded.'
          : whatsappErrorWords(error),
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton(onPressed: retry, child: const Text('Try again')),
    ),
  ];

  List<Widget> _reminders() {
    final data = ref.watch(whatsappRemindersProvider);
    return data.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => _failed(
        'reminders',
        () => ref.invalidate(whatsappRemindersProvider),
        e,
      ),
      data: (reminders) => [
        if (reminders.isEmpty) const Text('There are no reminders.'),
        for (final r in reminders) _ReminderCard(reminder: r, onTap: _edit),
      ],
    );
  }

  List<Widget> _runs() {
    final data = ref.watch(whatsappRunsProvider);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    return data.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) =>
          _failed('runs', () => ref.invalidate(whatsappRunsProvider), e),
      data: (runs) => [
        if (runs.isEmpty) const Text('No runs yet.'),
        for (final run in runs)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                '#${run.id} · ${run.status}${run.dryRun ? ' · dry run' : ''}',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(runCounts(run)),
                  if (run.window != null) Text(run.window!, style: muted),
                  if (run.startedAt != null)
                    Text(_when.format(run.startedAt!.toLocal()), style: muted),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => WhatsappRunScreen(runId: run.id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.onTap});

  final WhatsappReminder reminder;
  final void Function(WhatsappReminder) onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final r = reminder;
    final schedule = !r.scheduleOn
        ? 'Schedule off — by hand only'
        : r.when.isEmpty
        ? 'Schedule on, no day or time'
        : 'Schedule on · ${r.when}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onTap(r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.enabled ? r.name : '${r.name} (off)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  r.gender,
                  if (r.place.isNotEmpty) r.place,
                  r.levels,
                  r.lang,
                ].join(' · '),
              ),
              Text(schedule, style: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a number and a text, confirms that a real message goes out, and
/// sends it. Pops true once sent.
class _SendTestDialog extends ConsumerStatefulWidget {
  const _SendTestDialog();

  @override
  ConsumerState<_SendTestDialog> createState() => _SendTestDialogState();
}

class _SendTestDialogState extends ConsumerState<_SendTestDialog> {
  final _mobile = TextEditingController();
  final _message = TextEditingController(text: 'Test message from TSR.');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _mobile.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sendWhatsappTestProvider)(
        mobile: _mobile.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = whatsappErrorWords(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send a test message'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This sends one real WhatsApp message.'),
            const SizedBox(height: 12),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                helperText: 'With country code, such as 919800000000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: const Text('Send'),
        ),
      ],
    );
  }
}
