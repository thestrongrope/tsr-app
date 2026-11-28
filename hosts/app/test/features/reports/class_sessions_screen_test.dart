import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/class_sessions_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/class_sessions_screen.dart';

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

ClassSessionsClass _class(int id, String name, String level) =>
    ClassSessionsClass(
      classId: id,
      className: name,
      level: level,
      teacher: 'Teacher $name',
      totalSessions: 3,
      lastDate: '2026-09-09',
      lastQuran: 'Maryam:5',
      lastTopics: const {'Arabic': 'Alphabet'},
    );

ClassSessionsReport _report({List<ClassSessionsClass>? classes}) =>
    ClassSessionsReport(
      gender: 1,
      levels: const ['AMMAR', 'BILAL'],
      classes: classes ?? [_class(7, 'A1', 'AMMAR'), _class(8, 'B1', 'BILAL')],
    );

const _held = ClassSession(
  date: '2026-09-09',
  held: true,
  reason: null,
  quran: 'Maryam:5',
  topics: {'Arabic': 'Alphabet', 'Ahkam': 'Wudu'},
);
const _notHeld = ClassSession(
  date: '2026-09-02',
  held: false,
  reason: 'Eid',
  quran: '',
  topics: {},
);

Widget _wrap(
  Future<ClassSessionsReport> Function(int?) load, {
  List<String> permissions = const ['reports:read:gender'],
  ShareClassSessionsAll? shareAll,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      classSessionsReportProvider.overrideWith((ref, gender) => load(gender)),
      if (shareAll != null)
        shareClassSessionsAllProvider.overrideWithValue(shareAll),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ClassSessionsScreen()),
          GoRoute(
            path: '/admin/reports/class-sessions/:classId',
            builder: (_, state) => Text(
              'history ${state.pathParameters['classId']} ${state.extra}',
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _wrapHistory(
  Future<List<ClassSession>> Function(int) load, {
  ShareClassSessions? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      classSessionHistoryProvider.overrideWith((ref, id) => load(id)),
      if (share != null) shareClassSessionsProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(
      home: ClassSessionHistoryScreen(classId: 7, title: 'A1 · AMMAR'),
    ),
  );
}

void main() {
  testWidgets('lists each class with its count, last date and last topics', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('3 sessions · last 9 Sep 2026'), findsNWidgets(2));
    expect(find.text('Quran: Maryam:5'), findsNWidgets(2));
    expect(find.text('Arabic: Alphabet'), findsNWidgets(2));
    expect(find.textContaining('Aqaed'), findsNothing);
  });

  testWidgets('a level chip narrows the classes without a new request', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      _wrap((_) async {
        requests++;
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();

    expect(find.text('B1 · BILAL'), findsOneWidget);
    expect(find.text('A1 · AMMAR'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('searching narrows the classes by code or teacher', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'teacher b1');
    await tester.pumpAndSettle();
    expect(find.text('B1 · BILAL'), findsOneWidget);
    expect(find.text('A1 · AMMAR'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search.'), findsOneWidget);
  });

  testWidgets('opening a class goes to its history with the class named', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B1 · BILAL'));
    await tester.pumpAndSettle();

    expect(find.text('history 8 B1 · BILAL'), findsOneWidget);
  });

  testWidgets('a failure offers Try again, which asks again', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      _wrap((_) async {
        requests++;
        if (requests == 1) throw Exception('offline');
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('The report could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets('only someone who reaches every class chooses the gender', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsNothing);

    await tester.pumpWidget(
      _wrap((_) async => _report(), permissions: ['reports:read:all']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsOneWidget);
  });

  Future<void> chooseShareAll(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share all (CSV)'));
    await tester.pumpAndSettle();
  }

  testWidgets('Share all sends the gender on screen, not the level', (
    tester,
  ) async {
    final shared = <int>[];
    await tester.pumpWidget(
      _wrap(
        (gender) async => ClassSessionsReport(
          gender: gender ?? 1,
          levels: const ['AMMAR', 'BILAL'],
          classes: [_class(7, 'A1', 'AMMAR'), _class(8, 'B1', 'BILAL')],
        ),
        permissions: ['reports:read:all'],
        shareAll: (gender) async => shared.add(gender),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ladies'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();

    await chooseShareAll(tester);

    expect(shared, [2]);
  });

  testWidgets('Share all is hidden without reports:read', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(), permissions: []));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('Share all with no sessions says so', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll: (gender) async => throw const ApiException('None', 404),
      ),
    );
    await tester.pumpAndSettle();

    await chooseShareAll(tester);

    expect(find.text('There are no sessions to share yet.'), findsOneWidget);
  });

  testWidgets('Share all failing shows the error', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll: (gender) async => throw Exception('offline'),
      ),
    );
    await tester.pumpAndSettle();

    await chooseShareAll(tester);

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('history lists each session and marks one not held', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapHistory((_) async => [_held, _notHeld]));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('9 Sep 2026'), findsOneWidget);
    expect(find.text('Quran: Maryam:5'), findsOneWidget);
    expect(find.text('Ahkam: Wudu'), findsOneWidget);
    expect(find.text('2 Sep 2026'), findsOneWidget);
    expect(find.text('Not held: Eid'), findsOneWidget);
  });

  testWidgets('a class with no sessions says so and offers no Share', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapHistory((_) async => []));
    await tester.pumpAndSettle();

    expect(
      find.text('No sessions have been recorded for this class.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('a history failure offers Try again', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      _wrapHistory((_) async {
        requests++;
        if (requests == 1) throw Exception('offline');
        return [_held];
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('The sessions could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('9 Sep 2026'), findsOneWidget);
  });

  testWidgets('Share as PDF sends the class and format', (tester) async {
    final shared = <(int, ReportFormat)>[];
    await tester.pumpWidget(
      _wrapHistory(
        (_) async => [_held],
        share: (id, format) async => shared.add((id, format)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();

    expect(shared, [(7, ReportFormat.pdf)]);
  });

  testWidgets('a failed download says so and leaves the history as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapHistory(
        (_) async => [_held],
        share: (id, format) async => throw Exception('offline'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('9 Sep 2026'), findsOneWidget);
  });

  testWidgets('there is nothing to share while the history is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapHistory((_) => Completer<List<ClassSession>>().future),
    );
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });
}
