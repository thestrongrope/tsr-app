import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/widgets/widgets.dart';

void main() {
  testWidgets('a section title is a heading and wraps at 1.3x text', (
    tester,
  ) async {
    const title = 'A rather long section name that needs two lines to read';
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: SizedBox(
              width: 260,
              child: AppSectionHeader(
                title: title,
                actionLabel: 'View all',
                onAction: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.text(title));
    expect(semantics.flagsCollection.isHeader, isTrue);
    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, 2);
    expect(tester.takeException(), isNull);
  });
}
