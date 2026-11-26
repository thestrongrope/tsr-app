import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whatsapp_link.dart';
import '../repositories/whatsapp_link_repository.dart';

final whatsappLinkRepositoryProvider = Provider<WhatsappLinkRepository>(
  (ref) => WhatsappLinkRepository(),
);

/// The link's state, asked once for the warning on the reminders screen. The
/// link screen polls for itself; the QR code has no provider on purpose.
final whatsappLinkStatusProvider =
    FutureProvider.autoDispose<WhatsappLinkStatus>(
      (ref) => ref.watch(whatsappLinkRepositoryProvider).getStatus(),
      retry: (retryCount, error) => null,
    );
