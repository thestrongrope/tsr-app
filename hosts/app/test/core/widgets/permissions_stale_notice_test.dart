import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/widgets/permissions_stale_notice.dart';

class _Permissions extends PermissionsNotifier {
  _Permissions({required bool stale}) {
    state = PermissionsState(
      payload: const PermissionsPayload.member(),
      stale: stale,
      error: stale ? 'offline' : null,
    );
  }

  int fetches = 0;

  @override
  Future<void> fetchAndSave() async {
    fetches++;
    state = PermissionsState(payload: state.payload);
  }
}

Future<void> _pump(WidgetTester tester, _Permissions permissions) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [permissionsProvider.overrideWith((ref) => permissions)],
      child: const MaterialApp(
        home: Scaffold(body: Column(children: [PermissionsStaleNotice()])),
      ),
    ),
  );
}

void main() {
  testWidgets('nothing is shown while the copy is confirmed', (tester) async {
    await _pump(tester, _Permissions(stale: false));

    expect(find.text(PermissionsStaleNotice.message), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a stale copy shows the notice, Retry fetches and clears it', (
    tester,
  ) async {
    final permissions = _Permissions(stale: true);
    await _pump(tester, permissions);

    expect(find.text(PermissionsStaleNotice.message), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(permissions.fetches, 1);
    expect(find.text(PermissionsStaleNotice.message), findsNothing);
  });
}
