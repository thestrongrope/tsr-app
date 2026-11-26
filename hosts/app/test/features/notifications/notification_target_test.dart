import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/grand_quiz/models/models.dart';
import 'package:the_strong_rope/features/grand_quiz/providers/grand_quiz_provider.dart';
import 'package:the_strong_rope/features/grand_quiz/repositories/grand_quiz_repository.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/notifications/providers/notification_target.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// Answers class and quiz lookups with the given failure, or not at all.
class _FakeRepository extends ClassesRepository {
  _FakeRepository(this.failure);

  final Object? failure;
  final asked = <String>[];

  @override
  Future<ClassModel> getClassDetail(int classId) async {
    asked.add('class $classId');
    if (failure != null) throw failure!;
    throw StateError('stop: a success needs no model here');
  }

  @override
  Future<ConductionListResponse> getConductionSessions(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    asked.add('conduction $classId');
    if (failure != null) throw failure!;
    throw StateError('stop: a success needs no model here');
  }

  @override
  Future<Quiz> getQuizDetail(int quizId) async {
    asked.add('quiz $quizId');
    if (failure != null) throw failure!;
    throw StateError('stop: a success needs no model here');
  }
}

QuizInfo _quiz({required String status, bool canTakePart = true}) =>
    QuizInfo.fromJson({
      'status': status,
      'name': 'Invented Quiz',
      'can_take_part': canTakePart,
    });

/// Answers the quiz info call with [quiz], or with a failure when it is null.
class _FakeQuizRepository extends GrandQuizRepository {
  _FakeQuizRepository(this.quiz);

  final QuizInfo? quiz;
  int asked = 0;

  @override
  Future<QuizInfoResponse> getQuizInfo({
    User? currentUser,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) asked++;
    final quiz = this.quiz;
    if (quiz == null) {
      return const QuizInfoResponse(success: false, error: 'offline');
    }
    return QuizInfoResponse(success: true, data: quiz);
  }
}

class _FakeWeb extends TsrWebService {
  _FakeWeb(this.failure);

  final Object failure;
  final asked = <String>[];

  @override
  Future<TsrArticle> getArticle(String slug) async {
    asked.add(slug);
    throw failure;
  }
}

Future<NotificationTarget> _checkArticle(String link, Object failure) async {
  final web = _FakeWeb(failure);
  final container = ProviderContainer(
    overrides: [tsrWebServiceProvider.overrideWithValue(web)],
  );
  addTearDown(container.dispose);
  final target = await container.read(notificationTargetCheckerProvider)(link);
  expect(web.asked, [link.substring('/articles/'.length)]);
  return target;
}

