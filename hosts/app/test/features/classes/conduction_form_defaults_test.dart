import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';

import '../../support/content_width.dart';

/// Duration presets, and which subjects a new record starts with ticked.
const int _classId = 42;

/// A ticked subject with no syllabus shows this text box, so counting the boxes
/// counts the ticked subjects.
const _hintFreeText = 'Topic covered (required)...';

Widget _wrap({required int level}) {
  return ProviderScope(
    overrides: [
      syllabusTopicsProvider(_classId).overrideWith((ref) async => const {}),
      conductionFormDataProvider(_classId).overrideWith(
        (ref) async => ConductionFormData(
          classInfo: ConductionClass(
            id: _classId,
            code: 'C1',
            name: 'Class',
            level: level,
          ),
        ),
      ),
    ],
    child: const MaterialApp(home: ConductionFormScreen(classId: _classId)),
  );
}

void main() {
  for (final size in [tabletLandscape, tabletPortrait]) {
    testWidgets('on a $size tablet the form is capped and centred', (
      tester,
    ) async {
      setWindow(tester, size);
      await tester.pumpWidget(_wrap(level: 3));
      await tester.pumpAndSettle();

      expectContentCapped(tester);
    });
  }

  testWidgets('rotating keeps what was typed and where the form is scrolled', (
    tester,
  ) async {
    setWindow(tester, tabletPortrait);
    await tester.pumpWidget(_wrap(level: 3));
    await tester.pumpAndSettle();

    final topic = find.widgetWithText(TextFormField, _hintFreeText).first;
    await tester.scrollUntilVisible(
      topic,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(topic, 'Typed before rotating');
    final scrolled = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(scrolled, greaterThan(0));

    setWindow(tester, tabletLandscape);
    await tester.pumpAndSettle();

    expect(find.text('Typed before rotating'), findsOneWidget);
    final after = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(after, closeTo(scrolled, 0.5));
  });

  testWidgets(
    'a Miqdad class starts with its four compulsory subjects ticked',
    (tester) async {
      await tester.pumpWidget(_wrap(level: 3));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Akhlaq (Ethics)'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_hintFreeText, skipOffstage: false), findsNWidgets(4));
    },
  );

  testWidgets('another level starts with every subject clear', (tester) async {
    await tester.pumpWidget(_wrap(level: 2));
    await tester.pumpAndSettle();

    expect(find.text(_hintFreeText, skipOffstage: false), findsNothing);
  });

  testWidgets('hour and minute buttons set the duration, the stepper adjusts', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(level: 2));
    await tester.pumpAndSettle();

    // The form is taller than the test screen: scroll to a button, then tap it.
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
    }

    expect(find.text('60 min'), findsOneWidget);
    // 2 hours (the Hours row), then 30 minutes (the Minutes row).
    await tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('120 min'), findsOneWidget);
    await tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('150 min'), findsOneWidget);

    // Changing the hours keeps the minutes.
    await tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(find.text('270 min'), findsOneWidget);
    await tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('210 min'), findsOneWidget);

    await tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('225 min'), findsOneWidget);
  });
}
