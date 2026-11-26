import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/app_router.dart';
import 'startup_alert.dart';
import 'version_provider.dart';

/// Shows the startup alerts once, over whatever screen the app opens on.
///
/// Wraps the app in `main.dart`'s `builder`. It never delays startup: it reads
/// the already-running [versionCheckProvider] and does nothing until that has
/// resolved, so an unresolved or failed fetch means no alert, no wait and no
/// error. A required update never reaches here — the blocking screen replaces
/// the whole app before the router exists.
class StartupAlertHost extends ConsumerStatefulWidget {
  final Widget child;

  const StartupAlertHost({super.key, required this.child});

  @override
  ConsumerState<StartupAlertHost> createState() => _StartupAlertHostState();
}

class _StartupAlertHostState extends ConsumerState<StartupAlertHost> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(versionCheckProvider).asData?.value;
    if (check != null && !_handled) {
      _handled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(check));
    }
    return widget.child;
  }

  Future<void> _show(VersionCheck check) async {
    try {
      final store = ref.read(startupAlertStoreProvider);
      final alerts = dueStartupAlerts(
        status: check.status,
        policy: check.policy,
        announcement: check.announcement,
        dismissedReleaseBuild: store.dismissedReleaseBuild,
        dismissedAnnouncementId: store.dismissedAnnouncementId,
      );

      for (final alert in alerts) {
        final context = await _navigatorContext();
        if (context == null || !context.mounted) return;

        switch (alert) {
          case ReleaseAlert():
            final updated = await showDialog<bool>(
              context: context,
              builder: (_) => _ReleaseDialog(alert: alert),
            );
            // Going to the store is not a dismissal: a member who comes back
            // without updating is asked again.
            if (updated != true) await store.dismissRelease(alert.build);
          case AnnouncementAlert():
            await showDialog<void>(
              context: context,
              builder: (_) => _AnnouncementDialog(alert: alert),
            );
            await store.dismissAnnouncement(alert.announcement.id);
        }
      }
    } catch (e) {
      // An alert is a courtesy: whatever goes wrong, the app carries on.
      debugPrint('Startup alert skipped: $e');
    }
  }

  /// The root navigator's context, which exists only once the router has built
  /// its first frame. Waits a few frames for it rather than blocking startup.
  Future<BuildContext?> _navigatorContext() async {
    for (var attempt = 0; attempt < 30; attempt++) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) return context;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }
}

class _ReleaseDialog extends StatelessWidget {
  final ReleaseAlert alert;

  const _ReleaseDialog({required this.alert});

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.tryParse(alert.storeUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What's new in ${alert.version}",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (alert.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final note in alert.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  $note'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        if (alert.storeUrl.isNotEmpty)
          FilledButton(
            onPressed: () => _openStore(context),
            child: const Text('Update'),
          ),
      ],
    );
  }
}

class _AnnouncementDialog extends StatelessWidget {
  final AnnouncementAlert alert;

  const _AnnouncementDialog({required this.alert});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(alert.announcement.title),
      content: alert.announcement.body.isEmpty
          ? null
          : SingleChildScrollView(child: Text(alert.announcement.body)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
