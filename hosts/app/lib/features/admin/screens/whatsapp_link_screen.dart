import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/services/secure_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../models/whatsapp_link.dart';
import '../providers/whatsapp_link_provider.dart';
import '../repositories/whatsapp_link_repository.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// How often the status and the QR code are asked for while the screen is shown.
const whatsappLinkPollSeconds = 3;

const _differentPhone =
    'Scan this code from a different phone than the one showing it. On that '
    'phone open WhatsApp, then Settings, Linked devices, Link a device.';

const _interrupts =
    'Every scheduled reminder, for gents and ladies, stops sending until the '
    'code is scanned again.';

/// The WhatsApp link: its state, the QR code to scan, Re-link and Logout (#693).
/// The web page's counterpart; the server shows it to those who hold
/// `whatsapp:manage`.
///
/// The QR code is a live credential, so it lives in this State and nowhere else:
/// no provider, cache or storage, never logged. It is dropped, and polling stops,
/// when the app leaves the foreground and when the screen closes.
/// While it is open the window is secure on Android (no screenshots, recording
/// or recent-apps thumbnail); dispose clears that.
class WhatsappLinkScreen extends ConsumerStatefulWidget {
  const WhatsappLinkScreen({super.key});

  @override
  ConsumerState<WhatsappLinkScreen> createState() => _WhatsappLinkScreenState();
}

class _WhatsappLinkScreenState extends ConsumerState<WhatsappLinkScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _polling = false;
  bool _busy = false;
  int _ticks = 0;

  WhatsappLinkStatus? _status;
  WhatsappLinkQr? _qr;

  /// Seconds since [_qr] was fetched, so its age keeps counting between polls.
  int _qrSeconds = 0;
  String? _problem;
  String? _notice;
  String? _failure;

  bool get _allowed =>
      ref.read(capabilitiesProvider).canManageWhatsappReminders;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_allowed) {
      SecureScreen.enable();
      _start();
    }
  }

  @override
  void dispose() {
    SecureScreen.disable();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _qr = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_timer == null && _allowed) _start();
    } else {
      _stop();
    }
  }

  void _start() {
    _ticks = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _ticks++;
      if (_ticks % whatsappLinkPollSeconds == 0) {
        _poll();
      } else if (mounted) {
        setState(() => _qrSeconds++);
      }
    });
    _poll();
  }

  /// Stops asking and forgets the code.
  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _qr = null);
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    final repo = ref.read(whatsappLinkRepositoryProvider);
    try {
      final status = await repo.getStatus();
      final qr = status.state == WhatsappLinkState.waiting
          ? await repo.getQr()
          : null;
      if (!mounted || _timer == null) return;
      setState(() {
        _status = status;
        _qr = qr;
        _qrSeconds = 0;
        _problem = null;
      });
    } catch (e) {
      if (!mounted || _timer == null) return;
      // Never keep showing a code that could not be refreshed.
      setState(() {
        _qr = null;
        _problem = whatsappLinkErrorWords(e);
      });
    } finally {
      _polling = false;
    }
  }

  Future<bool> _confirm(String title, String action, String effect) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('$effect $_interrupts'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<void> _change({
    required String title,
    required String action,
    required String effect,
    required Future<void> Function() call,
    required String done,
  }) async {
    if (!await _confirm(title, action, effect) || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
      _notice = null;
    });
    try {
      await call();
      if (!mounted) return;
      setState(() => _notice = done);
      await _poll();
    } catch (e) {
      if (!mounted) return;
      // The previous state stays shown.
      setState(() => _failure = whatsappLinkErrorWords(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _relink() => _change(
    title: 'Re-link WhatsApp?',
    action: 'Re-link',
    effect: 'This clears the current session and shows a new code.',
    call: ref.read(whatsappLinkRepositoryProvider).relink,
    done: 'The session was cleared. A new code will appear shortly.',
  );

  void _logout() => _change(
    title: 'Log out of WhatsApp?',
    action: 'Log out',
    effect: "This ends the session on WhatsApp's side.",
    call: ref.read(whatsappLinkRepositoryProvider).logout,
    done: 'Logged out. Reminders will not send until WhatsApp is linked again.',
  );

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(capabilitiesProvider).canManageWhatsappReminders;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('WhatsApp link')),
      body: !allowed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('You do not have access to this.'),
              ),
            )
          : ListView(
              padding: withTabBarInset(context, const EdgeInsets.all(16)),
              children: _content(),
            ),
    );
  }

  List<Widget> _content() {
    final status = _status;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.mediumText,
    );
    return [
      if (status == null && _problem == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (status != null) ...[
        _StatusRow(status: status),
        if (!status.isConnected) ...[
          const SizedBox(height: 8),
          const Text(
            'Scheduled reminders are not being delivered until WhatsApp is '
            'linked.',
          ),
        ],
      ],
      if (_problem != null) ...[
        const SizedBox(height: 12),
        Text(_problem!, style: TextStyle(color: AppTheme.errorRed)),
        Text(
          'Trying again every $whatsappLinkPollSeconds seconds.',
          style: muted,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _poll,
            child: const Text('Try again now'),
          ),
        ),
      ],
      if (_notice != null) ...[const SizedBox(height: 12), Text(_notice!)],
      if (_failure != null) ...[
        const SizedBox(height: 12),
        Text(_failure!, style: TextStyle(color: AppTheme.errorRed)),
      ],
      if (status?.state == WhatsappLinkState.waiting && _problem == null) ...[
        const SizedBox(height: 16),
        _QrCard(qr: _qr, secondsSinceFetch: _qrSeconds),
      ],
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _busy ? null : _relink,
        child: const Text('Re-link WhatsApp'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _busy ? null : _logout,
        child: const Text('Log out of WhatsApp'),
      ),
      const SizedBox(height: 8),
      Text(
        'Re-link clears the session and shows a new code. Log out also tells '
        'WhatsApp to forget it: use it to switch to a different phone.',
        style: muted,
      ),
    ];
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final WhatsappLinkStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (status.state) {
      WhatsappLinkState.connected => ('Connected', AppTheme.successGreen),
      WhatsappLinkState.waiting => ('Waiting for a scan', Colors.amber),
      WhatsappLinkState.offline => ('Offline', AppTheme.errorRed),
    };
    final seen = status.lastSeen;
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: colour),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        if (seen != null) ...[
          const SizedBox(width: 8),
          Text(
            'last seen ${_ago(DateTime.now().difference(seen))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

/// The code to scan, its age, and the different-phone notice. A code older than
/// it stays scannable, or one that could not be refreshed, is not drawn.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.qr, required this.secondsSinceFetch});

  final WhatsappLinkQr? qr;
  final int secondsSinceFetch;

  @override
  Widget build(BuildContext context) {
    final qr = this.qr;
    final code = qr?.code;
    final age = (qr?.ageSeconds ?? 0) + secondsSinceFetch;
    final current = qr != null && code != null && age < qr.validSeconds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              _differentPhone,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (current) ...[
              Center(
                child: QrImageView(
                  data: code,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text('Code made $age s ago')),
            ] else
              Text(
                qr?.code == null && qr?.ageSeconds == null
                    ? 'Waiting for WhatsApp to make a code.'
                    : 'That code has expired. Waiting for a new one.',
              ),
          ],
        ),
      ),
    );
  }
}
