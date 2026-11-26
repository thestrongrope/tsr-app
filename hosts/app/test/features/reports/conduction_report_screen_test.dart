import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/conduction_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/conduction_report_screen.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions, {PermissionScopes? scopes}) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: scopes ?? const PermissionScopes(),
        issuedAt: '',
      ),
    );
  }
}

ConductionClass _class(String name, String level, {int conducted = 4}) =>
    ConductionClass(
      level: level,
      className: name,
      teacher: 'Teacher $name',
      expected: 6,
      conducted: conducted,
      notFilled: 6 - conducted,
      notConducted: 0,
      students: 20,
      percentConduction: 80,
      percentAttendance: 60,
      percentNotFilled: 17,
    );

ConductionReport _report({
  List<ConductionClass>? classes,
  List<ConductionWeekRow>? lastWeek,
  int week = 40,
}) {
  return ConductionReport(
    gender: 1,
    year: 2026,
    week: week,
    // The server's neighbours: 40 is the last completed week, so no next.
    previous: (year: 2026, week: week - 1),
    next: week >= 40 ? null : (year: 2026, week: week + 1),
    weekOf: '04-Oct to 10-Oct',
    summaryStart: 'Mon, 01-Sep-26',
    summaryEnd: 'Sun, 11-Oct-26',
    levels: const ['AMMAR', 'BILAL'],
    classes: classes ?? [_class('A1', 'AMMAR'), _class('B1', 'BILAL')],
    lastWeek:
        lastWeek ??
        const [
          ConductionWeekRow(
            classId: 7,
            level: 'AMMAR',
            className: 'A1',
            teacher: 'Teacher A1',
            status: WeekStatus.held,
            conductedOn: '2026-10-08',
            attendance: 14,
            duration: 60,
          ),
          ConductionWeekRow(
            classId: 8,
            level: 'BILAL',
            className: 'B1',
            teacher: 'Teacher B1',
            status: WeekStatus.notFilled,
          ),
        ],
  );
}

Widget _wrap(
  Future<ConductionReport> Function(ConductionQuery) load, {
  List<String> permissions = const ['reports:read:gender'],
  ShareConduction? share,
  ShareConductionAllWeeks? shareAll,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith(
        (ref) => _FixedPermissions(
          permissions,
          scopes: const PermissionScopes(gender: 1),
        ),
      ),
      conductionReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareConductionProvider.overrideWithValue(share),
      if (shareAll != null)
        shareConductionAllWeeksProvider.overrideWithValue(shareAll),
    ],
    child: const MaterialApp(home: ConductionReportScreen()),
  );
}

void main() {
  testWidgets('shows the week, each class and how its session went', (
    tester,
  ) async {
    // Tall enough to build both class cards below the search box.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('04-Oct to 10-Oct'), findsOneWidget);
    expect(find.text('Held'), findsOneWidget);
    expect(find.text('Not filled'), findsOneWidget);
    expect(
      find.textContaining('2026-10-08 · 14 present · 60 min'),
      findsOneWidget,
    );
    expect(find.text('Conduction 80% · Attendance 60%'), findsNWidgets(2));
  });

  testWidgets('a class that never met is marked never held', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(classes: [_class('B1', 'BILAL', conducted: 0)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Never held'), findsOneWidget);
  });

  testWidgets('a level chip narrows both lists without a new request', (
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

    expect(find.text('B1 · BILAL'), findsNWidgets(2));
    expect(find.text('A1 · AMMAR'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('an empty week says so', (tester) async {
    await tester.pumpWidget(
      _wrap((_) async => _report(classes: [], lastWeek: [])),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No classes were expected to meet this week.'),
      findsOneWidget,
    );
    expect(find.text('No classes to summarise.'), findsOneWidget);
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

    expect(find.text('Held'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets('previous and next ask for the weeks the server named', (
    tester,
  ) async {
    final queries = <ConductionQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report(week: query.week ?? 40);
      }),
    );
    await tester.pumpAndSettle();

    IconButton next() => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(queries.single.week, isNull, reason: 'the server picks the default');
    expect(next().onPressed, isNull, reason: 'nothing after the last week');

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();

    expect((queries.last.year, queries.last.week), (2026, 39));
    expect(next().onPressed, isNotNull);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();

    expect(queries.last.week, 40);
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

  testWidgets('Share as Excel sends the week and level on screen', (
    tester,
  ) async {
    final shared = <(ConductionQuery, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, format) async => shared.add((query, format)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single.$1, (gender: 1, year: 2026, week: 40, level: 'BILAL'));
    expect(shared.single.$2, ReportFormat.xlsx);
  });

  testWidgets('a failed download says so and leaves the report as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, format) async => throw Exception('offline'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Week 40'), findsOneWidget);
    expect(find.text('Held'), findsOneWidget);
    // Share is usable again afterwards.
    final menu = tester.widget<PopupMenuButton<ConductionShare>>(
      find.byType(PopupMenuButton<ConductionShare>),
    );
    expect(menu.enabled, isTrue);
  });

  Future<void> chooseAllWeeks(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share all weeks (CSV)'));
    await tester.pumpAndSettle();
  }

  testWidgets('Share all weeks sends the gender and week, not the level', (
    tester,
  ) async {
    final shared = <ConductionQuery>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll: (query) async => shared.add(query),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();

    await chooseAllWeeks(tester);

    expect(shared, [(gender: 1, year: 2026, week: 40, level: null)]);
  });

  testWidgets('Share all weeks with no data says so', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll: (query) async => throw const ApiException('No data', 404),
      ),
    );
    await tester.pumpAndSettle();

    await chooseAllWeeks(tester);

    expect(find.text('There is no data to share yet.'), findsOneWidget);
  });

  testWidgets('Share all weeks failing shows the error and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        shareAll: (query) async {
          attempts++;
          throw Exception('offline');
        },
      ),
    );
    await tester.pumpAndSettle();

    await chooseAllWeeks(tester);
    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
    await chooseAllWeeks(tester);

    expect(attempts, 2);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) => Completer<ConductionReport>().future));
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('searching narrows both lists by code or teacher', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'teacher b1');
    await tester.pumpAndSettle();
    expect(find.text('B1 · BILAL'), findsNWidgets(2));
    expect(find.text('A1 · AMMAR'), findsNothing);
    expect(find.text('Week 40'), findsOneWidget, reason: 'week stays');

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search.'), findsNWidgets(2));
  });
}
