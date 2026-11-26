import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/theme/app_theme.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/grand_quiz/providers/grand_quiz_provider.dart';
import 'package:the_strong_rope/features/home/models/recent_action.dart';
import 'package:the_strong_rope/features/home/presentation/home_screen.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';
import 'package:the_strong_rope/features/home/services/recent_actions_store.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/reports/models/this_week.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

import '../../support/content_width.dart';

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth()
    : super(
        const AuthState(
          status: AuthStatus.authenticated,
          user: User(
            id: 1,
            token: 7,
            email: 'a@example.com',
            name: 'Test Member',
            roleId: 1,
          ),
        ),
      );

  @override
  Future<void> refreshUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(
    List<String> permissions,
    PermissionScopes scopes, {
    this.refreshFails = false,
  }) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: scopes,
        issuedAt: '',
      ),
    );
  }

  final bool refreshFails;

  @override
  Future<void> fetchAndSave() async {
    if (refreshFails) {
      state = state.copyWith(stale: true, error: 'offline');
    }
  }
}

class _FixedClasses extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClasses(super.state);

  var refreshed = 0;

  @override
  Future<void> loadClasses({bool allowSaved = true}) async {}

  @override
  Future<void> refresh() async => refreshed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedQuiz extends StateNotifier<GrandQuizState>
    implements GrandQuizNotifier {
  _FixedQuiz() : super(const GrandQuizState());

  @override
  Future<void> loadQuizInfo({bool forceRefresh = false}) async {}

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedNotifications extends UserNotificationsNotifier {
  @override
  UserNotificationsState build() => const UserNotificationsState();

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}
}

class _FixedRecent extends RecentActionsNotifier {
  _FixedRecent(List<RecentAction> events) : super(RecentActionsStore(), null) {
    state = events;
  }
}

ClassModel _class(int id, String name, {String? role}) => ClassModel(
  id: id,
  code: 'C$id',
  name: name,
  level: 1,
  gender: 1,
  status: 'active',
  role: role,
);

ThisWeek _week(int flagged) => ThisWeek(
  gender: 1,
  weekFrom: '2026-10-11',
  weekTo: '2026-10-17',
  summary: ThisWeekSummary(
    met: 3,
    total: 4,
    formsMissing: 0,
    attendance: 0.6,
    flagged: flagged,
  ),
  cform: const [],
  conduction: const [],
  attendance: const [],
  alignment: const [],
);

const _article = TsrArticle(slug: 'a', title: 'An article');
const _video = TsrYouTubeVideo(
  id: '1',
  videoId: 'v1',
  title: 'A video',
  youtubeLink: 'https://example.com/v1',
);

const _articleArgs = (limit: 5, offset: 0, category: null, search: null);
const _videoArgs = (limit: 5, offset: 0);

Widget _home({
  List<ClassModel> classes = const [],
  ClassesState? classesState,
  List<String> permissions = const [],
  PermissionScopes scopes = const PermissionScopes(),
  int? flagged,
  Future<TsrArticlesResponse> Function()? articles,
  Future<TsrYouTubeResponse> Function()? videos,
  _FixedClasses? classesNotifier,
  bool permissionsRefreshFails = false,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith((ref) => _FixedAuth()),
      grandQuizProvider.overrideWith((ref) => _FixedQuiz()),
      userNotificationsProvider.overrideWith(_FixedNotifications.new),
      recentActionsProvider.overrideWith(
        (ref) => _FixedRecent([
          RecentAction(
            kind: RecentActionKind.thisWeek,
            classId: null,
            at: DateTime.now(),
          ),
        ]),
      ),
      classesProvider.overrideWith(
        (ref) =>
            classesNotifier ??
            _FixedClasses(classesState ?? ClassesState(classes: classes)),
      ),
      permissionsProvider.overrideWith(
        (ref) => _FixedPermissions(
          permissions,
          scopes,
          refreshFails: permissionsRefreshFails,
        ),
      ),
      thisWeekProvider.overrideWith((ref, _) async => _week(flagged ?? 0)),
      tsrArticlesProvider(_articleArgs).overrideWith(
        (ref) =>
            articles?.call() ??
            Future.value(const TsrArticlesResponse(articles: [_article])),
      ),
      tsrYouTubeProvider(_videoArgs).overrideWith(
        (ref) =>
            videos?.call() ??
            Future.value(const TsrYouTubeResponse(videos: [_video])),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: HomeScreen()),
          ),
          for (final path in ['/articles', '/videos', '/classes'])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text('screen $path')),
            ),
        ],
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(home);
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

/// The pull itself is Flutter's; this runs what the pull runs.
Future<void> _pullToRefresh(WidgetTester tester) async {
  final indicator = tester.state<RefreshIndicatorState>(
    find.byType(RefreshIndicator),
  );
  unawaited(indicator.show());
  await tester.pumpAndSettle();
}

