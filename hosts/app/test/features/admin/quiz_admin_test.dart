import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/quiz_admin.dart';
import 'package:the_strong_rope/features/admin/repositories/quiz_admin_repository.dart';

// Invented values throughout: no member, token, name or sheet.

Map<String, dynamic> megaBody({
  bool offered = false,
  Object? megaWinners,
  Object? download,
}) => {
  'settings': {
    'loaded': true,
    'kind': 'mega',
    'series': 'Series A',
    'title': 'Title A',
    'mode': 'Live',
    'registration': '1 Jan',
    'stop': '9 Jan',
    'mega_minimum': 3,
    'episodes': [
      {'episode': 1, 'start': '1 Jan', 'stop': '2 Jan'},
      {'episode': 2, 'start': null, 'stop': null},
    ],
    'winner_counts': [1, 2],
    'winner_labels': ['First', 'Second'],
    'colors': {'heading': '#000000'},
  },
  'quiz_day': 2,
  'download': download,
  'eligibility': [
    {
      'episode': 1,
      'submitted': 10,
      'after_dedup': 9,
      'members': 8,
      'country_allowed': 7,
      'not_excluded': 6,
      'passing': 5,
      'needed': 3,
      'status': 'ok',
      'reason': null,
    },
    {
      'episode': 2,
      'submitted': 2,
      'after_dedup': 2,
      'members': 1,
      'country_allowed': 1,
      'not_excluded': 1,
      'passing': 0,
      'needed': 3,
      'status': 'blocked',
      'reason': 'Only 0 people passed; 3 are needed.',
    },
  ],
  'gates': {
    'generate': {'allowed': false, 'reason': 'Episode 2 is blocked.'},
    'mega': {'offered': offered, 'allowed': offered, 'reason': null},
    'mega_student': {'allowed': true, 'reason': null},
  },
  'winners': {
    'episodes': [
      {
        'episode': 1,
        'winners': [
          {
            'prize': 1,
            'label': 'First',
            'rank': 1,
            'token': 1,
            'name': 'Invented One',
            'city': 'Nowhere',
            'known': true,
          },
          {
            'prize': 2,
            'label': 'Second',
            'rank': 1,
            'token': 2,
            'name': '(unknown)',
            'city': '',
            'known': false,
          },
        ],
      },
    ],
    'mega': megaWinners,
    'mega_student': null,
  },
  'activity': {
    'winners_generated': {'at': '2026-10-20T10:00:00+00:00', 'by': 'An Admin'},
    'mega_published': null,
  },
  'can_reset': false,
};

class _Call {
  _Call(this.method, this.path, this.data, this.options);
  final String method;
  final String path;
  final Object? data;
  final Options? options;
}

class _FakeApi implements ApiClient {
  final calls = <_Call>[];
  Object? answer = <String, dynamic>{
    'outcome': 'complete',
    'message': 'ok',
    'changed': true,
  };

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add(_Call('GET', path, null, options));
    return answer as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add(_Call('POST', path, data, options));
    return answer as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('state parsing', () {
    test('a Mega quiz with a blocked episode and no overall Mega yet', () {
      final state = QuizAdminState.fromJson(megaBody());

      expect(state.settings.loaded, isTrue);
      expect(state.settings.kind, QuizKind.mega);
      expect(state.settings.episodes.map((e) => e.episode), [1, 2]);
      expect(state.settings.episodes.last.start, isNull);
      expect(state.settings.winnerCounts, [1, 2]);
      expect(state.settings.winnerLabels, ['First', 'Second']);
      expect(state.settings.megaMinimum, 3);
      expect(state.quizDay, 2);
      expect(state.download, isNull);
      expect(state.eligibility.last.blocked, isTrue);
      expect(state.eligibility.last.reason, contains('3 are needed'));
      expect(state.eligibility.first.reason, isNull);
      expect(state.gates.generate.allowed, isFalse);
      expect(state.gates.generate.reason, 'Episode 2 is blocked.');
      expect(state.gates.mega.offered, isFalse, reason: 'not offered yet');
      expect(state.gates.megaStudent.allowed, isTrue);
      expect(state.canReset, isFalse);
    });

    test(
      'winners parse with who they are; known: false and a null Mega too',
      () {
        final state = QuizAdminState.fromJson(megaBody());

        expect(state.winners.episodes, {1: 2});
        expect(state.winners.megaDrawn, isFalse);
        expect(state.winners.megaStudentDrawn, isFalse);
        expect(state.winners.mega, isEmpty);

        final winners = state.winners.byEpisode[1]!;
        expect(winners.map((w) => w.name), ['Invented One', '(unknown)']);
        expect(winners.map((w) => w.known), [true, false]);
        expect(winners.first.label, 'First');
        expect(winners.first.token, 1);
      },
    );

    test('the quiz colours parse; a missing colour is left out', () {
      final state = QuizAdminState.fromJson(megaBody());

      expect(state.settings.colors, {'heading': '#000000'});
    });

    test('a drawn Mega entry counts as drawn', () {
      final state = QuizAdminState.fromJson(
        megaBody(
          offered: true,
          megaWinners: {
            'episode': null,
            'winners': [
              {
                'prize': 0,
                'label': 'MEGA',
                'rank': 1,
                'token': 3,
                'name': 'Invented Two',
                'city': 'Nowhere',
                'known': true,
              },
            ],
          },
        ),
      );

      expect(state.gates.mega.offered, isTrue);
      expect(state.winners.megaDrawn, isTrue);
    });

    test(
      'the download and the activity stamps parse; a null stamp is dropped',
      () {
        final state = QuizAdminState.fromJson(
          megaBody(
            download: {
              'at': '2026-10-20T09:00:00+00:00',
              'by': 'An Admin',
              'submissions': [
                {'episode': 1, 'submissions': 10},
              ],
            },
          ),
        );

        expect(state.download?.by, 'An Admin');
        expect(state.download?.submissions.single.submissions, 10);
        expect(state.activity.keys, ['winners_generated']);
        expect(state.activity['winners_generated']?.by, 'An Admin');
      },
    );

    test('a Grand quiz reads as Grand', () {
      final body = megaBody();
      (body['settings'] as Map<String, dynamic>)['kind'] = 'grand';
      expect(QuizAdminState.fromJson(body).settings.kind, QuizKind.grand);
    });

    test('missing fields read as empty, and a missing gate is closed', () {
      final state = QuizAdminState.fromJson(<String, dynamic>{});

      expect(state.settings.loaded, isFalse);
      expect(state.settings.episodes, isEmpty);
      expect(state.eligibility, isEmpty);
      expect(state.download, isNull);
      expect(state.winners.episodes, isEmpty);
      expect(state.gates.generate.allowed, isFalse);
      expect(state.gates.mega.offered, isFalse);
      expect(state.canReset, isFalse);
    });

    test('a body that is not an object throws', () {
      expect(() => QuizAdminState.fromJson([]), throwsFormatException);
      expect(() => QuizAdminState.fromJson(null), throwsFormatException);
    });
  });

