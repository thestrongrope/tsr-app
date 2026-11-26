import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/access_log.dart';
import 'package:the_strong_rope/features/admin/providers/access_log_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/access_log_repository.dart';
import 'package:the_strong_rope/features/admin/screens/access_log_screen.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart'
    show ReportFormat;

const _ali = AccessLogUser(
  token: 100,
  name: 'Ali Raza',
  email: 'ali@example.test',
  hits: 30,
  activeDays: 12,
  lastAccessed: '2026-10-06 11:00:00',
);
const _zayd = AccessLogUser(
  token: 200,
  name: 'Zayd Khan',
  email: 'zayd@example.test',
  hits: 5,
  activeDays: 2,
  lastAccessed: '2026-10-08 09:00:00',
);
const _classes = AccessLogPage(
  page: 'manage_classes.php',
  hits: 25,
  lastAccessed: '2026-10-06 11:00:00',
);
const _donors = AccessLogPage(
  page: 'donors.php',
  hits: 10,
  lastAccessed: '2026-10-08 09:00:00',
);
const _entry = AccessLogEntry(
  id: 9,
  accessedAt: '2026-10-08 09:00:00',
  token: 200,
  name: 'Zayd Khan',
  email: 'zayd@example.test',
  role: 'Ladies admin',
  method: 'POST',
  page: 'donors.php',
  ip: '10.0.0.1',
);

const _full = AccessLog(
  users: [_zayd, _ali], // the server's order is not the screen's
  pages: [_donors, _classes],
  recent: [_entry],
);
const _none = AccessLog(users: [], pages: [], recent: []);

class _FakeRepository extends AccessLogRepository {
  _FakeRepository(this.answer);

  /// What each load returns, given its filter: a log, or an Exception to throw.
  Object Function(AccessLogFilter) answer;
  final loads = <AccessLogFilter>[];

