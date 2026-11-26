import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/admin/models/quiz_admin.dart';
import 'package:the_strong_rope/features/admin/providers/quiz_admin_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/quiz_admin_repository.dart';
import 'package:the_strong_rope/features/admin/screens/quiz_admin_screen.dart';

import 'quiz_admin_test.dart' show megaBody;

class _Permissions extends PermissionsNotifier {
  _Permissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(),
        issuedAt: '',
      ),
    );
  }
}

/// The server, as the screen sees it: fixtures in, calls recorded, nothing
/// reaches the network or a sheet.
class _FakeRepository implements QuizAdminRepository {
  _FakeRepository(this.body);

  Map<String, dynamic> body;
  final calls = <String>[];
  int stateReads = 0;

  /// Thrown by the next action, if set.
  Object? fail;
  Completer<QuizActionResult>? pending;
  QuizActionResult answer = const QuizActionResult(
    complete: true,
    message: 'Done.',
    changed: true,
  );

  Future<QuizActionResult> _act(String call) {
    calls.add(call);
    if (fail != null) return Future.error(fail!);
    return pending?.future ?? Future.value(answer);
  }

  @override
  Future<QuizAdminState> getState() async {
    stateReads++;
    return QuizAdminState.fromJson(body);
  }

  @override
  Future<QuizActionResult> refreshSettings() => _act('refresh');

  @override
  Future<QuizActionResult> download() => _act('download');

  @override
  Future<QuizActionResult> generate(String kind) => _act('generate:$kind');

  @override
  Future<QuizActionResult> regenerate(String kind) => _act('regenerate:$kind');

  @override
  Future<QuizActionResult> publish(String what) => _act('publish:$what');

  @override
  Future<QuizActionResult> deleteAll() => _act('delete-all');
}

Map<String, dynamic> _grandBody() {
  final body = megaBody();
  (body['settings'] as Map<String, dynamic>)['kind'] = 'grand';
  return body;
}

Map<String, dynamic> _allowed(Map<String, dynamic> body) {
  (body['gates'] as Map<String, dynamic>)['generate'] = {
    'allowed': true,
    'reason': null,
  };
  return body;
}

