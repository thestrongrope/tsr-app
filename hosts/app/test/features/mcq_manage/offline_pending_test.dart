import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/mcq_manage/providers/mcq_manage_provider.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/mcq_manage_repository.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/offline_answers_store.dart';

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

void main() {
  late Directory dir;
  late Box box;
  late OfflineAnswersStore store;
  late _FakeRepository repository;

  Future<OfflinePendingNotifier> notifier() async {
    final n = OfflinePendingNotifier(10, store, repository);
    await n.record({
      101: {7},
      102: <int>{},
    });
    return n;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('offline_pending');
    Hive.init(dir.path);
    box = await Hive.openBox('offline_pending_test');
    store = OfflineAnswersStore(box, 9);
    repository = _FakeRepository();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('offline_pending_test');
    await dir.delete(recursive: true);
  });

  test(
    'recording keeps every chosen student on the device, answered or not',
    () async {
      final n = await notifier();

      expect(n.state, {
        101: {7},
        102: <int>{},
      });
      expect(store.count(10), 2);
    },
  );

  test('a submit sends everyone once and then clears the list', () async {
    final n = await notifier();
    final result = await n.submit();

    expect(result.saved, 2);
    expect(repository.sent, {
      101: {7},
      102: <int>{},
    });
    expect(n.state, isEmpty);
    expect(store.count(10), 0);
  });

  test('a failed submit keeps every answer and says so', () async {
    repository.failWith = const ApiException('Server error', 500);
    final n = await notifier();
    final result = await n.submit();

    expect(result.error, 'Server error');
    expect(result.saved, 0);
    expect(n.state.keys, [101, 102]);
    expect(store.count(10), 2);
  });

  test('no connection is a failed submit too', () async {
    repository.failWith = Exception('offline');
    final n = await notifier();
    final result = await n.submit();

    expect(result.error, isNotNull);
    expect(store.count(10), 2);
  });

  test('a 409 drops only the students who had already submitted', () async {
    repository.failWith = const ApiException(
      'One or more students already have submissions.',
      409,
      body: {
        'conflicts': [102],
      },
    );
    final n = await notifier();
    final result = await n.submit();

    expect(result.conflicts, [102]);
    expect(result.error, isNull);
    expect(n.state.keys, [101]);
    expect(store.pending(10).keys, [101]);
  });
}
