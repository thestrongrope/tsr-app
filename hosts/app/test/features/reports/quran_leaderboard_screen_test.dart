import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/quran_leaderboard.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/quran_leaderboard_screen.dart';

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

const _student = LeaderboardStudent(
  rank: 1,
  name: 'Ali',
  token: 1001,
  className: 'A1',
  recitation: 120,
);

QuranLeaderboard _board({
  List<LeaderboardStudent> students = const [_student],
  int? total,
}) => QuranLeaderboard(
  gender: 1,
  from: '2025-10-15',
  to: '2026-10-15',
  levels: const ['AMMAR', 'BILAL'],
  total: total ?? students.length,
  students: students,
);

Widget _wrap(
  Future<QuranLeaderboard> Function(QuranLeaderboardQuery) load, {
  List<String> permissions = const ['quran-leaderboard:read:gender'],
  ShareQuranLeaderboard? share,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      quranLeaderboardProvider.overrideWith((ref, query) => load(query)),
      if (share != null) shareQuranLeaderboardProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: QuranLeaderboardScreen()),
  );
}

void main() {
  testWidgets('lists each ranked student with class, token and recitation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _board()));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('A1 · token 1001'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('1 students'), findsOneWidget);
  });

  testWidgets('opens on the last year', (tester) async {
    final queries = <QuranLeaderboardQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _board();
      }),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    String d(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    expect(queries.single.to, d(now));
    expect(queries.single.from, d(DateTime(now.year - 1, now.month, now.day)));
    expect(queries.single.level, isNull);
    expect(queries.single.minimum, 1);
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);
  });

  testWidgets('says when only the top of a longer ranking is shown', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _board(total: 150)));
    await tester.pumpAndSettle();

    expect(
      find.text('Top 1 of 150 students. Share the file for everyone.'),
      findsOneWidget,
    );
  });

  testWidgets('a level chip asks the server again for that level', (
    tester,
  ) async {
    final queries = <QuranLeaderboardQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _board();
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'BILAL'));
    await tester.pumpAndSettle();

    expect(queries.map((q) => q.level), [null, 'BILAL']);
  });

  testWidgets(
    'a period in which nobody recited says so, and cannot be shared',
    (tester) async {
      await tester.pumpWidget(_wrap((_) async => _board(students: [])));
      await tester.pumpAndSettle();

      expect(find.text('Nobody recited in this period.'), findsOneWidget);
      expect(find.byTooltip('Share'), findsNothing);
    },
  );

  testWidgets('only someone who reaches both genders chooses one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _board()));
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        (_) async => _board(),
        permissions: const ['quran-leaderboard:read:all'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap((_) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _board();
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('The leaderboard could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('Share hands the period and level to the file download', (
    tester,
  ) async {
    QuranLeaderboardQuery? shared;
    ReportFormat? format;
    await tester.pumpWidget(
      _wrap(
        (_) async => _board(),
        share: (query, f) async {
          shared = query;
          format = f;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'AMMAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(format, ReportFormat.xlsx);
    expect(shared?.level, 'AMMAR');
  });

  testWidgets('a failed download says so and leaves the list as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _board(),
        share: (_, _) async => throw Exception('no file'),
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
  });

  Future<void> typeMinimum(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('quran-minimum')), text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('a typed minimum asks the server again with it', (tester) async {
    final queries = <QuranLeaderboardQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _board();
      }),
    );
    await tester.pumpAndSettle();

    await typeMinimum(tester, '25');

    expect(queries.map((q) => q.minimum), [1, 25]);
  });

  testWidgets('a blank minimum is 1, with no error', (tester) async {
    final queries = <QuranLeaderboardQuery>[];
    await tester.pumpWidget(
      _wrap((query) async {
        queries.add(query);
        return _board();
      }),
    );
    await tester.pumpAndSettle();
    await typeMinimum(tester, '7');

    await typeMinimum(tester, '');

    expect(queries.map((q) => q.minimum), [1, 7, 1]);
    expect(find.text('The leaderboard could not be loaded.'), findsNothing);
  });

  testWidgets('Share hands the minimum to the file download', (tester) async {
    QuranLeaderboardQuery? shared;
    await tester.pumpWidget(
      _wrap((_) async => _board(), share: (query, _) async => shared = query),
    );
    await tester.pumpAndSettle();
    await typeMinimum(tester, '40');

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(shared?.minimum, 40);
  });

  testWidgets('when nobody meets the minimum it says so and stays editable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (query) async =>
            _board(students: query.minimum > 1 ? [] : const [_student]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);

    await typeMinimum(tester, '500');

    expect(
      find.text('No member has 500 or more recitations in this period.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('quran-minimum')), findsOneWidget);
    expect(find.byTooltip('Share'), findsNothing);

    await typeMinimum(tester, '1');
    expect(find.text('Ali'), findsOneWidget);
  });
}
