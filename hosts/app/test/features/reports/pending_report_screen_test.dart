import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/utils/api_datetime.dart';
import 'package:the_strong_rope/features/reports/models/pending_report.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/pending_report_screen.dart';

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

PendingClass _class(int id, String code, String level, int forms, int mcq) =>
    PendingClass(
      classId: id,
      level: level,
      className: code,
      notFilled: forms,
      mcqPending: mcq,
      mcqConducted: 4,
      mcqExpected: 20,
    );

PendingReport _report({List<PendingTeacher>? teachers}) => PendingReport(
  gender: 1,
  from: '09-2026',
  to: '10-2026',
  levels: const ['AMMAR', 'BILAL'],
  teachers:
      teachers ??
      [
        PendingTeacher(
          token: 100,
          name: 'Teacher A',
          classes: [
            _class(1, 'A1', 'AMMAR', 3, 3),
            _class(2, 'B1', 'BILAL', 2, 0),
          ],
        ),
        PendingTeacher(
          token: 200,
          name: 'Teacher B',
          classes: [_class(3, 'A2', 'AMMAR', 0, 2)],
        ),
      ],
);

Widget _wrap(
  Future<PendingReport> Function(PendingQuery) load, {
  List<String> permissions = const ['reports:read:gender'],
  SharePending? share,
  NudgeTeacher? nudge,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      pendingReportProvider.overrideWith((ref, query) => load(query)),
      if (share != null) sharePendingProvider.overrideWithValue(share),
      if (nudge != null) nudgeTeacherProvider.overrideWithValue(nudge),
    ],
    child: const MaterialApp(home: PendingReportScreen()),
  );
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows each teacher with totals and their classes', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    expect(find.text('Teacher A'), findsOneWidget);
    expect(find.text('5 forms not filled · 3 MCQs pending'), findsOneWidget);
    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('3 forms · 3 MCQs'), findsOneWidget);
    expect(find.text('2 teachers · 5 forms · 5 MCQs pending'), findsOneWidget);
  });

  testWidgets('opens on the previous and the current month', (tester) async {
    final queries = <PendingQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _report();
      }),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    String mm(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.year}';
    expect(queries.single.from, mm(DateTime(now.year, now.month - 1)));
    expect(queries.single.to, mm(now));
  });

  testWidgets('a level chip recounts the totals without a new request', (
    tester,
  ) async {
    tall(tester);
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

    expect(find.text('Teacher A'), findsOneWidget);
    expect(find.text('2 forms not filled · 0 MCQs pending'), findsOneWidget);
    expect(find.text('Teacher B'), findsNothing, reason: 'no BILAL class');
    expect(requests, 1);
  });

  testWidgets('search matches a teacher or a class', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap((_) async => _report()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'teacher b');
    await tester.pumpAndSettle();
    expect(find.text('Teacher B'), findsOneWidget);
    expect(find.text('Teacher A'), findsNothing);

    await tester.enterText(find.byType(TextField), 'b1');
    await tester.pumpAndSettle();
    expect(find.text('Teacher A'), findsOneWidget);
    expect(find.text('Teacher B'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(
      find.text('No teachers or classes match your search.'),
      findsOneWidget,
    );
  });

  testWidgets('nothing pending says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _report(teachers: [])));
    await tester.pumpAndSettle();

    expect(find.text('Nothing is pending in this period.'), findsOneWidget);
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

    expect(find.text('Teacher A'), findsOneWidget);
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

  testWidgets('Share sends the months and level on screen', (tester) async {
    tall(tester);
    final shared = <(PendingQuery, String?, ReportFormat)>[];
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
    expect(find.text('Teacher A'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ReportFormat>>(
      find.byType(PopupMenuButton<ReportFormat>),
    );
    expect(menu.enabled, isTrue);
  });

  testWidgets('there is nothing to share while the report is loading', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) => Completer<PendingReport>().future));
    await tester.pump();

    expect(find.byTooltip('Share'), findsNothing);
  });

  group('Remind', () {
    PendingNudge answer({
      bool already = false,
      bool sent = false,
      String? last,
    }) => PendingNudge(
      teacher: 'Teacher A',
      title: 'Reminder from the class coordination team',
      body:
          'Assalamu Alaikum. Please complete the following:\n• A1: 3 class forms',
      alreadyReminded: already,
      lastReminded: last,
      sent: sent,
    );

    /// Every call the screen makes: (teacher token, send).
    NudgeTeacher recording(
      List<(int, bool)> calls,
      PendingNudge Function(bool send) reply,
    ) => (query, teacherToken, {required send}) async {
      calls.add((teacherToken, send));
      return reply(send);
    };

    testWidgets('shows the exact message and, on Cancel, sends nothing', (
      tester,
    ) async {
      tall(tester);
      final calls = <(int, bool)>[];
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          nudge: recording(calls, (send) => answer()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remind').first);
      await tester.pumpAndSettle();

      expect(find.text('Remind Teacher A?'), findsOneWidget);
      expect(find.textContaining('• A1: 3 class forms'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, [(100, false)], reason: 'only the preview was asked for');
      expect(find.text('Reminder sent to Teacher A.'), findsNothing);
    });

    testWidgets('Send sends it once, and says so', (tester) async {
      tall(tester);
      final calls = <(int, bool)>[];
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          nudge: recording(calls, (send) => answer(sent: send)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remind').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(calls, [(100, false), (100, true)]);
      expect(find.text('Reminder sent to Teacher A.'), findsOneWidget);
    });

    testWidgets('a teacher reminded today cannot be sent to again', (
      tester,
    ) async {
      tall(tester);
      final calls = <(int, bool)>[];
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          nudge: recording(
            calls,
            (send) => answer(already: true, last: '2026-10-14 08:00:00'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remind').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Already reminded at ${formatApiLocalDateTime('2026-10-14 08:00:00')}',
        ),
        findsOneWidget,
      );
      expect(find.text('Send'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(calls, [(100, false)]);
    });

    testWidgets('a failed preview says so and shows no dialog', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          nudge: (query, teacherToken, {required send}) async =>
              throw Exception('offline'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remind').first);
      await tester.pumpAndSettle();

      expect(
        find.text('The reminder could not be prepared. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Teacher A'),
        findsOneWidget,
        reason: 'screen as it was',
      );
    });

    testWidgets('a refusal on send shows the server\'s reason', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          nudge: (query, teacherToken, {required send}) async {
            if (send) {
              throw const ApiException(
                'This teacher was already reminded in the last 24 hours',
                429,
              );
            }
            return answer();
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remind').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(
        find.text('This teacher was already reminded in the last 24 hours'),
        findsOneWidget,
      );
    });

    testWidgets('any other failure on send says it could not be sent', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        _wrap(
          (_) async => _report(),
          nudge: (query, teacherToken, {required send}) async {
            if (send) throw Exception('boom');
            return answer();
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remind').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(
        find.text('The reminder could not be sent. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
