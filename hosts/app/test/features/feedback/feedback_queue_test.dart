import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/features/feedback/providers/feedback_queue_provider.dart';
import 'package:the_strong_rope/features/feedback/repositories/feedback_repository.dart';
import 'package:the_strong_rope/features/feedback/services/feedback_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';

/// A server that answers each text the way the test says, and records the
/// client ids it was sent.
class ScriptedFeedbackRepository extends FeedbackRepository {
  final sentIds = <String>[];
  final Map<String, ApiException> answers = {};

  @override
  Future<int> send(String clientId, String text) async {
    final answer = answers[text];
    if (answer != null) throw answer;
    sentIds.add(clientId);
    return 1;
  }
}

class _Offline extends OfflineNotifier {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

const _unreachable = ApiException('offline', 0);

void main() {
  late Directory dir;
  late Box box;
  late ScriptedFeedbackRepository repo;
  late ProviderContainer container;
  late _Offline offline;

  ProviderContainer build({int? member = 100}) {
    offline = _Offline();
    return ProviderContainer(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(member),
        feedbackQueueStoreProvider.overrideWithValue(FeedbackQueueStore(box)),
        feedbackRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith(() => offline),
      ],
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_feedback_queue');
    Hive.init(dir.path);
    box = await Hive.openBox(AppConstants.settingsBoxKey);
    repo = ScriptedFeedbackRepository();
    container = build();
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  FeedbackQueueNotifier notifier() =>
      container.read(feedbackQueueProvider.notifier);

  QueuedFeedback only() => container.read(feedbackQueueProvider).single;

  QueuedFeedback item(String id, String text) => QueuedFeedback(
    clientId: id,
    payload: {'text': text},
    writtenAt: DateTime.utc(2026, 11, 8),
  );

  group('store', () {
    test('keeps a message, its payload and its refusal across a reload', () {
      final store = FeedbackQueueStore(box);
      store.write(100, [
        QueuedFeedback(
          clientId: 'abc',
          payload: {'text': 'Hello', 'later': 1},
          writtenAt: DateTime.utc(2026, 11, 8),
          error: 'Too long',
        ),
      ]);

      final back = store.read(100).single;
      expect(back.clientId, 'abc');
      expect(back.text, 'Hello');
      expect(back.payload['later'], 1);
      expect(back.error, 'Too long');
    });

    test('one member never reads another member\'s queue', () async {
      final store = FeedbackQueueStore(box);
      await store.write(100, [item('a', 'Hello')]);

      expect(store.read(200), isEmpty);
    });

    test('clearAll removes every queue and nothing else', () async {
      final store = FeedbackQueueStore(box);
      await box.put('theme', 'dark');
      await store.write(100, [item('a', 'One')]);
      await store.write(200, [item('b', 'Two')]);

      await store.clearAll();

      expect(store.read(100), isEmpty);
      expect(store.read(200), isEmpty);
      expect(box.get('theme'), 'dark');
    });
  });

  group('queue', () {
    test('a client id is a version 4 UUID, new each time', () {
      final id = newClientId();

      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
      expect(newClientId(), isNot(id));
    });

    test('a guest has no queue', () async {
      container.dispose();
      container = build(member: null);

      await notifier().enqueue('a', 'Hello');

      expect(container.read(feedbackQueueProvider), isEmpty);
    });

    test('nothing is sent while the server cannot be reached', () async {
      repo.answers['Hello'] = _unreachable;

      await notifier().enqueue('a', 'Hello');
      await notifier().replay();

      expect(repo.sentIds, isEmpty);
      expect(only().failed, isFalse, reason: 'still waiting, not refused');
    });

    test('coming back online sends the message and removes it', () async {
      repo.answers['Hello'] = _unreachable;
      final queue = notifier();
      offline.set(true);
      await queue.enqueue('a', 'Hello');
      await notifier().replay();
      expect(container.read(feedbackQueueProvider), hasLength(1));

      repo.answers.clear();
      offline.set(false);
      while (container.read(feedbackQueueProvider).isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(repo.sentIds, ['a']);
      expect(FeedbackQueueStore(box).read(100), isEmpty);
    });

    test('the same client id is sent on every resend', () async {
      repo.answers['Hello'] = _unreachable;
      final seen = <String>[];
      final spy = _SpyRepository(seen);
      container.dispose();
      container = ProviderContainer(
        overrides: [
          recentActionsMemberProvider.overrideWithValue(100),
          feedbackQueueStoreProvider.overrideWithValue(FeedbackQueueStore(box)),
          feedbackRepositoryProvider.overrideWithValue(spy),
          isOfflineProvider.overrideWith(() => _Offline()),
        ],
      );

      await notifier().enqueue('fixed-id', 'Hello');
      await notifier().replay();
      await notifier().replay();

      expect(seen, ['fixed-id', 'fixed-id']);
      expect(only().clientId, 'fixed-id');
    });

    test('a refused message stays with the reason and does not block '
        'the next one', () async {
      repo.answers['Bad'] = const ApiException('Too long', 422);

      await notifier().enqueue('a', 'Bad');
      await notifier().enqueue('b', 'Good');
      await notifier().replay();

      final left = only();
      expect(left.clientId, 'a');
      expect(left.error, 'Too long');
      expect(repo.sentIds, ['b']);
    });

    test('retry sends a refused message once the cause is gone', () async {
      repo.answers['Bad'] = const ApiException('Too long', 422);
      await notifier().enqueue('a', 'Bad');
      await notifier().replay();
      expect(only().failed, isTrue);

      repo.answers.clear();
      await notifier().retry('a');

      expect(container.read(feedbackQueueProvider), isEmpty);
      expect(repo.sentIds, ['a']);
    });

    test('discard drops only the chosen message', () async {
      repo.answers['One'] = _unreachable;
      repo.answers['Two'] = _unreachable;
      await notifier().enqueue('a', 'One');
      await notifier().enqueue('b', 'Two');

      await notifier().discard('a');

      expect(only().clientId, 'b');
    });

    test('messages saved before the app was closed are sent on start', () async {
      await FeedbackQueueStore(box).write(100, [item('a', 'Hello')]);
      container.dispose();
      container = build();

      container.read(feedbackQueueProvider);
      while (container.read(feedbackQueueProvider).isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(repo.sentIds, ['a']);
    });
  });
}

class _SpyRepository extends FeedbackRepository {
  _SpyRepository(this.seen);

  final List<String> seen;

  @override
  Future<int> send(String clientId, String text) async {
    seen.add(clientId);
    throw _unreachable;
  }
}
