import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/reports/screens/reports_screen.dart';
import 'package:the_strong_rope/features/reports/widgets/report_search.dart';

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

Widget _app({List<String> permissions = const ['reports:read:gender']}) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        permissionsProvider.overrideWith(
          (ref) => _FixedPermissions(permissions),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const ReportsScreen()),
            for (final path in [
              AppRoutes.adminConductionReport,
              AppRoutes.adminWeeklyReport,
              AppRoutes.adminSummaryReport,
            ])
              GoRoute(path: path, builder: (_, _) => Text('opened $path')),
          ],
        ),
      ),
    );

void main() {
  group('matchesSearch', () {
    test('an empty or blank query matches everything', () {
      expect(matchesSearch('', ['A1']), isTrue);
      expect(matchesSearch('   ', ['A1']), isTrue);
    });

    test('matches any field, ignoring case and surrounding spaces', () {
      expect(matchesSearch(' ammar ', ['A1', 'Teacher AMMAR']), isTrue);
      expect(matchesSearch('zzz', ['A1', 'Teacher']), isFalse);
    });
  });

  testWidgets('lists every report with its description', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Conduction Report'), findsOneWidget);
    expect(find.text('Weekly Report'), findsOneWidget);
    expect(find.text('Class Summary'), findsOneWidget);
    expect(find.text('How each class did over a period'), findsOneWidget);
  });

  testWidgets('the Quran leaderboard shows only to someone who may read it', (
    tester,
  ) async {
    // Tall enough that the list builds every entry.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Quran Leaderboard'), findsNothing);

    await tester.pumpWidget(
      _app(
        permissions: const [
          'reports:read:gender',
          'quran-leaderboard:read:gender',
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quran Leaderboard'), findsOneWidget);
  });

  testWidgets('Registrations shows only to someone who may read them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Registrations'), findsNothing);

    await tester.pumpWidget(
      _app(
        permissions: const ['reports:read:gender', 'registrations:read:gender'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registrations'), findsOneWidget);
  });

  testWidgets('searching narrows the list by name or description', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'summary');
    await tester.pumpAndSettle();
    expect(find.text('Class Summary'), findsOneWidget);
    expect(find.text('Weekly Report'), findsNothing);

    // "met" is only in the weekly report's description.
    await tester.enterText(find.byType(TextField), 'met');
    await tester.pumpAndSettle();
    expect(find.text('Weekly Report'), findsOneWidget);
    expect(find.text('Class Summary'), findsNothing);
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'payroll');
    await tester.pumpAndSettle();

    expect(find.text('No reports match your search.'), findsOneWidget);
    expect(find.text('Conduction Report'), findsNothing);
  });

  testWidgets('tapping a report opens it', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weekly Report'));
    await tester.pumpAndSettle();

    expect(find.text('opened ${AppRoutes.adminWeeklyReport}'), findsOneWidget);
  });
}
