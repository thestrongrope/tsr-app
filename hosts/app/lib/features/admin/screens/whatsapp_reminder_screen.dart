import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/whatsapp_reminders.dart';
import '../providers/whatsapp_reminders_provider.dart';
import '../repositories/whatsapp_reminders_repository.dart';
import 'whatsapp_run_screen.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// One reminder's settings and the way to run it (#418). Saving sends every
/// field; the notifier checks them and an invalid one comes back in its words
/// with nothing saved. Popped with the saved [WhatsappReminder].
class WhatsappReminderScreen extends ConsumerStatefulWidget {
  const WhatsappReminderScreen({super.key, required this.reminder});

  final WhatsappReminder reminder;

  @override
  ConsumerState<WhatsappReminderScreen> createState() =>
      _WhatsappReminderScreenState();
}

class _WhatsappReminderScreenState
    extends ConsumerState<WhatsappReminderScreen> {
  late final _city = TextEditingController(text: widget.reminder.city ?? '');
  late final _country = TextEditingController(
    text: widget.reminder.country ?? '',
  );
  late final _levels = TextEditingController(text: widget.reminder.levels);
  late final _leeway = TextEditingController(
    text: '${widget.reminder.leewayDays}',
  );
  late final _timezone = TextEditingController(text: widget.reminder.timezone);
  late final _sendTime = TextEditingController(
    text: widget.reminder.sendTimeShort ?? '',
  );
  late String _gender = widget.reminder.gender;
  late String _lang = widget.reminder.lang;
  late int? _weekday = widget.reminder.weekday;
  late bool _enabled = widget.reminder.enabled;
  late bool _scheduleOn = widget.reminder.scheduleOn;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_city, _country, _levels, _leeway, _timezone, _sendTime]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _blankToNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = true,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppTheme.errorRed)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return yes == true && mounted;
  }

  Future<void> _save() async {
    // Switching the schedule on makes real messages go out by themselves.
    if (_scheduleOn && !widget.reminder.scheduleOn) {
      final ok = await _confirm(
        title: 'Turn the schedule on?',
        body:
            'From now on this reminder sends real WhatsApp messages to '
            'teachers by itself, every week at the day and time set here.',
        action: 'Turn on',
      );
      if (!ok) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(updateWhatsappReminderProvider)(
        widget.reminder.id,
        {
          'enabled': _enabled,
          'gender': _gender,
          'city': _blankToNull(_city),
          'country': _blankToNull(_country),
          'levels': _levels.text.trim(),
          'lang': _lang,
          // Text that is not a whole number goes as it is, for the server to refuse.
          'leewayDays': int.tryParse(_leeway.text.trim()) ?? _leeway.text,
          'timezone': _timezone.text.trim(),
          'weekday': _weekday,
          'sendTime': _blankToNull(_sendTime),
          'scheduleOn': _scheduleOn,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = whatsappErrorWords(e);
      });
    }
  }

  Future<void> _run({required bool dryRun}) async {
    if (!dryRun) {
      final ok = await _confirm(
        title: 'Send for real?',
        body:
            'Real WhatsApp messages will go out to the teachers this '
            'reminder covers. Use the dry run first to see who.',
        action: 'Send messages',
      );
      if (!ok) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final runId = await ref.read(startWhatsappRunProvider)(
        widget.reminder.id,
        dryRun: dryRun,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => WhatsappRunScreen(runId: runId)),
      );
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
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    const gap = SizedBox(height: 12);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: Text(widget.reminder.name)),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder on'),
            subtitle: const Text('A reminder that is off cannot be run.'),
            value: _enabled,
            onChanged: _busy ? null : (v) => setState(() => _enabled = v),
          ),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: [
              for (final g in whatsappGenders)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _gender = v!),
          ),
          gap,
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          gap,
          TextField(
            controller: _country,
            decoration: const InputDecoration(labelText: 'Country'),
          ),
          gap,
          TextField(
            controller: _levels,
            decoration: const InputDecoration(
              labelText: 'Levels',
              helperText: 'Comma-separated, such as BILAL,AMMAR',
            ),
          ),
          gap,
          DropdownButtonFormField<String>(
            initialValue: _lang,
            decoration: const InputDecoration(labelText: 'Language'),
            items: [
              for (final l in whatsappLanguages)
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _lang = v!),
          ),
          gap,
          TextField(
            controller: _leeway,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Leeway in days',
              helperText: 'Grace period before a teacher is reminded',
            ),
          ),
          gap,
          TextField(
            controller: _timezone,
            decoration: const InputDecoration(
              labelText: 'Timezone',
              helperText: 'Such as Asia/Kolkata or America/Chicago',
            ),
          ),
          gap,
          DropdownButtonFormField<int?>(
            initialValue: _weekday,
            decoration: const InputDecoration(labelText: 'Day'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('No day')),
              for (var d = 1; d <= 7; d++)
                DropdownMenuItem<int?>(value: d, child: Text(weekdayName(d))),
            ],
            onChanged: _busy ? null : (v) => setState(() => _weekday = v),
          ),
          gap,
          TextField(
            controller: _sendTime,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Time',
              helperText: 'In the timezone above, such as 13:00',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Schedule on'),
            subtitle: const Text(
              'Sends real messages by itself at the day and time above.',
            ),
            value: _scheduleOn,
            onChanged: _busy ? null : (v) => setState(() => _scheduleOn = v),
          ),
          if (_error != null) ...[
            gap,
            Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
          ],
          gap,
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Run now', style: Theme.of(context).textTheme.titleMedium),
          Text('Uses the saved settings.', style: muted),
          gap,
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(dryRun: true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Dry run (sends nothing)'),
          ),
          gap,
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: _busy ? null : () => _run(dryRun: false),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send for real'),
          ),
        ],
      ),
    );
  }
}
