import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/summary_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/summary_report_screen.dart';

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

SummaryClass _class(
  String name,
  String level, {
  int expected = 12,
  SummarySubjects? subjects,
}) => SummaryClass(
  classId: 1,
  level: level,
  className: name,
  teacher: 'Teacher $name',
  expected: expected,
  conducted: 8,
  notFilled: 1,
  notConducted: 3,
  avgStudents: 14,
  avgDuration: 55,
  percentNotFilled: 8,
  percentConduction: 67,
  percentAttendance: 73,
  subjects: subjects,
);

const _subjects = SummarySubjects(
  arabic: SubjectFigure(count: 4, percent: 50),
  aqaed: SubjectFigure(count: 2, percent: 25),
  ahkam: SubjectFigure(count: 1, percent: 13),
  akhlaq: SubjectFigure(count: 0, percent: 0),
  other: SubjectFigure(count: 3, percent: 38),
);

SummaryReport _report({List<SummaryClass>? classes}) => SummaryReport(
  gender: 1,
  from: '07-2026',
  to: '10-2026',
  levels: const ['AMMAR', 'BILAL'],
  classes:
      classes ??
      [_class('A1', 'AMMAR', subjects: _subjects), _class('B1', 'BILAL')],
);

Widget _wrap(
  Future<SummaryReport> Function(SummaryQuery) load, {
  ShareSummary? share,
  List<String> permissions = const ['reports:read:gender'],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      summaryReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareSummaryProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: SummaryReportScreen()),
  );
}

void main() {
  testWidgets('shows each class\'s figures and its subjects where it has any', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('Conduction 67% · Attendance 73%'), findsNWidgets(2));
    expect(
      find.text('Held 8 of 12 · 1 not filled · 3 not held'),
      findsNWidgets(2),
    );
    expect(find.text('Avg 14 students · 55 min'), findsNWidgets(2));
    expect(
      find.text(
        'Arabic 4 (50%) · Aqaed 2 (25%) · Ahkam 1 (13%) · Akhlaq 0 (0%) · Other 3 (38%)',
      ),
      findsOneWidget,
      reason: 'only A1 records subjects',
    );
  });

  testWidgets('opens on the last three months to now', (tester) async {
    final queries = <SummaryQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    String mm(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.year}';
    expect(queries.single.from, mm(DateTime(now.year, now.month - 3)));
    expect(queries.single.to, mm(now));
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

  testWidgets('a period with no sessions says so', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(classes: [_class('A1', 'AMMAR', expected: 0)]),
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

  testWidgets('Share as Excel sends the months and level on screen', (
    tester,
  ) async {
    final shared = <(SummaryQuery, String?, ReportFormat)>[];
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
    expect(query.from, isNot(query.to));
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
    expect(find.text('A1 · AMMAR'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) => Completer<SummaryReport>().future));
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

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search.'), findsOneWidget);
  });
}
