import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/version/update_required_screen.dart';

/// The screen a blocked user sees.
///
/// Two things are worth asserting and neither is the wording: that it cannot be
/// escaped, and that it degrades sensibly when the server gave it nothing to
/// link to.
Widget _wrap(String storeUrl) {
  return MaterialApp(home: UpdateRequiredScreen(storeUrl: storeUrl));
}

void main() {
  testWidgets('states what happened and what to do', (tester) async {
    await tester.pumpWidget(_wrap('https://example.invalid/app'));

    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('no longer supported'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Update'), findsOneWidget);
  });

  testWidgets('offers no way past it', (tester) async {
    // A gate with a way round it is not a gate. No AppBar means no automatic
    // back button, and canPop: false stops the system back gesture.
    await tester.pumpWidget(_wrap('https://example.invalid/app'));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });

  testWidgets('hides the button when the server sent no store link', (
    tester,
  ) async {
    // A button that visibly does nothing is worse than no button; the message
    // still says what to do.
    await tester.pumpWidget(_wrap(''));

    expect(find.text('Update required'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Update'), findsNothing);
  });
}
