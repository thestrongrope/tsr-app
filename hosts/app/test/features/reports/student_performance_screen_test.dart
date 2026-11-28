import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/student_performance.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/student_performance_screen.dart';

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

StudentPerformance _student(
  String token,
  String name,
  String level,
  String className, {
  int tsr = 60,
}) => StudentPerformance(
  token: token,
  name: name,
  level: level,
  className: className,
  sessions: 8,
  attendance: 83,
  totalMcqs: 4,
  mcqAttempted: 75,
  mcqPerformance: 50,
  recitation: 10,
  recitationAvg: 1.25,
  tsrScore: tsr,
);

StudentsReport _report({List<StudentPerformance>? students}) => StudentsReport(
  gender: 1,
  from: '2026-09-13',
  to: '2026-10-13',
  levels: const ['AMMAR', 'BILAL'],
  classes: const [
    StudentClass(className: 'A1', level: 'AMMAR'),
    StudentClass(className: 'B1', level: 'BILAL'),
    StudentClass(className: 'B2', level: 'BILAL'),
  ],
  students:
      students ??
      [
        _student('101', 'Ann Test', 'AMMAR', 'A1', tsr: 70),
        _student('202', 'Bob Test', 'BILAL', 'B1', tsr: 90),
        _student('303', 'Cy Test', 'BILAL', 'B2', tsr: 50),
      ],
);

Widget _wrap(
  Future<StudentsReport> Function(StudentsQuery) load, {
  List<String> permissions = const ['reports:read:gender'],
  ShareStudents? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      studentsReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareStudentsProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: StudentPerformanceScreen()),
  );
}

/// The student names on screen, top to bottom.
List<String> _order(WidgetTester tester) {
  final names = ['Ann Test', 'Bob Test', 'Cy Test'];
  final found = [
    for (final n in names)
      if (find.text(n).evaluate().isNotEmpty) n,
  ];
  found.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return found;
}

void main() {
  testWidgets('shows each student with their figures, best TSR score first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(_order(tester), ['Bob Test', 'Ann Test', 'Cy Test']);
    expect(find.text('#101 · A1 · AMMAR'), findsOneWidget);
    expect(find.text('Attendance 83% · 8 sessions'), findsNWidgets(3));
    expect(find.text('Recitation 10 · 1.25 per session'), findsNWidgets(3));
    expect(find.text('90%'), findsOneWidget);
  });

  testWidgets('opens on the last thirty days', (tester) async {
    final queries = <StudentsQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    expect(queries.single.to, d(to));
    expect(queries.single.from, d(from));
    expect(find.text('${d(from)} to ${d(to)}'), findsOneWidget);
  });

  testWidgets('a level chip then a class narrows the students', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
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

    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();
    expect(_order(tester), ['Bob Test', 'Cy Test']);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2').last);
    await tester.pumpAndSettle();
    expect(_order(tester), ['Cy Test']);
    expect(requests, 1, reason: 'filtering does not ask the server again');
  });

  testWidgets('search matches token, name or class', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '202');
    await tester.pumpAndSettle();
    expect(_order(tester), ['Bob Test']);

    await tester.enterText(find.byType(TextField), 'cy');
    await tester.pumpAndSettle();
    expect(_order(tester), ['Cy Test']);

    await tester.enterText(find.byType(TextField), 'a1');
    await tester.pumpAndSettle();
    expect(_order(tester), ['Ann Test']);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No students match your search.'), findsOneWidget);
  });

  testWidgets('Order by changes the order', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<StudentSort>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();

    expect(_order(tester), ['Ann Test', 'Bob Test', 'Cy Test']);
  });

  testWidgets('a period with no students says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(students: [])));
    await tester.pumpAndSettle();

    expect(find.text('No students were found in this period.'), findsOneWidget);
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

    expect(find.text('Bob Test'), findsOneWidget);
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

  testWidgets('Share sends the dates, level and class on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shared = <(StudentsQuery, String?, String?, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, level, className, format) async =>
            shared.add((query, level, className, format)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    final (query, level, className, format) = shared.single;
    expect(query.gender, 1);
    expect(query.from, isNotNull);
    expect(level, 'BILAL');
    expect(className, 'B2');
    expect(format, ReportFormat.xlsx);
  });

  testWidgets('a failed download says so and leaves the report as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, level, className, format) async =>
            throw Exception('offline'),
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
    expect(find.text('Bob Test'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) => Completer<StudentsReport>().future));
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });
}
