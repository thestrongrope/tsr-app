import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/profile/widgets/danger_zone.dart';

Widget _wrap({required VoidCallback onDelete}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: DangerZone(onDelete: onDelete)),
    ),
  );
}

void main() {
  testWidgets('names the section and keeps the deletion route findable', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(onDelete: () {}));

    // App Store Review Guideline 5.1.1(v) requires deletion to be initiated
    // in-app, so a reviewer has to be able to find this without hunting.
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
  });

  testWidgets('says nothing is deleted before the confirmation screen', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(onDelete: () {}));

    // The control routes to a screen with its own confirmation; it does not
    // delete anything itself. Saying so is what makes it safe to give the
    // section visual weight.
    expect(find.textContaining('confirm'), findsOneWidget);
  });

  testWidgets('invokes the callback when the control is tapped', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(_wrap(onDelete: () => tapped++));

    await tester.tap(find.text('Delete my account'));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('does not underline the label', (tester) async {
    await tester.pumpWidget(_wrap(onDelete: () {}));

    // An underline is what made the old bare link read as unstyled markup
    // rather than a deliberate choice.
    final label = tester.widget<Text>(find.text('Delete my account'));
    expect(label.style?.decoration, isNot(TextDecoration.underline));
  });
}
