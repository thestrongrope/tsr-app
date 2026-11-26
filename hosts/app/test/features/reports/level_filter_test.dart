import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/widgets/level_filter.dart';

void main() {
  testWidgets('offers All and each level, and reports the choice', (
    tester,
  ) async {
    String? picked = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelFilter(
            levels: const ['AMMAR', 'BILAL'],
            selected: null,
            onChanged: (level) => picked = level,
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    await tester.tap(find.text('BILAL'));
    expect(picked, 'BILAL');
    await tester.tap(find.text('All'));
    expect(picked, isNull);
  });
}
