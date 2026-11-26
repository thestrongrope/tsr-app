import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/search/models/search_result.dart';
import 'package:the_strong_rope/features/search/providers/search_provider.dart';
import 'package:the_strong_rope/features/search/repositories/search_repository.dart';

// The fan-out behind global search (#557): every kind asked once, in
// parallel, each answering or failing alone.

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(gender: 1),
        issuedAt: '',
      ),
    );
  }
}

SearchGroup _group(SearchKind kind, String title, {int id = 1}) => SearchGroup(
  kind: kind,
  count: 1,
  results: [
    SearchResult(
      kind: kind,
      id: id,
      title: title,
      subtitle: '',
      target: '/x/$id',
    ),
  ],
);

class _FakeRepo extends SearchRepository {
  _FakeRepo({this.failing = const {}, this.private, this.privateFails = false});

  final Set<String> failing;
  final PrivateSearch? private;
  final bool privateFails;
  final calls = <String, int>{};
  Completer<SearchGroup>? articlesGate;

  void _count(String name) => calls[name] = (calls[name] ?? 0) + 1;

  @override
  Future<SearchGroup> articles(String query) async {
    _count('articles');
    if (articlesGate != null) return articlesGate!.future;
    if (failing.contains('articles')) throw Exception('articles down');
    return _group(SearchKind.article, 'An article');
  }

  @override
  Future<SearchGroup> videos(String query) async {
    _count('videos');
    if (failing.contains('videos')) throw Exception('videos down');
    return _group(SearchKind.video, 'A lecture');
  }

  @override
  Future<SearchGroup> publications(String query) async {
    _count('publications');
    if (failing.contains('publications')) throw Exception('pubs down');
    return _group(SearchKind.publication, 'A book');
  }

  @override
  Future<PrivateSearch> privateSearch(String query) async {
    _count('private');
    if (privateFails) throw Exception('private down');
    return private ??
        PrivateSearch(
          groups: {
            SearchKind.classRecord: _group(SearchKind.classRecord, 'AYD1'),
          },
          unavailable: const {},
        );
  }
}

User _user(int token) =>
    User(id: 5, token: token, email: 'a@example.test', name: 'A', roleId: 0);

ProviderContainer _container(
  _FakeRepo repo, {
  User? user,
  List<String> permissions = const ['reports:read:gender'],
}) => ProviderContainer(
  overrides: [
    searchRepositoryProvider.overrideWithValue(repo),
    currentUserProvider.overrideWithValue(user),
    permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
  ],
);

/// Lets every lookup for [query] finish, answered or failed.
Future<GlobalSearchView> _settle(ProviderContainer c, String query) async {
  final sub = c.listen(globalSearchProvider(query), (_, _) {});
  await Future<void>.delayed(const Duration(milliseconds: 20));
  final view = c.read(globalSearchProvider(query));
  sub.close();
  return view;
}

