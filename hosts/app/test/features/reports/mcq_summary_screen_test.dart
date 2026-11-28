import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/mcq_summary_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/mcq_summary_screen.dart';

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

McqSummaryClass _class(int id, String name, String level) => McqSummaryClass(
  classId: id,
  className: name,
  level: level,
  teacher: 'Teacher $name',
  mcqs: 4,
  students: 12,
);

McqSummaryReport _report({List<McqSummaryClass>? classes}) => McqSummaryReport(
  gender: 1,
  from: '2026-09-01',
  to: '2026-09-30',
  levels: const ['AMMAR', 'BILAL'],
  classes: classes ?? [_class(7, 'A1', 'AMMAR'), _class(8, 'B1', 'BILAL')],
);

const _detail = McqSummaryDetail(
  mcqs: 4,
  maxMarks: 20,
  students: [
    McqStudent(
      name: 'Ali',
      attempted: 3,
      pending: 1,
      correct: 15,
      percent: 75,
      topics: [McqTopicScore(topic: 'Wudu', max: 12, correct: 9)],
    ),
    McqStudent(
      name: 'Zayd',
      attempted: 0,
      pending: 4,
      correct: 0,
      percent: null,
      topics: [McqTopicScore(topic: 'Wudu', max: 12, correct: null)],
    ),
  ],
);

Widget _wrap(
  Future<McqSummaryReport> Function(McqSummaryQuery) load, {
  List<String> permissions = const ['reports:read:gender'],
  ShareMcqSummaryAll? shareAll,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      mcqSummaryReportProvider.overrideWith((ref, query) => load(query)),
      if (shareAll != null)
        shareMcqSummaryAllProvider.overrideWithValue(shareAll),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const McqSummaryScreen()),
          GoRoute(
            path: '/admin/reports/mcq-summary/:classId',
            builder: (_, state) {
              final args = state.extra as McqSummaryClassArgs;
              return Text(
                'class ${state.pathParameters['classId']} ${args.title} '
                '${args.gender} ${args.from} ${args.to}',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget _wrapClass(
  Future<McqSummaryDetail> Function(McqSummaryClassQuery) load, {
  ShareMcqSummaryClass? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      mcqSummaryClassProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareMcqSummaryClassProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(
      home: McqSummaryClassScreen(
        classId: 7,
        args: McqSummaryClassArgs(
          title: 'A1 · AMMAR',
          gender: 1,
          from: '2026-09-01',
          to: '2026-09-30',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lists each class with its MCQ and student counts', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('4 MCQs · 12 students'), findsNWidgets(2));
  });

  testWidgets('opens on the last 30 days', (tester) async {
    final queries = <McqSummaryQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    String d(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    expect(queries.single.to, d(now));
    expect(queries.single.from, d(now.subtract(const Duration(days: 30))));
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
  });

  testWidgets('a period in which no class published MCQs says so', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report(classes: [])));
    await tester.pumpAndSettle();

    expect(
      find.text('No class published MCQs in this period.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'opening a class carries its period and gender to the class screen',
    (tester) async {
      await tester.pumpWidget(_wrap((_) async => _report()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('B1 · BILAL'));
      await tester.pumpAndSettle();

      expect(
        find.text('class 8 B1 · BILAL 1 2026-09-01 2026-09-30'),
        findsOneWidget,
      );
    },
  );

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

  testWidgets(
    'the class screen shows attempts, score and topics, and no score for none',
    (tester) async {
      await tester.pumpWidget(_wrapClass((_) async => _detail));
      await tester.pumpAndSettle();

      expect(find.text('Attempted 3 / 4 · Pending 1'), findsOneWidget);
      expect(find.text('Score 15 / 20 (75%)'), findsOneWidget);
      expect(find.text('Wudu: 9 / 12'), findsOneWidget);
      expect(find.text('Attempted 0 / 4 · Pending 4'), findsOneWidget);
      expect(find.text('Score —'), findsOneWidget);
      expect(find.text('Wudu: —'), findsOneWidget);
    },
  );

  testWidgets('the class screen asks for the list\'s period and gender', (
    tester,
  ) async {
    final queries = <McqSummaryClassQuery>[];
    await tester.pumpWidget(
      _wrapClass((query) async {
        queries.add(query);
        return _detail;
      }),
    );
    await tester.pumpAndSettle();

    expect(queries.single, (
      classId: 7,
      gender: 1,
      from: '2026-09-01',
      to: '2026-09-30',
    ));
  });

  testWidgets('a class with no students says so and offers no Share', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapClass(
        (_) async => const McqSummaryDetail(mcqs: 0, maxMarks: 0, students: []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No students to show for this class.'), findsOneWidget);
    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('a class failure offers Try again', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      _wrapClass((_) async {
        requests++;
        if (requests == 1) throw Exception('offline');
        return _detail;
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('The students could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('Share as PDF sends the class, period and format', (
    tester,
  ) async {
    final shared = <(McqSummaryClassQuery, ReportFormat)>[];
    await tester.pumpWidget(
      _wrapClass(
        (_) async => _detail,
        share: (query, format) async => shared.add((query, format)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();

    expect(shared.single.$1.classId, 7);
    expect(shared.single.$1.from, '2026-09-01');
    expect(shared.single.$2, ReportFormat.pdf);
  });

  testWidgets(
    'a failed download says so and leaves the students as they were',
    (tester) async {
      await tester.pumpWidget(
        _wrapClass(
          (_) async => _detail,
          share: (query, format) async => throw Exception('offline'),
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
      expect(find.text('Ali'), findsOneWidget);
    },
  );

  testWidgets('there is nothing to share while the class is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapClass((_) => Completer<McqSummaryDetail>().future),
    );
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });

  Future<void> chooseShareAll(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share all (CSV)'));
    await tester.pumpAndSettle();
  }

  testWidgets('Share all sends the classes in view, narrowed by search', (
    tester,
  ) async {
    final shared = <List<int>>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll:
            ({
              required classIds,
              required gender,
              required from,
              required to,
            }) async => shared.add(classIds),
      ),
    );
    await tester.pumpAndSettle();

    await chooseShareAll(tester);
    await tester.enterText(find.byType(TextField), 'teacher b1');
    await tester.pumpAndSettle();
    await chooseShareAll(tester);

    expect(shared, [
      [7, 8],
      [8],
    ]);
  });

  testWidgets('Share all is hidden without reports:read', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(), permissions: []));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('Share all is hidden when no class is in view', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(classes: [])));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('Share all with nothing to send says so and keeps filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll:
            ({
              required classIds,
              required gender,
              required from,
              required to,
            }) async => throw const ApiException('None', 404),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'teacher b1');
    await tester.pumpAndSettle();

    await chooseShareAll(tester);

    expect(find.text('There is nothing to share.'), findsOneWidget);
    expect(find.text('B1 · BILAL'), findsOneWidget);
    expect(find.text('A1 · AMMAR'), findsNothing);
  });

  testWidgets('Share all failing shows the error and keeps filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll:
            ({
              required classIds,
              required gender,
              required from,
              required to,
            }) async => throw Exception('offline'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'teacher b1');
    await tester.pumpAndSettle();

    await chooseShareAll(tester);

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('A1 · AMMAR'), findsNothing);
  });
}
