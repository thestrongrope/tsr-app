import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback_item.dart';
import '../repositories/feedback_repository.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository();
});

List<FeedbackItem> sortFeedbackItems(List<FeedbackItem> items) {
  final copy = List<FeedbackItem>.from(items);
  copy.sort((a, b) {
    if (a.isHandled != b.isHandled) {
      return a.isHandled ? 1 : -1;
    }
    if (!a.isHandled) {
      return b.createdAt.compareTo(a.createdAt);
    }
    final aHandled = a.handledAt ?? a.createdAt;
    final bHandled = b.handledAt ?? b.createdAt;
    return bHandled.compareTo(aHandled);
  });
  return copy;
}

class FeedbackNotifier extends AsyncNotifier<FeedbackQueue> {
  @override
  Future<FeedbackQueue> build() async {
    final page = await ref.watch(feedbackRepositoryProvider).fetchFeedback();
    return FeedbackQueue(
      items: sortFeedbackItems(page.items),
      unhandledCount: page.unhandledCount,
      handledCount: page.handledCount,
      page: page.page,
      pageSize: page.pageSize,
    );
  }

  /// Appends the next page. Items already shown are kept once: a toggle moves
  /// an item between sections, so a page boundary can repeat one.
  Future<void> loadMore() async {
    final queue = state.asData?.value;
    if (queue == null || !queue.hasMore) return;

    final page = await ref
        .read(feedbackRepositoryProvider)
        .fetchFeedback(page: queue.page + 1);

    final latest = state.asData?.value ?? queue;
    final known = latest.items.map((i) => i.id).toSet();
    final added = page.items.where((i) => !known.contains(i.id));
    state = AsyncData(
      latest.copyWith(
        items: sortFeedbackItems([...latest.items, ...added]),
        unhandledCount: page.unhandledCount,
        handledCount: page.handledCount,
        page: queue.page + 1,
      ),
    );
  }

  /// Toggles handled state with an optimistic update.
  ///
  /// Every change replaces only this item in the latest state, so a failure
  /// restores this item and leaves any toggle made meanwhile as it is.
  /// A failed save rethrows after the item is restored.
  Future<void> toggleHandled(int id) async {
    final original = _find(id);
    if (original == null) return;

    final target = !original.isHandled;
    _replace(
      original.copyWith(
        isHandled: target,
        handledAt: target ? DateTime.now() : null,
        clearHandled: !target,
      ),
    );

    final repo = ref.read(feedbackRepositoryProvider);
    try {
      _replace(
        target ? await repo.markHandled(id) : await repo.markUnhandled(id),
      );
    } catch (_) {
      _replace(original);
      rethrow;
    }
  }

  FeedbackItem? _find(int id) {
    final items = state.asData?.value.items ?? const <FeedbackItem>[];
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Swaps [updated] in for the item with its id and moves the counts when the
  /// handled state differs.
  void _replace(FeedbackItem updated) {
    final queue = state.asData?.value;
    final before = _find(updated.id);
    if (queue == null || before == null) return;

    final delta = before.isHandled == updated.isHandled
        ? 0
        : (updated.isHandled ? 1 : -1);
    state = AsyncData(
      queue.copyWith(
        items: sortFeedbackItems([
          for (final item in queue.items)
            item.id == updated.id ? updated : item,
        ]),
        unhandledCount: queue.unhandledCount - delta,
        handledCount: queue.handledCount + delta,
      ),
    );
  }
}

final feedbackNotifierProvider =
    AsyncNotifierProvider.autoDispose<FeedbackNotifier, FeedbackQueue>(
      FeedbackNotifier.new,
    );