  @override
  Future<AccessLog> getAccessLog(AccessLogFilter filter) async {
    loads.add(filter);
    final next = answer(filter);
    if (next is Exception) throw next;
    return next as AccessLog;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repo, {
  ShareAccessLog? share,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        accessLogRepositoryProvider.overrideWithValue(repo),
        if (share != null) shareAccessLogProvider.overrideWithValue(share),
      ],
      child: const MaterialApp(home: AccessLogScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The vertical order of the given texts on screen.
List<String> _order(WidgetTester tester, List<String> texts) {
  final tops = {for (final t in texts) t: tester.getTopLeft(find.text(t)).dy};
  return (tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!)));
}

void main() {
  group('models', () {
    test('AccessLog reads the three lists', () {
      final log = AccessLog.fromJson({
        'users': [
          {
            'token': 100,
            'name': 'Ali Raza',
            'email': 'ali@example.test',
            'hits': 30,
            'activeDays': 12,
            'lastAccessed': '2026-10-06 11:00:00',
          },
        ],
        'pages': [
          {
            'page': 'donors.php',
            'hits': 10,
            'lastAccessed': '2026-10-08 09:00:00',
          },
        ],
        'recent': [
          {
            'id': 9,
            'accessedAt': '2026-10-08 09:00:00',
            'token': 200,
            'name': null,
            'email': null,
            'role': 'Ladies admin',
            'method': 'POST',
            'page': 'donors.php',
            'ip': null,
          },
        ],
      });

      expect(log.users.single.activeDays, 12);
      expect(log.pages.single.page, 'donors.php');
      expect(log.recent.single.role, 'Ladies admin');
      expect(log.recent.single.name, '', reason: 'a gone user has no name');
      expect(log.recent.single.ip, '');
    });

    test(
      'a filter is a value: the same member and page are the same filter',
      () {
        expect(
          const AccessLogFilter(token: 1, page: 'a'),
          const AccessLogFilter(token: 1, page: 'a'),
        );
        expect(
          const AccessLogFilter(token: 1).hashCode,
          const AccessLogFilter(token: 1).hashCode,
        );
        expect(const AccessLogFilter(token: 1), isNot(const AccessLogFilter()));
        expect(const AccessLogFilter().isEmpty, isTrue);
        expect(const AccessLogFilter(page: 'x').isEmpty, isFalse);
      },
    );
  });

  group('AccessLogScreen', () {
    testWidgets('People are listed, most hits first, with their details', (
      tester,
    ) async {
      await _pump(tester, _FakeRepository((_) => _full));

      expect(_order(tester, ['Ali Raza', 'Zayd Khan']), [
        'Ali Raza',
        'Zayd Khan',
      ]);
      expect(find.textContaining('ali@example.test'), findsOneWidget);
      expect(find.textContaining('30 hits'), findsOneWidget);
      expect(find.textContaining('12 days'), findsOneWidget);
      expect(find.textContaining('2026-10-06 11:00:00'), findsOneWidget);
    });

    testWidgets('each list can be sorted', (tester) async {
      await _pump(tester, _FakeRepository((_) => _full));

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latest access'));
      await tester.pumpAndSettle();
      expect(_order(tester, ['Ali Raza', 'Zayd Khan']), [
        'Zayd Khan',
        'Ali Raza',
      ]);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name A–Z'));
      await tester.pumpAndSettle();
      expect(_order(tester, ['Ali Raza', 'Zayd Khan']), [
        'Ali Raza',
        'Zayd Khan',
      ]);

      await tester.tap(find.text('Pages'));
      await tester.pumpAndSettle();
      expect(_order(tester, ['donors.php', 'manage_classes.php']), [
        'manage_classes.php',
        'donors.php',
      ], reason: 'most hits first');
      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page A–Z'));
      await tester.pumpAndSettle();
      expect(_order(tester, ['donors.php', 'manage_classes.php']), [
        'donors.php',
        'manage_classes.php',
      ]);
    });

    testWidgets('Recent shows time, person, role, method, page and address', (
      tester,
    ) async {
      await _pump(tester, _FakeRepository((_) => _full));

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(find.text('donors.php'), findsOneWidget);
      expect(find.textContaining('Zayd Khan'), findsOneWidget);
      expect(find.textContaining('Ladies admin'), findsOneWidget);
      expect(find.textContaining('POST'), findsOneWidget);
      expect(find.textContaining('10.0.0.1'), findsOneWidget);
      expect(find.textContaining('2026-10-08 09:00:00'), findsOneWidget);
    });

    testWidgets('Recent is newest first and can be turned around', (
      tester,
    ) async {
      const older = AccessLogEntry(
        id: 3,
        accessedAt: '2026-10-01 08:00:00',
        token: 100,
        name: 'Ali Raza',
        email: 'ali@example.test',
        role: 'Admin',
        method: 'GET',
        page: 'older_page.php',
        ip: '10.0.0.2',
      );
      await _pump(
        tester,
        _FakeRepository(
          (_) => const AccessLog(
            users: [_ali],
            pages: [_donors],
            recent: [older, _entry],
          ),
        ),
      );
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      expect(_order(tester, ['donors.php', 'older_page.php']), [
        'donors.php',
        'older_page.php',
      ]);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest first'));
      await tester.pumpAndSettle();

      expect(_order(tester, ['donors.php', 'older_page.php']), [
        'older_page.php',
        'donors.php',
      ]);
    });

    testWidgets('tapping a person filters every list by that member', (
      tester,
    ) async {
      final repo = _FakeRepository((_) => _full);
      await _pump(tester, repo);

      await tester.tap(find.text('Zayd Khan'));
      await tester.pumpAndSettle();

      expect(repo.loads.last, const AccessLogFilter(token: 200));
      expect(find.byType(InputChip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(InputChip),
          matching: find.text('Zayd Khan'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Remove member filter'));
      await tester.pumpAndSettle();

      expect(repo.loads.last, const AccessLogFilter());
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets(
      'the page filter narrows by part of a page name, and tapping a page fills it',
      (tester) async {
        final repo = _FakeRepository((_) => _full);
        await _pump(tester, repo);

        await tester.enterText(find.byType(TextField), 'class');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repo.loads.last, const AccessLogFilter(page: 'class'));

        await tester.tap(find.text('Pages'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('donors.php'));
        await tester.pumpAndSettle();

        expect(repo.loads.last, const AccessLogFilter(page: 'donors.php'));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'donors.php',
        );
      },
    );

    testWidgets('no matching accesses says so and offers no file', (
      tester,
    ) async {
      await _pump(tester, _FakeRepository((_) => _none));

      expect(find.text('No accesses match.'), findsOneWidget);
      expect(find.byTooltip('Share'), findsNothing);
    });

    testWidgets(
      'a failed load says so, shows no lists, and Retry loads again',
      (tester) async {
        var calls = 0;
        final repo = _FakeRepository((_) {
          calls++;
          return calls == 1 ? Exception('offline') : _full;
        });
        await _pump(tester, repo);

        expect(find.text("Couldn't load the access log."), findsOneWidget);
        expect(find.text('Ali Raza'), findsNothing);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Ali Raza'), findsOneWidget);
      },
    );

    testWidgets(
      'Share hands the chosen format and the current filter to the file download',
      (tester) async {
        final shared = <(ReportFormat, AccessLogFilter)>[];
        await _pump(
          tester,
          _FakeRepository((_) => _full),
          share: (format, filter) async => shared.add((format, filter)),
        );
        await tester.tap(find.text('Zayd Khan'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Share'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Share as Excel'));
        await tester.pumpAndSettle();

        expect(shared, [
          (ReportFormat.xlsx, const AccessLogFilter(token: 200)),
        ]);
      },
    );

    testWidgets('a file that cannot be prepared says so and keeps the lists', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeRepository((_) => _full),
        share: (_, _) async => throw Exception('offline'),
      );

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share as PDF'));
      await tester.pumpAndSettle();

      expect(
        find.text('The file could not be prepared. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Ali Raza'), findsOneWidget);
    });
  });
}