  group('action results', () {
    test('a draw with a shortfall is not complete', () {
      final result = QuizActionResult.fromJson({
        'outcome': 'incomplete',
        'message': 'Drew 2 of 3.',
        'changed': true,
        'drawn': 2,
        'missing': 1,
        'episodes': [
          {'episode': 1, 'prize': 1, 'drawn': 1, 'missing': 0},
          {'episode': 1, 'prize': 2, 'drawn': 1, 'missing': 1},
          {'episode': null, 'prize': 0, 'drawn': 0, 'missing': 1},
        ],
      });

      expect(result.complete, isFalse);
      expect(result.drawn, 2);
      expect(result.missing, 1);
      expect(result.draws.length, 3);
      expect(result.draws.last.episode, isNull);
    });

    test('a publish that wrote nothing says so and changed is false', () {
      final result = QuizActionResult.fromJson({
        'outcome': 'complete',
        'message': 'Nothing was published: the range is not set.',
        'changed': false,
        'rows': 0,
      });

      expect(result.complete, isTrue);
      expect(result.changed, isFalse);
      expect(result.rows, 0);
      expect(result.drawn, isNull);
    });

    test('an answer without a message throws', () {
      expect(
        () => QuizActionResult.fromJson({'outcome': 'complete'}),
        throwsFormatException,
      );
    });
  });

  group('repository', () {
    late _FakeApi api;
    late QuizAdminRepository repo;

    setUp(() {
      api = _FakeApi();
      repo = QuizAdminRepository(apiClient: api);
    });

    test(
      'download and publish wait 120 s; nothing else changes the timeout',
      () async {
        await repo.download();
        await repo.publish('scoreboard');
        await repo.refreshSettings();
        await repo.generate('daily');
        await repo.regenerate('daily');
        await repo.deleteAll();
        api.answer = megaBody();
        await repo.getState();

        Duration? receiveOf(String path) =>
            api.calls.firstWhere((c) => c.path == path).options?.receiveTimeout;

        expect(
          receiveOf(AppConstants.quizAdminDownloadEndpoint),
          const Duration(seconds: 120),
        );
        expect(
          receiveOf(AppConstants.quizAdminPublishEndpoint),
          const Duration(seconds: 120),
        );
        for (final path in [
          AppConstants.quizAdminRefreshEndpoint,
          AppConstants.quizAdminGenerateEndpoint,
          AppConstants.quizAdminRegenerateEndpoint,
          AppConstants.quizAdminResetEndpoint,
          AppConstants.quizAdminEndpoint,
        ]) {
          expect(
            api.calls.firstWhere((c) => c.path == path).options,
            isNull,
            reason: path,
          );
        }
      },
    );

    test('kinds and targets are sent as the plan names them', () async {
      await repo.generate('mega_student');
      await repo.regenerate('grand');
      await repo.publish('winners');

      expect(api.calls[0].data, {'kind': 'mega_student'});
      expect(api.calls[1].data, {'kind': 'grand'});
      expect(api.calls[2].data, {'what': 'winners'});
    });
  });

  group('error messages', () {
    String message(int status, [String detail = 'server words']) =>
        quizAdminErrorMessage(ApiException(detail, status));

    test('409 and 502 carry the server\'s own sentence', () {
      expect(
        message(
          409,
          'Another quiz admin action is running. Try again in a moment.',
        ),
        'Another quiz admin action is running. Try again in a moment.',
      );
      expect(
        message(
          502,
          'Episode 3 could not be read from the sheet. Nothing was changed.',
        ),
        contains('Nothing was changed'),
      );
    });

    test('a 502 with no detail still says nothing was published', () {
      expect(message(502, ''), contains('Nothing was changed or published'));
    });

    test('403, 404 and 422 are worded for the screen', () {
      expect(message(403), contains('permission'));
      expect(message(404), contains('not part of this quiz'));
      expect(message(422), contains('Nothing was changed'));
    });

    test('anything else is a generic retry, and a timeout is not an error', () {
      expect(message(500), 'That did not work. Please try again.');
      expect(
        quizAdminErrorMessage(StateError('x')),
        'That did not work. Please try again.',
      );
      expect(quizAdminTimedOut(const ApiException('t', 408)), isTrue);
      expect(quizAdminTimedOut(const ApiException('t', 502)), isFalse);
      expect(quizAdminTimedOut(StateError('x')), isFalse);
    });
  });
}
