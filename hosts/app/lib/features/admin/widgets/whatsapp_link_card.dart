import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_home.dart';
import '../../../core/theme/app_theme.dart';
import '../models/whatsapp_link.dart';
import '../providers/whatsapp_link_provider.dart';
import '../screens/whatsapp_link_screen.dart';

/// On the reminders screen (#693): the WhatsApp link's state, a warning while it
/// is not connected (scheduled reminders are not delivered), and the way to the
/// link screen. Shown only to those who hold `whatsapp:manage`.
class WhatsappLinkCard extends ConsumerWidget {
  const WhatsappLinkCard({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WhatsappLinkScreen()));
    ref.invalidate(whatsappLinkStatusProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capabilitiesProvider).mayManageWhatsappReminders) {
      return const SizedBox.shrink();
    }
    final status = ref.watch(whatsappLinkStatusProvider);
    final (headline, warning) = status.when(
      loading: () => ('Checking the WhatsApp link...', null),
      error: (_, _) => ('Could not check the WhatsApp link.', null),
      data: (s) => switch (s.state) {
        WhatsappLinkState.connected => ('WhatsApp is linked.', null),
        WhatsappLinkState.waiting => (
          'WhatsApp is waiting to be linked.',
          'Scheduled reminders will not be delivered until it is linked.',
        ),
        WhatsappLinkState.offline => (
          'WhatsApp is not linked.',
          'Scheduled reminders will not be delivered until it is linked.',
        ),
      },
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          warning == null ? Icons.link : Icons.link_off,
          color: warning == null ? null : AppTheme.errorRed,
        ),
        title: Text(headline),
        subtitle: warning == null ? null : Text(warning),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context, ref),
      ),
    );
  }
}
