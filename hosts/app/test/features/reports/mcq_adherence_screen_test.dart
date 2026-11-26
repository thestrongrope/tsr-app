import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/mcq_adherence_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/mcq_adherence_screen.dart';

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

McqAdherenceClass _class(int id, String name, String level, double pct) =>
    McqAdherenceClass(
      classId: id,
      className: name,
      level: level,
      teacher: 'Teacher $name',
      figures: McqAdherenceFigures(
        expected: 3,
        conducted: 1,
        pending: 1,
        skipped: 1,
        adherencePercent: pct,
      ),
    );

McqAdherenceReport _report({List<McqAdherenceClass>? classes}) =>
    McqAdherenceReport(
      gender: 1,
      levels: const ['BILAL', 'AMMAR'],
      classes:
          classes ??
          [_class(8, 'B1', 'BILAL', 12.5), _class(7, 'A1', 'AMMAR', 33.3)],
    );

const _detail = McqAdherenceDetail(
  figures: McqAdherenceFigures(
    expected: 3,
    conducted: 1,
    pending: 1,
    skipped: 1,
    adherencePercent: 33.3,
  ),
  mcqs: [
    AdherenceMcq(
      topic: 'Fiqh',
      subject: 'Wudu',
      lesson: '1',
      name: 'One',
      status: 'conducted',
    ),
    AdherenceMcq(
      topic: 'Fiqh',
      subject: 'Wudu',
      lesson: '2',
      name: 'Two',
      status: 'pending',
    ),
    AdherenceMcq(
      topic: 'Fiqh',
      subject: 'Salat',
      lesson: '1',
      name: 'Three',
      status: 'skipped',
    ),
  ],
);

Widget _wrap(
  Future<McqAdherenceReport> Function(int?) load, {
  List<String> permissions = const ['reports:read:gender'],
  ShareMcqAdherenceAll? shareAll,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      mcqAdherenceReportProvider.overrideWith((ref, gender) => load(gender)),
      if (shareAll != null)
        shareMcqAdherenceAllProvider.overrideWithValue(shareAll),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const McqAdherenceScreen()),
          GoRoute(
            path: '/admin/reports/mcq-adherence/:classId',
            builder: (_, state) {
              final args = state.extra as McqAdherenceClassArgs;
              return Text(
                'class ${state.pathParameters['classId']} ${args.title} '
                '${args.gender}',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget _wrapClass(
  Future<McqAdherenceDetail> Function(McqAdherenceClassQuery) load, {
  ShareMcqAdherenceClass? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      mcqAdherenceClassProvider.overrideWith((ref, query) => load(query)),
      if (share != null)
        shareMcqAdherenceClassProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(
      home: McqAdherenceClassScreen(
        classId: 7,
        args: McqAdherenceClassArgs(title: 'A1 · AMMAR', gender: 1),
      ),
    ),
  );
}

void main() {
  testWidgets('lists the classes worst first with their figures', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('Adherence 12.5%'), findsOneWidget);
    expect(find.text('Adherence 33.3%'), findsOneWidget);
    expect(
      find.text('1 of 3 conducted · 1 pending · 1 skipped'),
      findsNWidgets(2),
    );
    expect(
      tester.getTopLeft(find.text('B1 · BILAL')).dy,
      lessThan(tester.getTopLeft(find.text('A1 · AMMAR')).dy),
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

    await tester.tap(find.widgetWithText(ChoiceChip, 'AMMAR'));
    await tester.pumpAndSettle();

    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('B1 · BILAL'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('searching narrows the classes by code or teacher', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'teacher a1');
    await tester.pumpAndSettle();
    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('B1 · BILAL'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search.'), findsOneWidget);
  });

  testWidgets('no class with standard MCQs says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(classes: [])));
    await tester.pumpAndSettle();

    expect(find.text('No class has standard MCQs to follow.'), findsOneWidget);
  });

  testWidgets('opening a class carries its name and gender on', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A1 · AMMAR'));
    await tester.pumpAndSettle();

    expect(find.text('class 7 A1 · AMMAR 1'), findsOneWidget);
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

  testWidgets('the class screen lists each MCQ with its status', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapClass((_) async => _detail));
    await tester.pumpAndSettle();

    expect(find.text('Adherence 33.3% · 1 of 3 conducted'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Conducted'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Fiqh · Salat'), findsOneWidget);
  });

  testWidgets('a class with no standard MCQs says so and offers no Share', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapClass(
        (_) async => const McqAdherenceDetail(
          figures: McqAdherenceFigures(
            expected: 0,
            conducted: 0,
            pending: 0,
            skipped: 0,
            adherencePercent: 0,
          ),
          mcqs: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This class has no standard MCQs.'), findsOneWidget);
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

    expect(find.text('The MCQs could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('Share as PDF sends the class, gender and format', (
    tester,
  ) async {
    final shared = <(McqAdherenceClassQuery, ReportFormat)>[];
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

    expect(shared.single.$1, (classId: 7, gender: 1));
    expect(shared.single.$2, ReportFormat.pdf);
  });

  testWidgets('a failed download says so and leaves the MCQs as they were', (
    tester,
  ) async {
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
    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('there is nothing to share while the class is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapClass((_) => Completer<McqAdherenceDetail>().future),
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
        shareAll: ({required classIds, required gender}) async =>
            shared.add(classIds),
      ),
    );
    await tester.pumpAndSettle();

    await chooseShareAll(tester);
    await tester.enterText(find.byType(TextField), 'teacher b1');
    await tester.pumpAndSettle();
    await chooseShareAll(tester);

    expect(shared, [
      [8, 7],
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
        shareAll: ({required classIds, required gender}) async =>
            throw const ApiException('None', 404),
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
        shareAll: ({required classIds, required gender}) async =>
            throw Exception('offline'),
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
