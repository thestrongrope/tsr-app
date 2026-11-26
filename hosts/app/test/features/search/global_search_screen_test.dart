import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/search/models/search_result.dart';
import 'package:the_strong_rope/features/search/providers/search_provider.dart';
import 'package:the_strong_rope/features/search/repositories/search_repository.dart';
import 'package:the_strong_rope/features/search/screens/global_search_screen.dart';

// The global search screen (#557): one field, results grouped by kind with
// counts, honest about what could not be searched.

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

SearchGroup _group(
  SearchKind kind,
  List<String> titles, {
  int? count,
  bool capped = false,
}) => SearchGroup(
  kind: kind,
  count: count ?? titles.length,
  capped: capped,
  results: [
    for (var i = 0; i < titles.length; i++)
      SearchResult(
        kind: kind,
        id: i + 1,
        title: titles[i],
        subtitle: 'sub ${titles[i]}',
        target: kind == SearchKind.video
            ? 'https://www.youtube.com/watch?v=${i + 1}'
            : '/${kind.name}/${i + 1}',
      ),
  ],
);

class _Repo extends SearchRepository {
  _Repo({
    this.articlesResult,
    this.videosResult,
    this.publicationsResult,
    this.privateResult,
    this.failAll = false,
    this.failVideos = false,
  });

  final SearchGroup? articlesResult;
  final SearchGroup? videosResult;
  final SearchGroup? publicationsResult;
  final PrivateSearch? privateResult;
  final bool failAll;
  final bool failVideos;
  final asked = <String>[];
  var allowRecovery = false;

  bool get _down => failAll && !allowRecovery;

  @override
  Future<SearchGroup> articles(String query) async {
    asked.add('articles:$query');
    if (_down) throw Exception('down');
    return articlesResult ?? _group(SearchKind.article, []);
  }

  @override
  Future<SearchGroup> videos(String query) async {
    asked.add('videos:$query');
    if (_down || failVideos) throw Exception('down');
    return videosResult ?? _group(SearchKind.video, []);
  }

  @override
  Future<SearchGroup> publications(String query) async {
    asked.add('publications:$query');
    if (_down) throw Exception('down');
    return publicationsResult ?? _group(SearchKind.publication, []);
  }

  @override
  Future<PrivateSearch> privateSearch(String query) async {
    asked.add('private:$query');
    if (_down) throw Exception('down');
    return privateResult ?? const PrivateSearch(groups: {}, unavailable: {});
  }
}

