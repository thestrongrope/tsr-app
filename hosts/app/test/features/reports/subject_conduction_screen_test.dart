import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/subject_conduction_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/subject_conduction_screen.dart';

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

SubjectClass _class(String name, String level, {int weeks = 1}) => SubjectClass(
  className: name,
  level: level,
  teacher: 'Teacher $name',
  weeks: [
    for (var i = 0; i < weeks; i++)
      SubjectWeek(
        week: '2026-W${37 + i}',
        heldOn: '${9 + i * 7} Sep 2026',
        arabic: 'Alphabet',
        aqaed: '',
        ahkam: 'Wudu; Ghusl',
        akhlaq: '',
        other: '',
      ),
  ],
);

SubjectConductionReport _report({List<SubjectClass>? classes}) =>
    SubjectConductionReport(
      classChoices: const [
        ClassChoice(
          classId: 11,
          className: 'A1',
          level: 'AMMAR',
          teacher: 'Teacher A1',
        ),
        ClassChoice(
          classId: 13,
          className: 'C1',
          level: 'AMMAR',
          teacher: 'Teacher C1',
        ),
        ClassChoice(
          classId: 12,
          className: 'B1',
          level: 'BILAL',
          teacher: 'Teacher B1',
        ),
      ],
      gender: 1,
      from: '09-2026',
      to: '09-2026',
      levels: const ['AMMAR', 'BILAL'],
      classes: classes ?? [_class('A1', 'AMMAR'), _class('B1', 'BILAL')],
    );

Widget _wrap(
  Future<SubjectConductionReport> Function(SubjectConductionQuery) load, {
  ShareSubjectConduction? share,
  List<String> permissions = const ['reports:read:gender'],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      subjectConductionReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null)
        shareSubjectConductionProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: SubjectConductionScreen()),
  );
}

void main() {
  testWidgets('shows the topic of each subject, a dash for one not taught', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('Held 9 Sep 2026'), findsNWidgets(2));
    expect(find.text('Arabic: Alphabet'), findsNWidgets(2));
    expect(find.text('Aqaed: —'), findsNWidgets(2));
    expect(find.text('Ahkam: Wudu; Ghusl'), findsNWidgets(2));
    expect(find.text('Other: —'), findsNWidgets(2));
  });

  testWidgets('a class held in two weeks lists both', (tester) async {
    await tester.pumpWidget(
      _wrap((_) async => _report(classes: [_class('A1', 'AMMAR', weeks: 2)])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Held 9 Sep 2026'), findsOneWidget);
    expect(find.text('Held 16 Sep 2026'), findsOneWidget);
  });

  testWidgets('opens on the current month only', (tester) async {
    final queries = <SubjectConductionQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final month = '${now.month.toString().padLeft(2, '0')}-${now.year}';
    expect(queries.single.from, month);
    expect(queries.single.to, month);
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

  testWidgets('a period with no classes held says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(classes: [])));
    await tester.pumpAndSettle();

    expect(find.text('No classes were held in this period.'), findsOneWidget);
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
    final shared = <(SubjectConductionQuery, String?, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, level, classId, format) async =>
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
    expect(level, 'BILAL');
    expect(format, ReportFormat.xlsx);
  });

  testWidgets('a failed download says so and leaves the report as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _report(),
        share: (query, level, classId, format) async =>
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
    expect(find.text('A1 · AMMAR'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap((_) => Completer<SubjectConductionReport>().future),
    );
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

  group('class choice (#678)', () {
    Future<void> chooseClass(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('there is no class control until a level is chosen', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap((_) async => _report()));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int?>), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'AMMAR'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int?>), findsOneWidget);
      expect(find.text('All classes'), findsOneWidget);
    });

    testWidgets('a chosen class shows only that class, and is shared', (
      tester,
    ) async {
      final shared = <int?>[];
      await tester.pumpWidget(
        _wrap(
          (_) async =>
              _report(classes: [_class('A1', 'AMMAR'), _class('C1', 'AMMAR')]),
          share: (query, level, classId, format) async => shared.add(classId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'AMMAR'));
      await tester.pumpAndSettle();
      expect(find.text('A1 · AMMAR'), findsOneWidget);
      expect(find.text('C1 · AMMAR'), findsOneWidget);

      await chooseClass(tester, 'C1 · Teacher C1');
      expect(find.text('A1 · AMMAR'), findsNothing);
      expect(find.text('C1 · AMMAR'), findsOneWidget);

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share as PDF'));
      await tester.pumpAndSettle();
      expect(shared, [13]);
    });

    testWidgets('changing the level resets the class', (tester) async {
      final shared = <int?>[];
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          share: (query, level, classId, format) async => shared.add(classId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'AMMAR'));
      await tester.pumpAndSettle();
      await chooseClass(tester, 'A1 · Teacher A1');

      await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
      await tester.pumpAndSettle();
      expect(find.text('All classes'), findsOneWidget);
      expect(find.text('B1 · BILAL'), findsOneWidget);

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share as PDF'));
      await tester.pumpAndSettle();
      expect(shared, [null]);
    });

    testWidgets('a class with no sessions says so and keeps the control', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap((_) async => _report()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'AMMAR'));
      await tester.pumpAndSettle();

      await chooseClass(tester, 'C1 · Teacher C1');

      expect(
        find.text('No sessions for this class in this period.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<int?>), findsOneWidget);
    });
  });
}