Future<_FakeRepository> _open(
  WidgetTester tester,
  Map<String, dynamic> body, {
  List<String> permissions = const ['quiz:admin:all'],
}) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = _FakeRepository(body);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quizAdminRepositoryProvider.overrideWithValue(repo),
        permissionsProvider.overrideWith((ref) => _Permissions(permissions)),
      ],
      child: const MaterialApp(home: QuizAdminScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _key(String name) => find.byKey(Key(name));

bool _enabled(WidgetTester tester, String name) {
  final widget = tester.widget(_key(name));
  if (widget is FilledButton) return widget.enabled;
  return (widget as OutlinedButton).enabled;
}

Future<void> _tap(WidgetTester tester, String name) async {
  await tester.tap(_key(name));
  await tester.pumpAndSettle();
}

/// Taps a prize's Reveal and lets the scramble finish.
Future<void> _reveal(WidgetTester tester, int prize) async {
  await tester.tap(_key('reveal-button-$prize'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('a Mega quiz shows its settings, the download and the table', (
    tester,
  ) async {
    await _open(tester, megaBody());

    expect(find.text('Quiz: Mega'), findsOneWidget);
    expect(find.text('Series: Series A'), findsOneWidget);
    expect(find.text('Quiz day: 2'), findsOneWidget);
    expect(find.text('Not downloaded yet.'), findsOneWidget);
    expect(_key('quiz-refresh'), findsOneWidget);
    expect(_key('quiz-download'), findsOneWidget);
    expect(_key('quiz-eligibility'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    for (final name in [
      'quiz-generate-daily',
      'quiz-regenerate-daily',
      'quiz-generate-mega_student',
      'quiz-regenerate-mega_student',
      'quiz-publish-scoreboard',
      'quiz-publish-winners',
      'quiz-publish-mega_student',
    ]) {
      expect(_key(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('a blocked episode disables generating and shows the reason', (
    tester,
  ) async {
    final repo = await _open(tester, megaBody());

    expect(_enabled(tester, 'quiz-generate-daily'), isFalse);
    expect(_enabled(tester, 'quiz-regenerate-daily'), isFalse);
    expect(find.text('Episode 2 is blocked.'), findsWidgets);
    expect(
      find.textContaining('Episode 2 is blocked: Only 0 people passed'),
      findsOneWidget,
    );
    await tester.tap(_key('quiz-generate-daily'));
    await tester.pump();
    expect(repo.calls, isEmpty);
  });

  testWidgets('the overall Mega winner is hidden until the server offers it', (
    tester,
  ) async {
    await _open(tester, megaBody());
    expect(_key('quiz-generate-mega'), findsNothing);
    expect(_key('quiz-regenerate-mega'), findsNothing);
    expect(_key('quiz-publish-mega'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _open(tester, megaBody(offered: true));
    expect(_key('quiz-generate-mega'), findsOneWidget);
    expect(_key('quiz-regenerate-mega'), findsOneWidget);
    expect(_key('quiz-publish-mega'), findsOneWidget);
    expect(
      _enabled(tester, 'quiz-publish-mega'),
      isFalse,
      reason: 'nothing drawn to publish yet',
    );
  });

  testWidgets('a Grand quiz offers its own actions and no push', (
    tester,
  ) async {
    await _open(tester, _allowed(_grandBody()));

    expect(find.text('Quiz: Grand'), findsOneWidget);
    expect(_key('quiz-generate-grand'), findsOneWidget);
    expect(_key('quiz-regenerate-grand'), findsOneWidget);
    expect(_key('quiz-download'), findsOneWidget);
    expect(find.text('Public sheet'), findsNothing);
    for (final name in [
      'quiz-publish-scoreboard',
      'quiz-publish-winners',
      'quiz-publish-mega',
      'quiz-publish-mega_student',
      'quiz-generate-daily',
      'quiz-generate-mega',
      'quiz-generate-mega_student',
    ]) {
      expect(_key(name), findsNothing, reason: name);
    }
  });

  testWidgets('regenerate names what is replaced and waits for the yes', (
    tester,
  ) async {
    final repo = await _open(tester, _allowed(megaBody()));

    await _tap(tester, 'quiz-regenerate-daily');
    expect(find.text('Regenerate the daily winners?'), findsOneWidget);
    expect(find.textContaining('replaces the daily winners'), findsOneWidget);
    expect(find.textContaining('1 episode has winners now'), findsOneWidget);
    expect(find.textContaining('kept in a record'), findsOneWidget);
    expect(repo.calls, isEmpty, reason: 'nothing before the confirmation');

    await _tap(tester, 'quiz-cancel');
    expect(repo.calls, isEmpty);

    await _tap(tester, 'quiz-regenerate-daily');
    await _tap(tester, 'quiz-confirm');
    expect(repo.calls, ['regenerate:daily']);
  });

  testWidgets('resetting the Grand winners confirms first', (tester) async {
    final repo = await _open(tester, _allowed(_grandBody()));

    await _tap(tester, 'quiz-regenerate-grand');
    expect(find.text('Reset the Grand winners?'), findsOneWidget);
    expect(find.textContaining('replaces every Grand winner'), findsOneWidget);
    await _tap(tester, 'quiz-cancel');
    expect(repo.calls, isEmpty);

    await _tap(tester, 'quiz-regenerate-grand');
    await _tap(tester, 'quiz-confirm');
    expect(repo.calls, ['regenerate:grand']);
  });

  testWidgets('publishing says it replaces the public sheet, and waits', (
    tester,
  ) async {
    final repo = await _open(tester, _allowed(megaBody()));

    await _tap(tester, 'quiz-publish-scoreboard');
    expect(find.text('Publish the scoreboard?'), findsOneWidget);
    expect(find.textContaining('to the public sheet'), findsOneWidget);
    expect(find.textContaining('replacing what is shown'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await _tap(tester, 'quiz-cancel');
    expect(repo.calls, isEmpty);

    await _tap(tester, 'quiz-publish-scoreboard');
    await _tap(tester, 'quiz-confirm');
    expect(repo.calls, ['publish:scoreboard']);
  });

  testWidgets('delete-all is hidden without quiz:reset', (tester) async {
    await _open(tester, megaBody());
    expect(_key('quiz-delete-all'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _open(tester, _grandBody());
    expect(_key('quiz-delete-all'), findsNothing);
  });

  testWidgets('delete-all names what is lost, and only a yes deletes', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      megaBody(),
      permissions: ['quiz:admin:all', 'quiz:reset:all'],
    );

    await _tap(tester, 'quiz-delete-all');
    expect(find.text('Delete all quiz data?'), findsOneWidget);
    expect(find.textContaining('every winner drawn'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await _tap(tester, 'quiz-cancel');
    expect(repo.calls, isEmpty);

    await _tap(tester, 'quiz-delete-all');
    await _tap(tester, 'quiz-confirm');
    expect(repo.calls, ['delete-all']);
  });

  testWidgets('a shortfall is shown as incomplete, with drawn and missing', (
    tester,
  ) async {
    final repo = await _open(tester, _allowed(megaBody()));
    repo.answer = const QuizActionResult(
      complete: false,
      message: 'Drew 2 of 3.',
      changed: true,
      drawn: 2,
      missing: 1,
      draws: [
        QuizDrawRow(episode: 1, prize: 2, drawn: 1, missing: 1),
        QuizDrawRow(episode: 1, prize: 1, drawn: 1, missing: 0),
      ],
    );

    await _tap(tester, 'quiz-generate-daily');

    expect(find.text('Drew 2 of 3.'), findsOneWidget);
    expect(find.text('Drawn 2, missing 1.'), findsOneWidget);
    expect(
      find.text('Episode 1, prize 2: drawn 1, missing 1.'),
      findsOneWidget,
    );
    expect(find.text('Episode 1, prize 1: drawn 1, missing 0.'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets('a publish that wrote nothing says nothing was published', (
    tester,
  ) async {
    final repo = await _open(tester, _allowed(megaBody()));
    repo.answer = const QuizActionResult(
      complete: true,
      message: 'Nothing was published: the sheet range is not set.',
      changed: false,
      rows: 0,
    );

    await _tap(tester, 'quiz-publish-scoreboard');
    await _tap(tester, 'quiz-confirm');

    expect(find.textContaining('Nothing was published'), findsOneWidget);
  });

  testWidgets('a busy quiz shows the server\'s busy message', (tester) async {
    final repo = await _open(tester, _allowed(megaBody()));
    repo.fail = const ApiException(
      'Another quiz admin action is running. Try again in a moment.',
      409,
    );

    await _tap(tester, 'quiz-generate-daily');

    expect(
      find.text('Another quiz admin action is running. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('a 502 on publish says nothing was published', (tester) async {
    final repo = await _open(tester, _allowed(megaBody()));
    repo.fail = const ApiException(
      'The public sheet could not be reached. Nothing was changed or published.',
      502,
    );

    await _tap(tester, 'quiz-publish-scoreboard');
    await _tap(tester, 'quiz-confirm');

    expect(
      find.textContaining('Nothing was changed or published'),
      findsOneWidget,
    );
  });

  testWidgets('a timeout on download reloads the state and says the result '
      'is unknown', (tester) async {
    final repo = await _open(tester, megaBody());
    expect(repo.stateReads, 1);
    repo.fail = const ApiException('Request timed out. Please try again.', 408);

    await _tap(tester, 'quiz-download');

    expect(repo.stateReads, 2, reason: 'the state was asked for again');
    expect(find.textContaining('the result is unknown'), findsOneWidget);
    expect(find.textContaining('did not work'), findsNothing);
    expect(find.textContaining('timed out. Please try again'), findsNothing);
  });

  testWidgets('a timeout on publish is also unknown, not failed', (
    tester,
  ) async {
    final repo = await _open(tester, _allowed(megaBody()));
    repo.fail = const ApiException('Request timed out. Please try again.', 408);

    await _tap(tester, 'quiz-publish-scoreboard');
    await _tap(tester, 'quiz-confirm');

    expect(repo.stateReads, 2);
    expect(find.textContaining('the result is unknown'), findsOneWidget);
  });

  testWidgets('every action is disabled while one runs', (tester) async {
    final repo = await _open(
      tester,
      _allowed(megaBody()),
      permissions: ['quiz:admin:all', 'quiz:reset:all'],
    );
    repo.pending = Completer<QuizActionResult>();

    await tester.tap(_key('quiz-download'));
    await tester.pump();

    expect(_key('quiz-working'), findsOneWidget);
    for (final name in [
      'quiz-refresh',
      'quiz-download',
      'quiz-generate-daily',
      'quiz-regenerate-daily',
      'quiz-publish-scoreboard',
      'quiz-delete-all',
    ]) {
      expect(_enabled(tester, name), isFalse, reason: name);
    }

    repo.pending!.complete(repo.answer);
    await tester.pumpAndSettle();

    expect(_key('quiz-working'), findsNothing);
    expect(_enabled(tester, 'quiz-download'), isTrue);
    expect(find.text('Done.'), findsOneWidget);
  });

  testWidgets('a state that cannot be read can be retried', (tester) async {
    final repo = _FakeRepository(megaBody());
    var fail = true;
    final failing = _Failing(repo, () => fail);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizAdminRepositoryProvider.overrideWithValue(failing),
          permissionsProvider.overrideWith(
            (ref) => _Permissions(['quiz:admin:all']),
          ),
        ],
        child: const MaterialApp(home: QuizAdminScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You do not have permission to do that.'), findsOneWidget);

    fail = false;
    await _tap(tester, 'quiz-retry');
    expect(_key('quiz-download'), findsOneWidget);
  });

  group('winners reveal', () {
    final mega = {
      'episode': null,
      'winners': [
        {
          'prize': 0,
          'label': 'MEGA',
          'rank': 1,
          'token': 3,
          'name': 'Invented Three',
          'city': 'Nowhere',
          'known': true,
        },
      ],
    };

    testWidgets('a Mega quiz opens each drawn episode and the Mega winners', (
      tester,
    ) async {
      final body = megaBody(offered: true, megaWinners: mega);
      (body['winners'] as Map<String, dynamic>)['mega_student'] = mega;
      await _open(tester, body);

      expect(_key('quiz-reveal-episode-1'), findsOneWidget);
      expect(_key('quiz-reveal-mega'), findsOneWidget);
      expect(_key('quiz-reveal-mega_student'), findsOneWidget);
      expect(_key('quiz-reveal-none'), findsNothing);

      await _tap(tester, 'quiz-reveal-episode-1');
      expect(find.text('Daily winners, episode 1'), findsOneWidget);
      expect(find.text('INVENTED QUIZ'), findsNothing, reason: 'no title set');
      await _tap(tester, 'reveal-close');

      await _tap(tester, 'quiz-reveal-mega');
      expect(find.text('Mega winner'), findsOneWidget);
      await _tap(tester, 'reveal-close');

      await _tap(tester, 'quiz-reveal-mega_student');
      expect(find.text('TSR-student Mega winner'), findsOneWidget);
    });

    testWidgets('a Grand quiz offers only the Grand reveal', (tester) async {
      await _open(tester, _grandBody());

      expect(find.text('Reveal Grand winners, episode 1'), findsOneWidget);
      expect(_key('quiz-reveal-mega'), findsNothing);
      expect(_key('quiz-reveal-mega_student'), findsNothing);
      expect(find.textContaining('Reveal daily winners'), findsNothing);
    });

    testWidgets('with nothing drawn it says so and offers no reveal', (
      tester,
    ) async {
      final body = megaBody();
      (body['winners'] as Map<String, dynamic>)['episodes'] = [];
      await _open(tester, body);

      expect(_key('quiz-reveal-none'), findsOneWidget);
      expect(find.textContaining('Reveal daily winners'), findsNothing);
    });

    testWidgets('winners that change are shown the next time it opens', (
      tester,
    ) async {
      final repo = await _open(tester, megaBody());
      await _tap(tester, 'quiz-reveal-episode-1');
      await _reveal(tester, 1);
      expect(find.text('Invented One'), findsOneWidget);
      await _tap(tester, 'reveal-close');

      final winners =
          ((repo.body['winners'] as Map<String, dynamic>)['episodes'] as List)
                  .first['winners']
              as List;
      (winners.first as Map<String, dynamic>)['name'] = 'Invented Changed';
      await _tap(tester, 'quiz-download');

      await _tap(tester, 'quiz-reveal-episode-1');
      await _reveal(tester, 1);
      expect(find.text('Invented Changed'), findsOneWidget);
      expect(find.text('Invented One'), findsNothing);
    });
  });
}

class _Failing extends _FakeRepository {
  _Failing(_FakeRepository inner, this._failing) : super(inner.body);

  final bool Function() _failing;

  @override
  Future<QuizAdminState> getState() {
    if (_failing()) throw const ApiException('forbidden', 403);
    return super.getState();
  }
}
