import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/tsr_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/tsr_report_screen.dart';

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

TsrReport _report({bool empty = false}) => TsrReport.fromJson(
  jsonDecode(
    jsonEncode({
      'gender': 1,
      'from': '2026-09-29',
      'to': '2026-10-13',
      'conduction': {
        'levels': empty
            ? []
            : [
                {'level': 'AMMAR', 'conducted': 4, 'total': 6, 'percent': 66.7},
                {
                  'level': 'BILAL',
                  'conducted': 3,
                  'total': 3,
                  'percent': 100.0,
                },
              ],
        'classes': empty
            ? []
            : [
                {
                  'level': 'AMMAR',
                  'class': 'A1',
                  'teacher': 'Teacher A',
                  'lastConducted': '2026-10-08',
                },
                {
                  'level': 'AMMAR',
                  'class': 'A2',
                  'teacher': 'Teacher B',
                  'lastConducted': null,
                },
                {
                  'level': 'BILAL',
                  'class': 'B1',
                  'teacher': 'Teacher C',
                  'lastConducted': '2026-10-09',
                },
              ],
      },
      'mcq': {'levels': [], 'classes': []},
      'attendance': {
        'levels': empty
            ? []
            : [
                {'level': 'AMMAR', 'percent': 83},
              ],
        'classes': [],
      },
      'recitation': {'levels': [], 'classes': []},
    }),
  ),
);

Widget _wrap(
  Future<TsrReport> Function(TsrQuery) load, {
  List<String> permissions = const ['reports:read:gender'],
  ShareTsr? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      tsrReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareTsrProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: TsrReportScreen()),
  );
}

void main() {
  testWidgets('shows each section with a line per level', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('Class conduction'), findsOneWidget);
    expect(find.text('4 of 6 (66.7%)'), findsOneWidget);
    expect(find.text('3 of 3 (100%)'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
  });

  testWidgets('opens on the last fourteen days', (tester) async {
    final queries = <TsrQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 14));
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    expect(queries.single.from, d(from));
    expect(queries.single.to, d(to));
  });

  testWidgets('tapping a level lists its classes and when each last held', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var requests = 0;
    await tester.pumpWidget(
      _wrap((_) async {
        requests++;
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('4 of 6 (66.7%)'));
    await tester.pumpAndSettle();

    expect(find.text('Class conduction · AMMAR'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Teacher A'), findsOneWidget);
    expect(find.text('Last held 2026-10-08'), findsOneWidget);
    expect(find.text('None in this period'), findsOneWidget);
    expect(find.text('B1'), findsNothing, reason: 'that is BILAL\'s');
    expect(requests, 1, reason: 'the drill-down does not ask the server again');
  });

  testWidgets('a period with no classes says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(empty: true)));
    await tester.pumpAndSettle();

    expect(find.text('No classes were found in this period.'), findsOneWidget);
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

    expect(find.text('Class conduction'), findsOneWidget);
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

  testWidgets('Share sends the dates and gender on screen', (tester) async {
    final shared = <(TsrQuery, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, format) async => shared.add((query, format)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single.$1.gender, 1);
    expect(shared.single.$1.from, isNot(shared.single.$1.to));
    expect(shared.single.$2, ReportFormat.pdf);
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
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Class conduction'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) => Completer<TsrReport>().future));
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });
}
