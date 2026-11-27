import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/grand_quiz/providers/grand_quiz_provider.dart';
import 'package:the_strong_rope/features/grand_quiz/repositories/grand_quiz_repository.dart';

/// A repository whose server is whatever the test says it is.
class _ScriptedRepository extends GrandQuizRepository {
  _ScriptedRepository({super.clock});

  Object? next;
  int fetches = 0;

  @override
  Future<bool> hasFirebaseToken() async => false;

  @override
  Future<Map<String, dynamic>> fetchQuizInfoJson() async {
    fetches++;
    final result = next;
    if (result is ApiException) throw result;
    return result as Map<String, dynamic>;
  }
}

/// Records the request the repository makes and answers [body].
class _RecordingApi implements ApiClient {
  final requests = <(String, Map<String, dynamic>?)>[];

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests.add((path, queryParameters));
    return <String, dynamic>{'status': 'offline', 'message': 'x'} as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A repository whose secure storage cannot be read.
class _BrokenStorage extends GrandQuizRepository {
  @override
  Future<bool> hasFirebaseToken() async => throw StateError('storage');
}

/// The body `GET /quiz/info` sends for a live Grand quiz: the object itself,
/// with no `{success, data}` wrapper.
Map<String, dynamic> _liveGrand({String name = 'Invented Quiz'}) => {
  'type': 'grand',
  'name': name,
  'series': 'S1',
  'description': '5 Dec',
  'status': 'live',
  'message': 'Quiz is now live! Click the link to participate.',
  'is_superuser': false,
  'timing': {
    'registration_start': '2026-12-01T09:00:00+00:00',
    'quiz_start': '2026-12-05T20:00:00+00:00',
    'quiz_end': '2026-12-05T22:00:00+00:00',
    'quiz_stop': '2026-12-06T00:00:00+00:00',
  },
  'episode': {
    'id': 1,
    'start': '2026-12-05T20:00:00+00:00',
    'end': '2026-12-05T22:00:00+00:00',
    'participation': null,
    'form_id': 'FORM1',
  },
  'banner': null,
  'colors': {
    'primary': '#ae3242',
    'secondary': '#510d25',
    'background': '#ffffff',
    'text': '#000000',
  },
  'mode': 'Live',
  'youtube_url': 'https://www.youtube.com/thestrongrope',
  'admin_url': null,
  'auth': {'method': 'none', 'can_register': false, 'user_token': null},
  'can_take_part': true,
};

void main() {
  late Directory dir;
  late _ScriptedRepository repository;
  var now = DateTime.utc(2026, 12, 5, 20);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('grand_quiz_repository');
    Hive.init(dir.path);
    now = DateTime.utc(2026, 12, 5, 20);
    repository = _ScriptedRepository(clock: () => now);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('the route is the API\'s, kept for the 60 seconds its copy lives', () {
    expect(AppConstants.quizInfoEndpoint, '/quiz/info');
    expect(AppConstants.quizInfoCacheDuration, const Duration(seconds: 60));
  });

  test(
    'the request goes through the API client to /quiz/info, with no token parameter and no address of its own',
    () async {
      final api = _RecordingApi();

      await GrandQuizRepository(
        apiClient: api,
        clock: () => now,
      ).fetchQuizInfoJson();

      final (path, query) = api.requests.single;
      expect(path, '/quiz/info');
      expect(
        path,
        isNot(contains('://')),
        reason: 'a path, so the client\'s base address applies',
      );
      expect(path, isNot(contains('token')));
      expect(query, anyOf(isNull, isEmpty));
    },
  );

  test(
    'a storage that cannot be read is an unexpected error, not a crash',
    () async {
      final response = await _BrokenStorage().getQuizInfo();

      expect(response.success, isFalse);
      expect(response.error, 'An unexpected error occurred');
    },
  );

  test('the body is read as it is, with no wrapper', () async {
    repository.next = _liveGrand();

    final response = await repository.getQuizInfo();

    expect(response.success, isTrue);
    expect(response.data!.name, 'Invented Quiz');
    expect(response.data!.status, 'live');
    expect(response.data!.auth.method, 'none');
    expect(response.data!.canTakePart, isTrue);
  });

  test('an offline body has just a status and a message', () async {
    repository.next = {
      'status': 'offline',
      'message': 'No quiz is currently configured',
    };

    final response = await repository.getQuizInfo();

    expect(response.success, isTrue);
    expect(response.data!.shouldDisplayBanner, isFalse);
  });

  test(
    'a copy under 60 seconds old is used and an older one is fetched again',
    () async {
      repository.next = _liveGrand(name: 'First');
      await repository.getQuizInfo();

      now = now.add(const Duration(seconds: 59));
      repository.next = _liveGrand(name: 'Second');
      expect((await repository.getQuizInfo()).data!.name, 'First');
      expect(repository.fetches, 1);

      now = now.add(const Duration(seconds: 1));
      expect((await repository.getQuizInfo()).data!.name, 'Second');
      expect(repository.fetches, 2);
    },
  );

  test('a forced refresh fetches although the copy is fresh', () async {
    repository.next = _liveGrand(name: 'First');
    await repository.getQuizInfo();

    repository.next = _liveGrand(name: 'Second');
    final response = await repository.getQuizInfo(forceRefresh: true);

    expect(response.data!.name, 'Second');
  });

  test('a network error returns the copy while it is fresh', () async {
    repository.next = _liveGrand();
    await repository.getQuizInfo();

    now = now.add(const Duration(seconds: 30));
    repository.next = const ApiException('offline', 0);
    final response = await repository.getQuizInfo(forceRefresh: true);

    expect(response.success, isTrue);
    expect(response.data!.name, 'Invented Quiz');
  });

  for (final failure in {
    'offline': (const ApiException('x', 0), 'No internet connection'),
    'slow': (const ApiException('x', 408), 'timed out'),
    'refused': (const ApiException('x', 429), 'Too many requests'),
    'bearer refused': (const ApiException('x', 401), 'Server error'),
  }.entries) {
    test(
      '${failure.key}, with nothing saved: a failure that says so',
      () async {
        repository.next = failure.value.$1;

        final response = await repository.getQuizInfo();

        expect(response.success, isFalse);
        expect(response.error, contains(failure.value.$2));
      },
    );
  }

  test('quiz info held in the provider goes stale after 60 seconds', () {
    final fresh = GrandQuizState(
      lastFetch: DateTime.now().subtract(const Duration(seconds: 30)),
    );
    final old = GrandQuizState(
      lastFetch: DateTime.now().subtract(const Duration(seconds: 61)),
    );

    expect(fresh.isStale, isFalse);
    expect(old.isStale, isTrue);
    expect(const GrandQuizState().isStale, isTrue);
  });
}
