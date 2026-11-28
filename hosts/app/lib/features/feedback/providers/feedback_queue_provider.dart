import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/saved_copy.dart';
import '../../../core/utils/user_message.dart';
import '../../home/providers/recent_actions_provider.dart';
import '../repositories/feedback_repository.dart';
import '../services/feedback_queue_store.dart';

/// How often a message still waiting is tried again; see the conduction queue
/// for why the device being "online" is not enough.
const feedbackQueueRetryInterval = Duration(minutes: 1);

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(),
);

final feedbackQueueStoreProvider = Provider<FeedbackQueueStore>(
  (ref) => FeedbackQueueStore(),
);

/// A random (version 4) UUID, made once per message.
String newClientId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}

/// The signed-in member's unsent feedback, and the replay that sends it.
/// Watched from the app root, like the conduction queue: at app start, on
/// reconnect, and every [feedbackQueueRetryInterval] while a message waits.
/// A message the server refuses stays with the reason until the member
/// retries or discards it.
final feedbackQueueProvider =
    NotifierProvider<FeedbackQueueNotifier, List<QueuedFeedback>>(
      FeedbackQueueNotifier.new,
    );

class FeedbackQueueNotifier extends Notifier<List<QueuedFeedback>> {
  bool _replaying = false;

  int? get _token => ref.read(recentActionsMemberProvider);

  @override
  List<QueuedFeedback> build() {
    final token = ref.watch(recentActionsMemberProvider);
    ref.listen(isOfflineProvider, (was, offline) {
      if (!offline) replay();
    });
    final retry = Timer.periodic(feedbackQueueRetryInterval, (_) {
      if (state.any((i) => !i.failed)) replay();
    });
    ref.onDispose(retry.cancel);
    if (token == null) return const [];
    final saved = ref.read(feedbackQueueStoreProvider).read(token);
    if (saved.isNotEmpty) Future.microtask(replay);
    return saved;
  }

  /// Keeps [text] to send later under [clientId].
  Future<void> enqueue(String clientId, String text) async {
    final token = _token;
    if (token == null) return;
    final item = QueuedFeedback(
      clientId: clientId,
      payload: {'text': text},
      writtenAt: DateTime.now(),
    );
    await _save(token, [
      for (final i in state)
        if (i.clientId != clientId) i,
      item,
    ]);
  }

  /// Drops a message the member chose not to send.
  Future<void> discard(String clientId) async {
    final token = _token;
    if (token == null) return;
    await _save(token, [
      for (final i in state)
        if (i.clientId != clientId) i,
    ]);
  }

  /// Clears a refusal so [replay] tries the message again.
  Future<void> retry(String clientId) async {
    final token = _token;
    if (token == null) return;
    await _save(token, [
      for (final i in state) i.clientId == clientId ? i.withError(null) : i,
    ]);
    await replay();
  }

  /// Sends every unrefused message, oldest first. Stops at the first one the
  /// server cannot be reached for; a refusal marks that message and moves on.
  Future<void> replay() async {
    final token = _token;
    if (token == null || _replaying) return;
    _replaying = true;
    try {
      final repo = ref.read(feedbackRepositoryProvider);
      for (final item in state.where((i) => !i.failed).toList()) {
        try {
          await repo.send(item.clientId, item.text);
          if (!ref.mounted) return;
          await _save(token, [
            for (final i in state)
              if (i.clientId != item.clientId) i,
          ]);
        } catch (e) {
          if (isUnreachable(e) || !ref.mounted) return;
          debugPrint('🟡 Queued feedback refused: $e');
          await _save(token, [
            for (final i in state)
              i.clientId == item.clientId ? i.withError(userMessage(e)) : i,
          ]);
        }
      }
    } finally {
      _replaying = false;
    }
  }

  Future<void> _save(int token, List<QueuedFeedback> items) async {
    // A sign-out or a different member while a send was in flight rebuilds
    // this provider; the old replay must not write into the new one.
    if (!ref.mounted) return;
    state = items;
    await ref.read(feedbackQueueStoreProvider).write(token, items);
  }
}
