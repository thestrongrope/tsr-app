import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/providers/conduction_queue_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';

/// Kept in memory: Hive's file I/O never completes inside fake async. The
/// store's own round trip is covered in conduction_queue_test.dart.
class _MemoryStore extends ConductionQueueStore {
  final _saved = <int, List<QueuedConduction>>{};

  @override
  List<QueuedConduction> read(int token) => _saved[token] ?? const [];

  @override
  Future<void> write(int token, List<QueuedConduction> items) async =>
      _saved[token] = items;
}

/// A server that is unreachable until the test says otherwise.
class _Repository extends ClassesRepository {
  bool reachable = false;
  ApiException? refusal;
  int attempts = 0;

  @override
  Future<ConductionSession> addConduction(
    int classId,
    Map<String, dynamic> payload,
  ) async {
    attempts++;
    if (refusal != null) throw refusal!;
    if (!reachable) throw const ApiException('offline', 0);
    return ConductionSession(
      id: 1,
      conductedOn: DateTime.parse(payload['conductedOn'] as String),
      conducted: true,
    );
  }
}

class _Online extends OfflineNotifier {
  @override
  bool build() => false;
}

void main() {
  late _Repository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repository();
    container = ProviderContainer(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(100),
        conductionQueueStoreProvider.overrideWithValue(_MemoryStore()),
        classesRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith(_Online.new),
      ],
    );
  });

  Map<String, dynamic> payload() => {
    'conductedOn': '2026-10-20',
    'recordedAt': '2026-10-20T08:30:00.000Z',
  };

  testWidgets('a record that met an unreachable server is tried again by '
      'itself', (tester) async {
    final queue = container.read(conductionQueueProvider.notifier);
    await queue.enqueue(7, payload());

    await queue.replay();
    expect(repo.attempts, 1);
    expect(container.read(conductionQueueProvider), hasLength(1));

    repo.reachable = true;
    await tester.pump(conductionQueueRetryInterval);

    expect(repo.attempts, 2);
    expect(container.read(conductionQueueProvider), isEmpty);
    container.dispose();
  });

  testWidgets('a refused record is not retried on the timer', (tester) async {
    final queue = container.read(conductionQueueProvider.notifier);
    await queue.enqueue(7, payload());
    await queue.replay();

    // Refused, not unreachable: the record is marked and left alone.
    repo.refusal = const ApiException('Class is closed', 403);
    await queue.retry(container.read(conductionQueueProvider).single.key);
    final before = repo.attempts;

    await tester.pump(conductionQueueRetryInterval * 3);

    expect(repo.attempts, before);
    expect(container.read(conductionQueueProvider).single.failed, isTrue);
    container.dispose();
  });

  testWidgets('an empty queue sends nothing on the timer', (tester) async {
    container.read(conductionQueueProvider);

    await tester.pump(conductionQueueRetryInterval * 3);

    expect(repo.attempts, 0);
    container.dispose();
  });
}
