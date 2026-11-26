import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/widgets.dart';

Widget _host({required bool disableAnimations, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('renders a box of the requested size', (tester) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: const SkeletonBox(width: 120, height: 40),
      ),
    );

    expect(tester.getSize(find.byType(SkeletonBox)), const Size(120, 40));
    expect(find.byType(FadeTransition), findsWidgets);
  });

  testWidgets('does not pulse when animations are disabled', (tester) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        child: const SkeletonBox(width: 120, height: 40),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    // Nothing is scheduled, so this returns instead of timing out.
    await tester.pumpAndSettle();
  });

  testWidgets('fits a small box without overflow', (tester) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: const SizedBox(width: 20, height: 10, child: SkeletonBox()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
