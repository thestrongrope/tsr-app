import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/widgets/app_error_view.dart';

Future<void> _show(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SizedBox(height: 200, child: child)),
  ),
);

void main() {
  testWidgets('shows plain words, never the exception', (tester) async {
    await _show(tester, AppErrorView(error: StateError('secret internals')));

    expect(find.text(AppConstants.genericErrorMessage), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.text('Retry'), findsNothing, reason: 'nothing to retry');
  });

  testWidgets('a server fault does not show the server\'s body', (
    tester,
  ) async {
    await _show(
      tester,
      const AppErrorView(
        error: ApiException('<html>502 Bad Gateway</html>', 502),
      ),
    );

    expect(find.textContaining('<html>'), findsNothing);
    expect(find.textContaining('on our side'), findsOneWidget);
  });

  testWidgets('Retry appears when it can be retried, and calls back', (
    tester,
  ) async {
    var retried = 0;
    await _show(
      tester,
      AppErrorView(error: const ApiException('x', 0), onRetry: () => retried++),
    );

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('the compact form fits a short strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 110,
            child: AppErrorView(
              error: const ApiException('x', 0),
              compact: true,
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.text('Retry'), findsOneWidget);
  });
}
