import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/content_width_cap.dart';

/// The width the issue asks for, written out so the tests do not follow the
/// constant they check.
const _cap = 840.0;

/// The tablet windows of #741, in logical pixels.
const tabletLandscape = Size(1280, 800);
const tabletPortrait = Size(800, 1280);

/// Sets the test window to [size] logical pixels (pixel ratio 1).
void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Asserts the screen under test caps its content: at least one
/// [ContentWidthCap] is on screen, and each is at most 840 dp wide
/// and centred in the window. Padding outside a cap may make it narrower than
/// the window, so a window wider than the cap by a padding's worth must show
/// exactly the cap.
void expectContentCapped(WidgetTester tester) {
  final caps = find.byType(ContentWidthCap);
  expect(caps, findsWidgets, reason: 'the screen has no ContentWidthCap');

  final windowWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  const padding = 64.0;

  for (final cap in caps.evaluate()) {
    final box = find.descendant(
      of: find.byElementPredicate((e) => e == cap),
      matching: find.byType(ConstrainedBox),
    );
    final rect = tester.getRect(box.first);
    expect(rect.width, lessThanOrEqualTo(_cap + 0.5));
    if (windowWidth >= _cap + padding) {
      expect(rect.width, closeTo(_cap, 0.5));
    }
    expect(rect.center.dx, closeTo(windowWidth / 2, 0.5));
  }
}
