import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/active_teachers_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/active_teachers_screen.dart';

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

const _ali = ActiveTeacher(
  token: 1001,
  name: 'Ali',
  attendingClass: 'C1, C2',
  selfTeacher: 'T1, T2',
  maxLevel: 'AMMAR',
  totalClasses: 2,
  conductingClasses: 'A1, A2',
);
const _zayd = ActiveTeacher(
  token: 2002,
  name: 'Zayd',
  attendingClass: '',
  selfTeacher: '',
  maxLevel: 'BILAL',
  totalClasses: 1,
  conductingClasses: 'B1',
);

ActiveTeachersReport _report({List<ActiveTeacher>? teachers}) =>
    ActiveTeachersReport(gender: 1, teachers: teachers ?? [_ali, _zayd]);

Widget _wrap(
  Future<ActiveTeachersReport> Function(int?) load, {
  ShareActiveTeachers? share,
  List<String> permissions = const ['reports:read:gender'],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      activeTeachersReportProvider.overrideWith((ref, gender) => load(gender)),
      if (share != null) shareActiveTeachersProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: ActiveTeachersScreen()),
  );
}

void main() {
  testWidgets('shows what each teacher conducts and attends', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Token 1001'), findsOneWidget);
    expect(find.text('Conducts 2: A1, A2'), findsOneWidget);
    expect(find.text('Highest level AMMAR'), findsOneWidget);
    expect(find.text('Attends C1, C2 (T1, T2)'), findsOneWidget);
    expect(find.text('Conducts 1: B1'), findsOneWidget);
    expect(find.textContaining('Attends'), findsOneWidget);
  });

  testWidgets('searching narrows by name, token or class', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2002');
    await tester.pumpAndSettle();
    expect(find.text('Zayd'), findsOneWidget);
    expect(find.text('Ali'), findsNothing);

    await tester.enterText(find.byType(TextField), 'a2');
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Zayd'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No teachers match your search.'), findsOneWidget);
  });

  testWidgets('no active teachers says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(teachers: [])));
    await tester.pumpAndSettle();

    expect(find.text('There are no active teachers to show.'), findsOneWidget);
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

    expect(find.text('Ali'), findsOneWidget);
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

  testWidgets('Share as Excel sends the gender on screen', (tester) async {
    final shared = <(int, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (gender, format) async => shared.add((gender, format)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(shared, [(1, ReportFormat.xlsx)]);
  });

  testWidgets('a failed download says so and leaves the report as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (gender, format) async => throw Exception('offline'),
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
    expect(find.text('Ali'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap((_) => Completer<ActiveTeachersReport>().future),
    );
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });
}
