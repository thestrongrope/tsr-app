import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/this_week_card.dart';
import 'package:the_strong_rope/features/reports/models/this_week.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';

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

ThisWeek _week(int flagged) => ThisWeek(
  gender: 1,
  weekFrom: '2026-10-11',
  weekTo: '2026-10-17',
  summary: ThisWeekSummary(
    met: 3,
    total: 4,
    formsMissing: 0,
    attendance: 0.6,
    flagged: flagged,
  ),
  cform: const [],
  conduction: const [],
  attendance: const [],
  alignment: const [],
);

Widget _wrap({
  List<String> permissions = const ['reports:read:gender'],
  Future<ThisWeek> Function(int?)? load,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      thisWeekProvider.overrideWith(
        (ref, gender) => (load ?? (_) async => _week(3))(gender),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: ThisWeekCard()),
          ),
          GoRoute(
            path: AppRoutes.adminThisWeek,
            builder: (_, _) => const Scaffold(body: Text('This week screen')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a coordinator sees how many classes need attention', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('This week: 3 classes need attention'), findsOneWidget);
  });

  testWidgets('one class reads as singular and none as all clear', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(load: (_) async => _week(1)));
    await tester.pumpAndSettle();
    expect(find.text('This week: 1 class needs attention'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(load: (_) async => _week(0)));
    await tester.pumpAndSettle();
    expect(find.text('This week: all clear'), findsOneWidget);
  });

  testWidgets('tapping the card opens the This week screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('This week: 3 classes need attention'));
    await tester.pumpAndSettle();

    expect(find.text('This week screen'), findsOneWidget);
  });

  testWidgets('someone without reports:read sees nothing and loads nothing', (
    tester,
  ) async {
    var loaded = false;
    await tester.pumpWidget(
      _wrap(
        permissions: const ['notifications:send:all'],
        load: (_) async {
          loaded = true;
          return _week(3);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('This week'), findsNothing);
    expect(loaded, isFalse);
  });

  testWidgets('a review that cannot load shows no card', (tester) async {
    await tester.pumpWidget(_wrap(load: (_) async => throw Exception('boom')));
    await tester.pumpAndSettle();

    expect(find.textContaining('This week'), findsNothing);
  });
}
