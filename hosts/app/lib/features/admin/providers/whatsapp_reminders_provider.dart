import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whatsapp_reminders.dart';
import '../repositories/whatsapp_reminders_repository.dart';

/// Every reminder.
final whatsappRemindersProvider =
    FutureProvider.autoDispose<List<WhatsappReminder>>(
      (ref) => WhatsappRemindersRepository().getReminders(),
      retry: (retryCount, error) => null,
    );

/// Recent runs of every reminder.
final whatsappRunsProvider = FutureProvider.autoDispose<List<WhatsappRun>>(
  (ref) => WhatsappRemindersRepository().getRuns(),
  retry: (retryCount, error) => null,
);

/// One run with each teacher it handled, by run id.
final whatsappRunProvider = FutureProvider.autoDispose
    .family<WhatsappRunDetail, int>(
      (ref, id) => WhatsappRemindersRepository().getRun(id),
      retry: (retryCount, error) => null,
    );

/// Saves a reminder's settings: (reminder id, the fields to change).
typedef UpdateWhatsappReminder =
    Future<WhatsappReminder> Function(int id, Map<String, dynamic> fields);

final updateWhatsappReminderProvider = Provider<UpdateWhatsappReminder>(
  (ref) =>
      (id, fields) => WhatsappRemindersRepository().updateReminder(id, fields),
);

/// Starts a run and returns its id.
typedef StartWhatsappRun =
    Future<int> Function(int reminderId, {required bool dryRun});

final startWhatsappRunProvider = Provider<StartWhatsappRun>(
  (ref) =>
      (reminderId, {required dryRun}) =>
          WhatsappRemindersRepository().startRun(reminderId, dryRun: dryRun),
);

/// Sends one real message to one number.
typedef SendWhatsappTest =
    Future<void> Function({required String mobile, required String message});

final sendWhatsappTestProvider = Provider<SendWhatsappTest>(
  (ref) =>
      ({required mobile, required message}) => WhatsappRemindersRepository()
          .sendTest(mobile: mobile, message: message),
);
