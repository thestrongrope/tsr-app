import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/conduction_report.dart';
import 'package:the_strong_rope/features/reports/models/weekly_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/weekly_report_screen.dart';

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

WeeklyCell _cell(WeekStatus status, [int sessions = 0]) =>
    WeeklyCell(status: status, sessions: sessions);

/// Two weeks in the past, so the screen opens on the last one.
WeeklyReport _report({List<WeeklyClass>? classes}) => WeeklyReport(
  gender: 1,
  from: '09-2026',
  to: '09-2026',
  levels: const ['AMMAR', 'BILAL'],
  weeks: const [
    WeeklyWeek(
      month: 'Sep-2026',
      label: 'Wk 1',
      from: '2026-08-30',
      to: '2026-09-05',
    ),
    WeeklyWeek(
      month: 'Sep-2026',
      label: 'Wk 2',
      from: '2026-09-06',
      to: '2026-09-12',
    ),
  ],
  classes:
      classes ??
      [
        WeeklyClass(
          classId: 7,
          level: 'AMMAR',
          className: 'A1',
          teacher: 'Teacher A1',
          weeks: [_cell(WeekStatus.held, 1), _cell(WeekStatus.held, 2)],
        ),
        WeeklyClass(
          classId: 8,
          level: 'BILAL',
          className: 'B1',
          teacher: 'Teacher B1',
          weeks: [_cell(WeekStatus.notHeld), _cell(WeekStatus.notFilled)],
        ),
      ],
);

Widget _wrap(
  Future<WeeklyReport> Function(WeeklyQuery) load, {
  ShareWeekly? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith(
        (ref) => _FixedPermissions(['reports:read:gender']),
      ),
      weeklyReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareWeeklyProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: WeeklyReportScreen()),
  );
}

void main() {
  testWidgets('opens on the last week and shows each class\'s result', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('Sep-2026 · Wk 2'), findsOneWidget);
    expect(find.text('Held (2)'), findsOneWidget);
    expect(find.text('Not filled'), findsOneWidget);
  });

  testWidgets('previous steps to the week before', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();

    expect(find.text('Sep-2026 · Wk 1'), findsOneWidget);
    expect(find.text('Held'), findsOneWidget);
    expect(find.text('Not held'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
      reason: 'nothing before the first week',
    );
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

  testWidgets('a range with no sessions says so', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(
          classes: [
            WeeklyClass(
              classId: 7,
              level: 'AMMAR',
              className: 'A1',
              teacher: '',
              weeks: [_cell(WeekStatus.notFilled), _cell(WeekStatus.notFilled)],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No sessions were recorded in this period.'),
      findsOneWidget,
    );
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

    expect(find.text('Sep-2026 · Wk 2'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets(
    'choosing From asks for the range; To earlier than From pulls From along',
    (tester) async {
      // Tall enough for the open menu to build all twelve months.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final queries = <WeeklyQuery>[];
      await tester.pumpWidget(
        _wrap((query) async {
          queries.add(query);
          return _report();
        }),
      );
      await tester.pumpAndSettle();
      final current = queries.single.from!;
      expect(queries.single.to, current);

      final now = DateTime.now();
      final oldest = DateTime(now.year, now.month - 11);
      const names = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
      ];
      final oldestLabel = '${names[oldest.month - 1]} ${oldest.year}';

      Future<void> pick(String field) async {
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, field),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(oldestLabel).last);
        await tester.pumpAndSettle();
      }

      await pick('From');
      expect(queries.last.from, isNot(current));
      expect(queries.last.to, current);

      await pick('To');
      expect(
        queries.last.to,
        queries.last.from,
        reason: 'From cannot be after To',
      );
    },
  );

  testWidgets('Share as Excel sends the months and level on screen', (
    tester,
  ) async {
    final shared = <(WeeklyQuery, String?, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, level, format) async =>
            shared.add((query, level, format)),
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
    final (query, level, format) = shared.single;
    expect(query.gender, 1);
    expect(query.from, query.to);
    expect(level, 'BILAL');
    expect(format, ReportFormat.xlsx);
  });

  testWidgets('a failed download says so and leaves the report as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, level, format) async => throw Exception('offline'),
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
    expect(find.text('Sep-2026 · Wk 2'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) => Completer<WeeklyReport>().future));
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
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
    expect(find.text('Sep-2026 · Wk 2'), findsOneWidget, reason: 'week stays');

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search.'), findsOneWidget);
  });
}
