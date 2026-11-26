import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/feedback_item.dart';
import 'package:the_strong_rope/features/admin/providers/feedback_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/feedback_repository.dart';
import 'package:the_strong_rope/features/admin/screens/feedback_review_screen.dart';

class _FakeFeedbackRepository extends FeedbackRepository {
  _FakeFeedbackRepository(
    this.items, {
    this.failOnMutate = false,
    this.failOnFetch = false,
    this.pageSize = 50,
  });

  final List<FeedbackItem> items;
  final bool failOnMutate;
  final bool failOnFetch;
  final int pageSize;
  final List<int> fetchedPages = [];

  @override
  Future<FeedbackPage> fetchFeedback({int page = 1}) async {
    if (failOnFetch) throw Exception('Fetch failed');
    fetchedPages.add(page);
    final ordered = sortFeedbackItems(items);
    return FeedbackPage(
      items: ordered.skip((page - 1) * pageSize).take(pageSize).toList(),
      unhandledCount: items.where((i) => !i.isHandled).length,
      handledCount: items.where((i) => i.isHandled).length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<FeedbackItem> markHandled(int id) async {
    if (failOnMutate) throw Exception('Save failed');
    final item = items.firstWhere((i) => i.id == id);
    return item.copyWith(
      isHandled: true,
      handledAt: DateTime(2026, 11, 7, 12, 0),
      handledBy: 1,
    );
  }

  @override
  Future<FeedbackItem> markUnhandled(int id) async {
    if (failOnMutate) throw Exception('Save failed');
    final item = items.firstWhere((i) => i.id == id);
    return item.copyWith(isHandled: false, clearHandled: true);
  }
}

Widget _wrap(FeedbackRepository repo) {
  return ProviderScope(
    overrides: [feedbackRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: FeedbackReviewScreen()),
  );
}

void main() {
  final item1 = FeedbackItem(
    id: 1,
    text: 'Typo in Arabic quiz question',
    createdAt: DateTime(2026, 11, 6, 10, 30),
    sender: const FeedbackSender(name: 'Fatima Zehra', token: 2341),
    isHandled: false,
  );

  final item2 = FeedbackItem(
    id: 2,
    text: 'App crashes on orientation change',
    createdAt: DateTime(2026, 11, 5, 8, 0),
    sender: const FeedbackSender(name: 'Former member', token: null),
    isHandled: true,
    handledAt: DateTime(2026, 11, 5, 12, 0),
    handledBy: 10,
  );

  testWidgets('displays unhandled first with sender name and member number', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeFeedbackRepository([item1, item2])));
    await tester.pumpAndSettle();

    expect(find.text('Fatima Zehra (2341)'), findsOneWidget);
    expect(find.text('Typo in Arabic quiz question'), findsOneWidget);
    expect(find.text('1 unhandled'), findsOneWidget);
    expect(find.text('1 handled'), findsOneWidget);

    // Verify ordering: item1 (unhandled) appears before item2 (handled)
    final pos1 = tester.getTopLeft(find.text('Fatima Zehra (2341)')).dy;
    final pos2 = tester.getTopLeft(find.text('Former member')).dy;
    expect(pos1, lessThan(pos2));
  });

  testWidgets(
    'displays "Former member" without token when sender is missing or deleted',
    (tester) async {
      await tester.pumpWidget(_wrap(_FakeFeedbackRepository([item2])));
      await tester.pumpAndSettle();

      expect(find.text('Former member'), findsOneWidget);
      expect(find.textContaining('Former member ('), findsNothing);
    },
  );

  testWidgets(
    'tapping "Mark handled" moves item to handled and shows handled date',
    (tester) async {
      await tester.pumpWidget(_wrap(_FakeFeedbackRepository([item1])));
      await tester.pumpAndSettle();

      expect(find.text('1 unhandled'), findsOneWidget);
      expect(find.text('0 handled'), findsOneWidget);
      expect(find.text('Mark handled'), findsOneWidget);

      await tester.tap(find.text('Mark handled'));
      await tester.pumpAndSettle();

      expect(find.text('0 unhandled'), findsOneWidget);
      expect(find.text('1 handled'), findsOneWidget);
      expect(find.text('Mark unhandled'), findsOneWidget);
      expect(find.textContaining('Handled on'), findsOneWidget);
    },
  );

  testWidgets('tapping "Mark unhandled" restores item to unhandled queue', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeFeedbackRepository([item2])));
    await tester.pumpAndSettle();

    expect(find.text('0 unhandled'), findsOneWidget);
    expect(find.text('1 handled'), findsOneWidget);
    expect(find.text('Mark unhandled'), findsOneWidget);

    await tester.tap(find.text('Mark unhandled'));
    await tester.pumpAndSettle();

    expect(find.text('1 unhandled'), findsOneWidget);
    expect(find.text('0 handled'), findsOneWidget);
    expect(find.text('Mark handled'), findsOneWidget);
  });

  testWidgets('if saving fails, surfaces error and keeps item as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_FakeFeedbackRepository([item1], failOnMutate: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark handled'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Changes could not be saved'), findsOneWidget);
    // Item is restored to unhandled
    expect(find.text('Mark handled'), findsOneWidget);
    expect(find.text('1 unhandled'), findsOneWidget);
  });

  testWidgets('displays empty state when there are no items', (tester) async {
    await tester.pumpWidget(_wrap(_FakeFeedbackRepository([])));
    await tester.pumpAndSettle();

    expect(find.text('No feedback submitted yet'), findsOneWidget);
  });

  testWidgets('displays error view with retry when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_FakeFeedbackRepository([], failOnFetch: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a Load more button and appends the next page', (
    tester,
  ) async {
    final items = [
      for (var i = 1; i <= 3; i++)
        FeedbackItem(
          id: i,
          text: 'Message $i',
          createdAt: DateTime(2026, 11, i, 10),
          sender: const FeedbackSender(name: 'Fatima Zehra', token: 2341),
          isHandled: false,
        ),
    ];
    final repo = _FakeFeedbackRepository(items, pageSize: 2);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('3 unhandled'), findsOneWidget);
    expect(find.text('Message 3'), findsOneWidget);
    expect(find.text('Message 1'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Load more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(repo.fetchedPages, [1, 2]);
    expect(find.text('Message 1', skipOffstage: false), findsOneWidget);
    expect(find.text('Load more', skipOffstage: false), findsNothing);
  });

  group('FeedbackItem.copyWith', () {
    test('clearHandled removes handledAt and handledBy', () {
      final cleared = item2.copyWith(isHandled: false, clearHandled: true);
      expect(cleared.handledAt, isNull);
      expect(cleared.handledBy, isNull);
    });

    test('keeps handledAt when not asked to clear it', () {
      expect(item2.copyWith(text: 'x').handledAt, item2.handledAt);
    });
  });

  group('FeedbackNotifier.toggleHandled', () {
    FeedbackItem fb(int id) => FeedbackItem(
      id: id,
      text: 'Message $id',
      createdAt: DateTime(2026, 11, id, 10),
      sender: const FeedbackSender(name: 'Fatima Zehra', token: 2341),
      isHandled: false,
    );

    test(
      'a failed toggle does not undo a later toggle of another item',
      () async {
        final repo = _GatedRepository([fb(1), fb(2)]);
        final container = ProviderContainer(
          overrides: [feedbackRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        container.listen(feedbackNotifierProvider, (_, _) {});
        await container.read(feedbackNotifierProvider.future);
        final notifier = container.read(feedbackNotifierProvider.notifier);

        final first = notifier.toggleHandled(1);
        final second = notifier.toggleHandled(2);
        repo.complete(2, ok: true);
        await second;
        repo.complete(1, ok: false);
        await expectLater(first, throwsException);

        final queue = container.read(feedbackNotifierProvider).requireValue;
        expect(queue.items.firstWhere((i) => i.id == 1).isHandled, isFalse);
        expect(queue.items.firstWhere((i) => i.id == 2).isHandled, isTrue);
        expect(queue.unhandledCount, 1);
        expect(queue.handledCount, 1);
      },
    );

    test('a failed toggle leaves the data state, not an error', () async {
      final repo = _GatedRepository([fb(1)]);
      final container = ProviderContainer(
        overrides: [feedbackRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(feedbackNotifierProvider, (_, _) {});
      await container.read(feedbackNotifierProvider.future);

      final toggle = container
          .read(feedbackNotifierProvider.notifier)
          .toggleHandled(1);
      repo.complete(1, ok: false);
      await expectLater(toggle, throwsException);

      expect(container.read(feedbackNotifierProvider).hasError, isFalse);
      expect(
        container.read(feedbackNotifierProvider).requireValue.unhandledCount,
        1,
      );
    });
  });
}

/// A repository whose mutations finish when the test says so.
class _GatedRepository extends FeedbackRepository {
  _GatedRepository(this.items);

  final List<FeedbackItem> items;
  final Map<int, Completer<bool>> _gates = {};

  void complete(int id, {required bool ok}) => _gates[id]!.complete(ok);

  @override
  Future<FeedbackPage> fetchFeedback({int page = 1}) async => FeedbackPage(
    items: items,
    unhandledCount: items.length,
    handledCount: 0,
    page: 1,
    pageSize: 50,
  );

  @override
  Future<FeedbackItem> markHandled(int id) async {
    final ok = await (_gates[id] = Completer<bool>()).future;
    if (!ok) throw Exception('Save failed');
    return items
        .firstWhere((i) => i.id == id)
        .copyWith(isHandled: true, handledAt: DateTime(2026, 11, 7, 12));
  }
}
