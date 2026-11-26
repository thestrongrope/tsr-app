import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/saved_copy.dart';
import '../../../core/utils/user_message.dart';
import '../../home/providers/recent_actions_provider.dart';
import '../services/conduction_queue_store.dart';
import 'classes_provider.dart';

/// How often a record still waiting is tried again. The device reporting
/// "online" does not mean the server is reachable, and a send that fails then
/// would otherwise wait for the next connectivity change or an app restart.
const conductionQueueRetryInterval = Duration(minutes: 1);

final conductionQueueStoreProvider = Provider<ConductionQueueStore>(
  (ref) => ConductionQueueStore(),
);

/// The signed-in member's unsent conduction records, and the replay that sends
/// them. Watched from the app root so it runs whichever screen is open: at app
/// start, each time the device comes back online, and every
/// [conductionQueueRetryInterval] while a record is still waiting.
///
/// Only a new record is queued; an edit needs the server's current copy.
/// A record the server refuses (permission revoked, class closed, a record by
/// someone else for that date) stays in the list with the reason and is never
/// dropped silently.
final conductionQueueProvider =
    NotifierProvider<ConductionQueueNotifier, List<QueuedConduction>>(
      ConductionQueueNotifier.new,
    );

class ConductionQueueNotifier extends Notifier<List<QueuedConduction>> {
  bool _replaying = false;

  int? get _token => ref.read(recentActionsMemberProvider);

  @override
  List<QueuedConduction> build() {
    final token = ref.watch(recentActionsMemberProvider);
    ref.listen(isOfflineProvider, (was, offline) {
      if (!offline) replay();
    });
    final retry = Timer.periodic(conductionQueueRetryInterval, (_) {
      if (state.any((i) => !i.failed)) replay();
    });
    ref.onDispose(retry.cancel);
    if (token == null) return const [];
    final saved = ref.read(conductionQueueStoreProvider).read(token);
    if (saved.isNotEmpty) Future.microtask(replay);
    return saved;
  }

  /// Adds [payload] for [classId], replacing an unsent record for the same
  /// date. [payload] must carry `conductedOn` and `recordedAt`.
  Future<void> enqueue(int classId, Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null) return;
    final item = QueuedConduction(
      classId: classId,
      conductedOn: (payload['conductedOn'] as String).split('T').first,
      payload: payload,
    );
    await _save(token, [
      for (final i in state)
        if (i.key != item.key) i,
      item,
    ]);
  }

  /// Drops a record the teacher chose not to send.
  Future<void> discard(String key) async {
    final token = _token;
    if (token == null) return;
    await _save(token, [
      for (final i in state)
        if (i.key != key) i,
    ]);
  }

  /// Clears a refusal so [replay] tries the record again.
  Future<void> retry(String key) async {
    final token = _token;
    if (token == null) return;
    await _save(token, [
      for (final i in state) i.key == key ? i.withError(null) : i,
    ]);
    await replay();
  }

  /// Sends every unrefused record, oldest first. Stops at the first one the
  /// server cannot be reached for, so the order is kept; a refusal marks that
  /// record and moves on to the next.
  Future<void> replay() async {
    final token = _token;
    if (token == null || _replaying) return;
    _replaying = true;
    try {
      final repo = ref.read(classesRepositoryProvider);
      for (final item in state.where((i) => !i.failed).toList()) {
        try {
          await repo.addConduction(item.classId, item.payload);
          if (!ref.mounted) return;
          await _save(token, [
            for (final i in state)
              if (i.key != item.key) i,
          ]);
          ref.invalidate(conductionSessionsProvider);
        } catch (e) {
          if (isUnreachable(e) || !ref.mounted) return;
          debugPrint('🟡 Queued conduction refused: $e');
          await _save(token, [
            for (final i in state)
              i.key == item.key ? i.withError(userMessage(e)) : i,
          ]);
        }
      }
    } finally {
      _replaying = false;
    }
  }

  Future<void> _save(int token, List<QueuedConduction> items) async {
    // A sign-out or a different member while a send was in flight rebuilds
    // this provider; the old replay must not write into the new one.
    if (!ref.mounted) return;
    state = items;
    await ref.read(conductionQueueStoreProvider).write(token, items);
  }
}