Future<(NotificationTarget, List<String>)> _check(
  String link,
  Object? failure,
) async {
  final repository = _FakeRepository(failure);
  final container = ProviderContainer(
    overrides: [classesRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  final target = await container.read(notificationTargetCheckerProvider)(link);
  return (target, repository.asked);
}

void main() {
  test('a 403 on a class or quiz is a refusal', () async {
    const refused = ApiException('no', 403);
    expect(
      (await _check('/classes/5/dashboard', refused)).$1,
      NotificationTarget.noAccess,
    );
    expect(
      (await _check('/quizzes/7', refused)).$1,
      NotificationTarget.noAccess,
    );
  });

  test('a 404 on a class or quiz is gone', () async {
    const missing = ApiException('no', 404);
    expect((await _check('/classes/5', missing)).$1, NotificationTarget.gone);
    expect((await _check('/quizzes/7', missing)).$1, NotificationTarget.gone);
  });

  test(
    'the class and quiz named in the link are the ones asked about',
    () async {
      expect(
        (await _check('/classes/5/dashboard', const ApiException('x', 404))).$2,
        ['class 5'],
      );
      expect((await _check('/quizzes/7', const ApiException('x', 404))).$2, [
        'quiz 7',
      ]);
    },
  );

  test(
    'a fault or being offline is not a verdict; the link is opened',
    () async {
      expect(
        (await _check('/quizzes/7', const ApiException('x', 500))).$1,
        NotificationTarget.open,
      );
      expect(
        (await _check('/classes/5', const ApiException('x', 408))).$1,
        NotificationTarget.open,
      );
    },
  );

  group('the quiz announcement link', () {
    Future<(NotificationTarget, int)> checkQuiz(
      _FakeQuizRepository repository,
    ) async {
      final container = ProviderContainer(
        overrides: [
          grandQuizRepositoryProvider.overrideWithValue(repository),
          currentUserProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      final target = await container.read(notificationTargetCheckerProvider)(
        AppRoutes.homeQuiz,
      );
      return (target, repository.asked);
    }

    test('a live or upcoming quiz opens', () async {
      for (final status in ['upcoming', 'registered', 'live']) {
        final repository = _FakeQuizRepository(_quiz(status: status));
        expect((await checkQuiz(repository)).$1, NotificationTarget.open);
        expect(repository.asked, 1, reason: 'asked afresh, not from the cache');
      }
    });

    test('an offline or ended quiz is gone', () async {
      for (final status in ['offline', 'ended']) {
        final repository = _FakeQuizRepository(_quiz(status: status));
        expect((await checkQuiz(repository)).$1, NotificationTarget.gone);
      }
    });

    test('a member the quiz leaves out has no access', () async {
      final repository = _FakeQuizRepository(
        _quiz(status: 'upcoming', canTakePart: false),
      );
      expect((await checkQuiz(repository)).$1, NotificationTarget.noAccess);
    });

    test('a quiz that cannot be loaded is not a verdict', () async {
      final repository = _FakeQuizRepository(null);
      expect((await checkQuiz(repository)).$1, NotificationTarget.open);
    });

    test('the answer says whether the member can take part', () {
      expect(
        QuizInfo.fromJson({'status': 'live', 'can_take_part': false})
            .canTakePart,
        isFalse,
      );
      expect(QuizInfo.fromJson({'status': 'live'}).canTakePart, isTrue);
    });
  });

  test('a link that is neither a class nor a quiz is not checked', () async {
    final result = await _check('/home', const ApiException('x', 404));
    expect(result.$1, NotificationTarget.open);
    expect(result.$2, isEmpty);
  });

  testWidgets('a video that cannot be launched shows the text and the reason', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final done = openNotificationTarget(
      context,
      check: (_) async => NotificationTarget.open,
      destination: const NotificationDestination.link('/videos/abc123'),
      title: 'New video',
      body: 'Watch it now',
      sentAt: DateTime(2026, 10, 29),
      launchVideo: (_) async => false,
    );
    await tester.pumpAndSettle();
    await done;
    expect(find.text('This could not be opened.'), findsOneWidget);
    expect(find.text('Watch it now'), findsOneWidget);
  });

  testWidgets('a fallback without a sent time does not show the tap time', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final done = openNotificationTarget(
      context,
      check: (_) async => NotificationTarget.gone,
      destination: const NotificationDestination.link('/videos/abc123'),
      title: 'New video',
      body: 'Watch it now',
    );
    await tester.pumpAndSettle();
    await done;
    expect(find.text('Watch it now'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{4} · ')), findsNothing);
  });

  test('an article the site no longer has is gone', () async {
    expect(
      await _checkArticle('/articles/old-post', const ApiException('x', 404)),
      NotificationTarget.gone,
    );
  });

  test('an article check that faults is not a verdict; it is opened', () async {
    expect(
      await _checkArticle('/articles/a-post', Exception('offline')),
      NotificationTarget.open,
    );
    expect(
      await _checkArticle('/articles/a-post', const ApiException('x', 500)),
      NotificationTarget.open,
    );
  });

  test('a conduction link asks the conduction list, not the class', () async {
    for (final link in ['/classes/5/conduction', '/classes/5/conduction/add']) {
      final result = await _check(link, const ApiException('x', 404));
      expect(result.$2, ['conduction 5'], reason: link);
    }
  });

  test('a 403 or 404 on a conduction link is a refusal or gone', () async {
    for (final link in ['/classes/5/conduction', '/classes/5/conduction/add']) {
      expect(
        (await _check(link, const ApiException('no', 403))).$1,
        NotificationTarget.noAccess,
        reason: link,
      );
      expect(
        (await _check(link, const ApiException('no', 404))).$1,
        NotificationTarget.gone,
        reason: link,
      );
    }
  });

  test('a fault on a conduction link is not a verdict; it is opened', () async {
    expect(
      (await _check(
        '/classes/5/conduction/add',
        const ApiException('x', 500),
      )).$1,
      NotificationTarget.open,
    );
  });
}
