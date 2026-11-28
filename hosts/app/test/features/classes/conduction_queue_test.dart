import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/providers/conduction_queue_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';

/// A server that answers each unsent record the way the test says.
class _ScriptedRepository extends ClassesRepository {
  final sent = <int>[];
  final Map<String, Object> answers = {};

  @override
  Future<ConductionSession> addConduction(
    int classId,
    Map<String, dynamic> payload,
  ) async {
    final answer = answers[payload['conductedOn']];
    if (answer is ApiException) throw answer;
    sent.add(classId);
    return ConductionSession(
      id: 1,
      conductedOn: DateTime.parse(payload['conductedOn'] as String),
      conducted: true,
    );
  }
}

class _Offline extends OfflineNotifier {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

Map<String, dynamic> _payload(String date) => {
  'conductedOn': date,
  'recordedAt': '2026-10-20T08:30:00.000Z',
};

void main() {
  late Directory dir;
  late Box box;
  late _ScriptedRepository repo;
  late ProviderContainer container;
  late _Offline offline;

  ProviderContainer build({int? member = 100}) {
    offline = _Offline();
    return ProviderContainer(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(member),
        conductionQueueStoreProvider.overrideWithValue(
          ConductionQueueStore(box),
        ),
        classesRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith(() => offline),
      ],
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_conduction_queue');
    Hive.init(dir.path);
    box = await Hive.openBox(AppConstants.settingsBoxKey);
    repo = _ScriptedRepository();
    container = build();
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  QueuedConduction only() => container.read(conductionQueueProvider).single;

  group('store', () {
    test('keeps a record, its payload and its refusal across a reload', () {
      final store = ConductionQueueStore(box);
      final item = QueuedConduction(
        classId: 7,
        conductedOn: '2026-10-20',
        payload: {
          ..._payload('2026-10-20'),
          'students': [
            {'token': 1, 'present': true},
          ],
        },
        error: 'Class is closed',
      );
      store.write(100, [item]);

      final back = store.read(100).single;
      expect(back.key, '7:2026-10-20');
      expect(back.error, 'Class is closed');
      expect((back.payload['students'] as List).single['present'], true);
    });

    test('one member never reads another member\'s queue', () async {
      final store = ConductionQueueStore(box);
      await store.write(100, [
        QueuedConduction(
          classId: 7,
          conductedOn: '2026-10-20',
          payload: _payload('2026-10-20'),
        ),
      ]);

      expect(store.read(200), isEmpty);
    });

    test('clearAll removes every member\'s queue and nothing else', () async {
      final store = ConductionQueueStore(box);
      await box.put('theme', 'dark');
      for (final token in [100, 200]) {
        await store.write(token, [
          QueuedConduction(
            classId: 7,
            conductedOn: '2026-10-20',
            payload: _payload('2026-10-20'),
          ),
        ]);
      }

      await store.clearAll();

      expect(store.read(100), isEmpty);
      expect(store.read(200), isEmpty);
      expect(box.get('theme'), 'dark');
    });
  });

  group('queue', () {
    test('saving the same class and date twice keeps one record', () async {
      final n = container.read(conductionQueueProvider.notifier);
      offline.set(true);
      repo.answers['2026-10-20'] = const ApiException('offline', 0);

      await n.enqueue(7, {..._payload('2026-10-20'), 'duration': 30});
      await n.enqueue(7, {..._payload('2026-10-20'), 'duration': 45});

      expect(only().payload['duration'], 45);
    });

    test('a guest has no queue', () async {
      container.dispose();
      container = build(member: null);

      await container
          .read(conductionQueueProvider.notifier)
          .enqueue(7, _payload('2026-10-20'));

      expect(container.read(conductionQueueProvider), isEmpty);
    });

    test('nothing is sent while the server cannot be reached', () async {
      repo.answers['2026-10-20'] = const ApiException('offline', 0);
      final n = container.read(conductionQueueProvider.notifier);

      await n.enqueue(7, _payload('2026-10-20'));
      await n.replay();

      expect(repo.sent, isEmpty);
      expect(only().failed, isFalse, reason: 'still waiting, not refused');
    });

    test('coming back online sends the record and removes it', () async {
      repo.answers['2026-10-20'] = const ApiException('offline', 0);
      final n = container.read(conductionQueueProvider.notifier);
      offline.set(true);
      await n.enqueue(7, _payload('2026-10-20'));
      await n.replay();
      expect(container.read(conductionQueueProvider), hasLength(1));

      repo.answers.clear();
      offline.set(false);
      while (container.read(conductionQueueProvider).isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(repo.sent, [7]);
      expect(container.read(conductionQueueProvider), isEmpty);
      expect(ConductionQueueStore(box).read(100), isEmpty);
    });

    test('a refused record stays with the reason and does not block '
        'the next one', () async {
      repo.answers['2026-10-20'] = const ApiException('Class is closed', 403);
      final n = container.read(conductionQueueProvider.notifier);

      await n.enqueue(7, _payload('2026-10-20'));
      await n.enqueue(7, _payload('2026-10-21'));
      await n.replay();

      final left = container.read(conductionQueueProvider).single;
      expect(left.conductedOn, '2026-10-20');
      expect(left.error, 'Class is closed');
      expect(repo.sent, [7], reason: 'the second record was still sent');
    });

    test('retry sends a refused record once the cause is gone', () async {
      repo.answers['2026-10-20'] = const ApiException('Class is closed', 403);
      final n = container.read(conductionQueueProvider.notifier);
      await n.enqueue(7, _payload('2026-10-20'));
      await n.replay();
      expect(only().failed, isTrue);

      repo.answers.clear();
      await n.retry(only().key);

      expect(container.read(conductionQueueProvider), isEmpty);
      expect(repo.sent, [7]);
    });

    test('discard drops only the chosen record', () async {
      repo.answers['2026-10-20'] = const ApiException('offline', 0);
      repo.answers['2026-10-21'] = const ApiException('offline', 0);
      final n = container.read(conductionQueueProvider.notifier);
      await n.enqueue(7, _payload('2026-10-20'));
      await n.enqueue(7, _payload('2026-10-21'));

      await n.discard('7:2026-10-20');

      expect(only().conductedOn, '2026-10-21');
    });

    test('records saved before the app was closed are sent on start', () async {
      await ConductionQueueStore(box).write(100, [
        QueuedConduction(
          classId: 7,
          conductedOn: '2026-10-20',
          payload: _payload('2026-10-20'),
        ),
      ]);
      container.dispose();
      container = build();

      container.read(conductionQueueProvider);
      while (container.read(conductionQueueProvider).isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(repo.sent, [7]);
      expect(container.read(conductionQueueProvider), isEmpty);
    });
  });
}
