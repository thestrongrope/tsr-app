import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_offline.dart';
import 'package:the_strong_rope/features/mcq_manage/providers/mcq_manage_provider.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/mcq_manage_repository.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/offline_answers_store.dart';
import 'package:the_strong_rope/features/mcq_manage/screens/mcq_offline_screen.dart';

const _data = McqOfflineData(
  quizName: 'Wudu',
  topic: 'Taharat',
  questions: [
    OfflineQuestion(
      id: 7,
      question: 'Which water?',
      options: [
        OfflineOption(text: 'Najis', isCorrect: false),
        OfflineOption(text: 'Pure', isCorrect: true),
      ],
    ),
    OfflineQuestion(
      id: 8,
      question: 'How many?',
      options: [OfflineOption(text: 'Four', isCorrect: true)],
    ),
  ],
  students: [
    OfflineStudent(token: 101, name: 'Ali', isOffline: true, submitted: false),
    OfflineStudent(
      token: 102,
      name: 'Zayd',
      isOffline: false,
      submitted: false,
    ),
    OfflineStudent(token: 103, name: 'Hasan', isOffline: true, submitted: true),
  ],
);

class _FakeRepository extends McqManageRepository {
  Object? failWith;
  Map<int, Set<int>>? sent;

  @override
  Future<void> saveOffline(
    int quizId,
    Map<int, Set<int>> correctByToken,
  ) async {
    sent = correctByToken;
    if (failWith != null) throw failWith!;
  }
}

/// A Hive box in memory: real Hive does file I/O, which never completes under
/// the widget tester's fake clock. The persistence itself is covered by
/// offline_answers_store_test.dart against a real box.
class _MemoryBox implements Box {
  final Map<dynamic, dynamic> _data = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data.containsKey(key) ? _data[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(dynamic key) async => _data.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late OfflineAnswersStore store;
  late _FakeRepository repository;

  setUp(() {
    store = OfflineAnswersStore(_MemoryBox(), 9);
    repository = _FakeRepository();
  });

  Widget wrap({ShareMcqSheet? share}) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      mcqOfflineProvider.overrideWith((ref, quizId) async => _data),
      offlineAnswersStoreProvider.overrideWithValue(store),
      mcqManageRepositoryProvider.overrideWithValue(repository),
      if (share != null) shareMcqSheetProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: McqOfflineScreen(quizId: 10)),
  );

  testWidgets(
    'shows students without a phone by default, and everyone on request',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Zayd'), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Zayd'), findsOneWidget);
    },
  );

  testWidgets('a student who already submitted is shown and cannot be chosen', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Already submitted'), findsOneWidget);
    await tester.tap(find.text('Hasan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose students'),
      findsOneWidget,
      reason: 'nobody chosen',
    );
  });

  testWidgets(
    'stepping through marks who was right; an unmarked question stays wrong',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record answers (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('Which water?'), findsOneWidget);
      // Ali got question 1 right and leaves question 2 unmarked.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ali'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Question 2 of 2'), findsOneWidget);
      await tester.tap(find.text('Save on this device'));
      await tester.pumpAndSettle();

      expect(store.pending(10), {
        101: {7},
      });
      expect(
        find.textContaining('1 student(s) saved on this device'),
        findsOneWidget,
      );
    },
  );

  testWidgets('pending answers show a count and survive a rebuilt screen', (
    tester,
  ) async {
    await store.put(10, 101, {7});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 student(s) saved on this device'),
      findsOneWidget,
    );
    expect(find.text('Submit 1'), findsOneWidget);
  });

  testWidgets('a failed submit keeps the answers and says so', (tester) async {
    await store.put(10, 101, {7});
    repository.failWith = const ApiException('Server error', 500);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit 1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('still saved on this device'), findsOneWidget);
    expect(store.count(10), 1);
  });

  testWidgets('a successful submit sends the batch and clears the count', (
    tester,
  ) async {
    await store.put(10, 101, {7});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit 1'));
    await tester.pumpAndSettle();

    expect(repository.sent, {
      101: {7},
    });
    expect(store.count(10), 0);
    expect(find.textContaining('saved on this device, not yet'), findsNothing);
  });

  testWidgets('the question sheet is handed to the share sheet', (
    tester,
  ) async {
    final shared = <int>[];
    await tester.pumpWidget(
      wrap(share: (quizId, name) async => shared.add(quizId)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Question sheet'));
    await tester.pumpAndSettle();

    expect(shared, [10]);
  });

  testWidgets('a sheet that cannot be fetched says so', (tester) async {
    await tester.pumpWidget(
      wrap(share: (quizId, name) async => throw Exception('no')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Question sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Could not get the question sheet.'), findsOneWidget);
  });
}