Widget _wrap(
  _Repo repo, {
  List<SearchResult>? opened,
  List<String> permissions = const [],
  bool signedIn = true,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: <Override>[
      searchRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(
        signedIn
            ? const User(
                id: 5,
                token: 9,
                email: 'a@example.test',
                name: 'A',
                roleId: 0,
              )
            : null,
      ),
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      searchOpenProvider.overrideWithValue(
        (context, result) async => opened?.add(result),
      ),
    ],
    child: const MaterialApp(home: GlobalSearchScreen()),
  );
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('before a query it says what to do and asks nothing', (
    tester,
  ) async {
    final repo = _Repo();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Type at least two letters to search'), findsOneWidget);
    expect(repo.asked, isEmpty);
  });

  testWidgets('results are grouped by kind with a count each', (tester) async {
    final repo = _Repo(
      articlesResult: _group(SearchKind.article, [
        'Tauheed article',
      ], count: 12),
      videosResult: _group(SearchKind.video, [
        'Tauheed lecture',
        'Another lecture',
      ]),
      publicationsResult: _group(SearchKind.publication, ['A book on Tauheed']),
      privateResult: PrivateSearch(
        groups: {
          SearchKind.classRecord: _group(SearchKind.classRecord, ['AYD1']),
        },
        unavailable: const {},
      ),
    );
    await tester.pumpWidget(_wrap(repo));
    await _type(tester, 'tau');

    expect(find.text('Articles (12)'), findsOneWidget);
    expect(find.text('Videos (2)'), findsOneWidget);
    expect(find.text('Classes (1)'), findsOneWidget);
    expect(find.text('Tauheed article'), findsOneWidget);
    expect(find.text('AYD1'), findsOneWidget);
    expect(find.text('Publications (1)'), findsOneWidget);
    expect(
      find.text('Guides (0)'),
      findsNothing,
      reason: 'a kind with no results is not a group',
    );
  });

  testWidgets('a capped group says there may be more', (tester) async {
    final repo = _Repo(
      privateResult: PrivateSearch(
        groups: {
          SearchKind.student: _group(
            SearchKind.student,
            ['S1'],
            count: 50,
            capped: true,
          ),
        },
        unavailable: const {},
      ),
    );
    await tester.pumpWidget(_wrap(repo));
    await _type(tester, 'stu');

    expect(find.text('Students (50+)'), findsOneWidget);
  });

  testWidgets('it says it is searching while an answer is pending', (
    tester,
  ) async {
    final repo = _SlowRepo();
    await tester.pumpWidget(_wrap(repo));
    await tester.enterText(find.byType(TextField), 'tau');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Searching…'), findsOneWidget);
    repo.release();
    await tester.pumpAndSettle();
    expect(find.text('Searching…'), findsNothing);
  });

  testWidgets('when nothing matches anywhere it says so once', (tester) async {
    await tester.pumpWidget(_wrap(_Repo()));
    await _type(tester, 'zzz');

    expect(find.text('Nothing found'), findsOneWidget);
  });

  testWidgets(
    'a kind that could not be searched is named and the rest still show',
    (tester) async {
      final repo = _Repo(
        articlesResult: _group(SearchKind.article, ['Tauheed article']),
        failVideos: true,
      );
      await tester.pumpWidget(_wrap(repo));
      await _type(tester, 'tau');

      expect(find.text('Tauheed article'), findsOneWidget);
      expect(
        find.text(
          'Videos could not be searched, so these results may be incomplete.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nothing found'), findsNothing);
    },
  );

  testWidgets(
    'the server naming kinds it could not search is shown the same way',
    (tester) async {
      final repo = _Repo(
        privateResult: PrivateSearch(
          groups: {
            SearchKind.classRecord: _group(SearchKind.classRecord, ['AYD1']),
          },
          unavailable: const {SearchKind.teacher, SearchKind.student},
        ),
      );
      await tester.pumpWidget(_wrap(repo));
      await _type(tester, 'ayd');

      expect(
        find.text(
          'Students and Teachers could not be searched, so these results may be incomplete.',
        ),
        findsOneWidget,
      );
      expect(find.text('AYD1'), findsOneWidget);
    },
  );

  testWidgets('when the whole search fails it offers to try again', (
    tester,
  ) async {
    final repo = _Repo(failAll: true);
    await tester.pumpWidget(_wrap(repo));
    await _type(tester, 'tau');

    expect(find.text('The search could not be done.'), findsOneWidget);
    repo.allowRecovery = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('The search could not be done.'), findsNothing);
    expect(find.text('Nothing found'), findsOneWidget);
  });

  testWidgets('tapping a result opens it', (tester) async {
    final opened = <SearchResult>[];
    final repo = _Repo(
      videosResult: _group(SearchKind.video, ['Tauheed lecture']),
      privateResult: PrivateSearch(
        groups: {
          SearchKind.student: _group(SearchKind.student, ['Student One']),
        },
        unavailable: const {},
      ),
    );
    await tester.pumpWidget(_wrap(repo, opened: opened));
    await _type(tester, 'tau');

    await tester.tap(find.text('Student One'));
    await tester.tap(find.text('Tauheed lecture'));
    await tester.pump();

    expect(opened.map((r) => r.kind), [SearchKind.student, SearchKind.video]);
    expect(opened.last.target, 'https://www.youtube.com/watch?v=1');
  });

  testWidgets('typing fast asks only for the last query', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_wrap(repo));

    await tester.enterText(find.byType(TextField), 'ay');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'ayd');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repo.asked.where((a) => a.endsWith(':ay')), isEmpty);
    expect(repo.asked.where((a) => a.endsWith(':ayd')), isNotEmpty);
  });

  testWidgets('a long group shows five and a button for the rest', (
    tester,
  ) async {
    final repo = _Repo(
      articlesResult: _group(SearchKind.article, [
        for (var i = 1; i <= 7; i++) 'Article $i',
      ]),
    );
    await tester.pumpWidget(_wrap(repo));
    await _type(tester, 'art');

    expect(find.text('Article 5'), findsOneWidget);
    expect(find.text('Article 6'), findsNothing);
    await tester.tap(find.text('Show all 7'));
    await tester.pumpAndSettle();
    expect(find.text('Article 7'), findsOneWidget);
  });

  testWidgets('screens and reports the person may open are listed first', (
    tester,
  ) async {
    final repo = _Repo(
      articlesResult: _group(SearchKind.article, ['A registration guide']),
    );
    await tester.pumpWidget(
      _wrap(repo, permissions: const ['registrations:read:gender']),
    );
    await _type(tester, 'regis');

    expect(find.text('Screens and reports (1)'), findsOneWidget);
    expect(find.text('Registrations'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Screens and reports (1)')).dy,
      lessThan(tester.getTopLeft(find.text('Articles (1)')).dy),
    );
  });
}

/// A repository whose answers wait until [release] is called.
class _SlowRepo extends _Repo {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<SearchGroup> articles(String query) async {
    await _gate.future;
    return _group(SearchKind.article, []);
  }
}
