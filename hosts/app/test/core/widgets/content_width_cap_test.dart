import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/content_width_cap.dart';

import '../../support/content_width.dart';

void main() {
  for (final width in [600.0, 840.0, 1200.0]) {
    testWidgets('content fills up to 840 dp in a $width dp window', (
      tester,
    ) async {
      setWindow(tester, Size(width, 800));
      const contentKey = Key('content');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContentWidthCap(
              child: SizedBox(
                key: contentKey,
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(contentKey));
      expect(rect.width, width > 840 ? 840 : width);
      expect(rect.center.dx, width / 2);
      expect(rect.top, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