void main() {
  group('PrivateSearch.fromJson', () {
    test('groups the answer by kind and points each result at its card', () {
      final private = PrivateSearch.fromJson({
        'groups': [
          {
            'kind': 'class',
            'count': 1,
            'capped': false,
            'results': [
              {'id': 7, 'title': 'AYD1', 'subtitle': 'AMMAR'},
            ],
          },
          {
            'kind': 'student',
            'count': 1,
            'capped': true,
            'results': [
              {'id': 101, 'title': 'Student One', 'subtitle': 'AYD1'},
            ],
          },
          {
            'kind': 'teacher',
            'count': 1,
            'capped': false,
            'results': [
              {'id': 100, 'title': 'Teacher One', 'subtitle': 'Teacher'},
            ],
          },
          {
            'kind': 'guide',
            'count': 1,
            'capped': false,
            'results': [
              {'id': 12, 'title': 'AMMAR guide', 'subtitle': ''},
            ],
          },
          {
            'kind': 'subscriber',
            'count': 1,
            'capped': false,
            'results': [
              {'id': 103, 'title': 'Sub Scriber', 'subtitle': ''},
            ],
          },
        ],
        'unavailable': ['teacher'],
      });

      expect(
        private.groups[SearchKind.classRecord]!.results.single.target,
        '/classes/7/dashboard',
      );
      expect(
        private.groups[SearchKind.student]!.results.single.target,
        AppRoutes.studentCardPath(101),
      );
      expect(private.groups[SearchKind.student]!.capped, isTrue);
      expect(
        private.groups[SearchKind.guide]!.results.single.target,
        '/classes/12/guide',
      );
      expect(
        private.groups[SearchKind.subscriber]!.results.single.target,
        AppRoutes.subscriberCardPath(103),
      );
      expect(
        private.groups[SearchKind.teacher]!.results.single.target,
        AppRoutes.adminTeacherPath(100),
      );
      expect(private.unavailable, {SearchKind.teacher});
    });

    test('a body that is not a search answer throws', () {
      expect(() => PrivateSearch.fromJson('nope'), throwsFormatException);
      expect(
        () => PrivateSearch.fromJson({'unavailable': <dynamic>[]}),
        throwsFormatException,
      );
    });
  });

  test('every kind is asked once, public and private', () async {
    final repo = _FakeRepo();
    final c = _container(repo, user: _user(9));

    final view = await _settle(c, 'ayd');

    expect(repo.calls, {
      'articles': 1,
      'videos': 1,
      'publications': 1,
      'private': 1,
    });
    expect(
      view.groups.keys,
      containsAll([
        SearchKind.article,
        SearchKind.video,
        SearchKind.publication,
        SearchKind.classRecord,
      ]),
    );
    expect(view.complete, isTrue);
    expect(view.searching, isFalse);
  });

  test(
    'one failure does not hide the others and the result is not complete',
    () async {
      final repo = _FakeRepo(failing: {'articles'});
      final c = _container(repo, user: _user(9));

      final view = await _settle(c, 'ayd');

      expect(view.failed, {SearchKind.article});
      expect(
        view.groups.keys,
        containsAll([
          SearchKind.video,
          SearchKind.publication,
          SearchKind.classRecord,
        ]),
      );
      expect(view.complete, isFalse);
    },
  );

  test('signed out asks the public kinds and the destinations only', () async {
    final repo = _FakeRepo();
    final c = _container(repo, user: null, permissions: const []);

    final view = await _settle(c, 'ayd');

    expect(repo.calls.containsKey('private'), isFalse);
    expect(view.groups.containsKey(SearchKind.classRecord), isFalse);
    expect(
      view.groups.keys,
      containsAll([
        SearchKind.article,
        SearchKind.video,
        SearchKind.publication,
      ]),
    );
  });

  test('a member with token 0 asks the public kinds only', () async {
    final repo = _FakeRepo();
    final c = _container(repo, user: _user(0));

    await _settle(c, 'ayd');

    expect(repo.calls.containsKey('private'), isFalse);
  });

  test(
    'kinds the server could not search are marked failed, the rest shown',
    () async {
      final repo = _FakeRepo(
        private: PrivateSearch(
          groups: {
            SearchKind.classRecord: _group(SearchKind.classRecord, 'AYD1'),
          },
          unavailable: const {SearchKind.teacher, SearchKind.student},
        ),
      );
      final c = _container(repo, user: _user(9));

      final view = await _settle(c, 'ayd');

      expect(view.failed, {SearchKind.teacher, SearchKind.student});
      expect(view.groups.containsKey(SearchKind.classRecord), isTrue);
      expect(view.complete, isFalse);
    },
  );

  test(
    'the whole private call failing marks every private kind failed',
    () async {
      final repo = _FakeRepo(privateFails: true);
      final c = _container(repo, user: _user(9));

      final view = await _settle(c, 'ayd');

      expect(view.failed, {
        SearchKind.classRecord,
        SearchKind.teacher,
        SearchKind.guide,
        SearchKind.student,
        SearchKind.subscriber,
      });
      expect(view.groups.containsKey(SearchKind.article), isTrue);
    },
  );

  test('fewer than two characters asks nothing', () async {
    final repo = _FakeRepo();
    final c = _container(repo, user: _user(9));

    final view = await _settle(c, 'a');

    expect(repo.calls, isEmpty);
    expect(view.groups, isEmpty);
    expect(view.searching, isFalse);
  });

  test('it is searching while an answer is pending', () async {
    final repo = _FakeRepo()..articlesGate = Completer<SearchGroup>();
    final c = _container(repo, user: _user(9));

    final view = await _settle(c, 'ayd');

    expect(view.searching, isTrue);
    expect(view.nothingFound, isFalse);
  });

  test(
    'destinations are matched by permission without a server call',
    () async {
      final repo = _FakeRepo();
      final c = _container(
        repo,
        user: _user(9),
        permissions: const ['registrations:read:gender'],
      );

      final view = await _settle(c, 'regis');

      expect(
        view.groups[SearchKind.destination]!.results.single.title,
        'Registrations',
      );
    },
  );

  test('nothing found says so only when every answer is in and empty', () async {
    final repo = _FakeRepo(
      private: PrivateSearch(groups: const {}, unavailable: const {}),
    );
    final c = _container(repo, user: _user(9), permissions: const []);
    // The public kinds find something in the fake, so this checks the empty rule directly.
    const empty = GlobalSearchView(groups: {}, failed: {}, searching: false);

    expect(empty.nothingFound, isTrue);
    expect(
      const GlobalSearchView(
        groups: {},
        failed: {SearchKind.video},
        searching: false,
      ).nothingFound,
      isFalse,
    );
    expect(
      const GlobalSearchView(
        groups: {},
        failed: {SearchKind.video},
        searching: false,
      ).allFailed,
      isTrue,
    );
    c.dispose();
  });
}