void main() {
  const teacher = ['sessions:create:taught', 'notifications:send:taught'];
  const reports = 'reports:read:gender';

  testWidgets('pull to refresh says so when the permissions check works', (
    tester,
  ) async {
    await _pump(tester, _home());
    await _pullToRefresh(tester);

    expect(find.text('Home data refreshed'), findsOneWidget);
  });

  testWidgets('pull to refresh reports a failed permissions check', (
    tester,
  ) async {
    await _pump(tester, _home(permissionsRefreshFails: true));
    await _pullToRefresh(tester);

    expect(find.text('Home data refreshed'), findsNothing);
    expect(find.textContaining('Could not check'), findsOneWidget);
    expect(find.text('What you can see may be out of date.'), findsOneWidget);
  });

  for (final size in [tabletLandscape, tabletPortrait]) {
    testWidgets('on a $size tablet the content is capped and centred', (
      tester,
    ) async {
      await _pump(
        tester,
        _home(classes: [_class(1, 'Alpha', role: 'attending')]),
      );
      setWindow(tester, size);
      await tester.pumpAndSettle();

      expectContentCapped(tester);
    });
  }

  testWidgets('sections appear in the order header to videos', (tester) async {
    await _pump(
      tester,
      _home(
        classes: [_class(1, 'Alpha', role: 'attending')],
        permissions: const [reports],
        scopes: const PermissionScopes(gender: 1, enrolled: [1]),
        flagged: 2,
      ),
    );

    final order = [
      find.text('Test Member'),
      find.text('Connect with the teachings of Ahlul Bayt (a.s.)'),
      find.textContaining('This week: 2 classes'),
      find.text('Jump back in'),
      find.text('My Classes'),
      find.text('Latest Articles'),
      find.text('Latest Videos'),
    ];
    for (final finder in order) {
      expect(finder, findsOneWidget);
    }
    final tops = [for (final f in order) _top(tester, f)];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('a teacher sees the teaching shortcuts and a student does not', (
    tester,
  ) async {
    await _pump(
      tester,
      _home(
        classes: [_class(1, 'Alpha', role: 'conducting')],
        permissions: teacher,
        scopes: const PermissionScopes(taught: [1]),
      ),
    );
    expect(find.text('Record conduction'), findsOneWidget);
    expect(find.text('Class announcement'), findsOneWidget);

    await _pump(
      tester,
      _home(
        classes: [_class(1, 'Alpha', role: 'attending')],
        scopes: const PermissionScopes(enrolled: [1]),
      ),
    );
    expect(find.text('Record conduction'), findsNothing);
    expect(find.text('Class announcement'), findsNothing);
  });

  testWidgets('empty sections say so and every link reaches its screen', (
    tester,
  ) async {
    const enrolled = PermissionScopes(enrolled: [1]);
    for (final link in [
      ('See classes', '/classes'),
      ('Browse articles', '/articles'),
      ('Browse videos', '/videos'),
    ]) {
      await _pump(
        tester,
        _home(
          scopes: enrolled,
          articles: () async => const TsrArticlesResponse(articles: []),
          videos: () async => const TsrYouTubeResponse(videos: []),
        ),
      );
      expect(find.text('No Classes Yet'), findsOneWidget);
      expect(find.text('No articles yet'), findsOneWidget);
      expect(find.text('No videos yet'), findsOneWidget);

      await tester.ensureVisible(find.text(link.$1));
      await tester.tap(find.text(link.$1));
      await tester.pumpAndSettle();
      expect(find.text('screen ${link.$2}'), findsOneWidget);
    }
  });

  testWidgets('a member who is not enrolled sees no My Classes section', (
    tester,
  ) async {
    await _pump(tester, _home());
    expect(find.text('My Classes'), findsNothing);
    expect(find.text('No Classes Yet'), findsNothing);
  });

  testWidgets('one failing section shows Retry and leaves the others', (
    tester,
  ) async {
    await _pump(
      tester,
      _home(
        classes: [_class(1, 'Alpha', role: 'attending')],
        articles: () async => throw Exception('boom'),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Latest Articles'), findsOneWidget);
    expect(find.text('A video'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
  });

  testWidgets('a failed My Classes shows Retry and the content below stays', (
    tester,
  ) async {
    final classes = _FixedClasses(const ClassesState(error: 'No connection'));
    await _pump(
      tester,
      _home(
        classesNotifier: classes,
        scopes: const PermissionScopes(enrolled: [1]),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('A video'), findsOneWidget);
    expect(find.text('An article'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(classes.refreshed, 1);
  });

  testWidgets('classes needing attention show the banner with a count', (
    tester,
  ) async {
    await _pump(
      tester,
      _home(
        permissions: const [reports],
        scopes: const PermissionScopes(gender: 1),
        flagged: 3,
      ),
    );
    expect(find.text('This week: 3 classes need attention'), findsOneWidget);
    expect(find.byIcon(Icons.notification_important_rounded), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsNothing);
  });

  test('the attention colour is at least 3:1 on the banner fill', () {
    final fill = Color.alphaBlend(
      AppTheme.warningStrong.withValues(alpha: 0.12),
      Colors.white,
    );
    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(ratio(AppTheme.warningStrong, fill), greaterThanOrEqualTo(3));
  });

  testWidgets('all clear shows no attention banner', (tester) async {
    await _pump(
      tester,
      _home(
        permissions: const [reports],
        scopes: const PermissionScopes(gender: 1),
        flagged: 0,
      ),
    );
    expect(find.text('This week: all clear'), findsOneWidget);
    expect(find.byIcon(Icons.notification_important_rounded), findsNothing);
  });
}
