import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/wordpress/models/publication.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/screens/publications_list_screen.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// Answers getPublications() from [answers], one per call; the last repeats.
class _FakeService extends TsrWebService {
  _FakeService(this.answers);

  final List<Future<List<Publication>> Function()> answers;
  int calls = 0;

  @override
  Future<List<Publication>> getPublications() {
    final i = calls < answers.length ? calls : answers.length - 1;
    calls++;
    return answers[i]();
  }
}

const _gift = Publication(
  title: 'A Gift for the Youth',
  summary: 'Focuses on early marriage.',
  type: 'PDF',
  size: '7.2 MB',
  updated: 'Feb 15, 2026',
  language: 'English',
  file: 'https://thestrongrope.com/downloads/books/gift.pdf',
  readOnlineUrl: 'https://thestrongrope.com/a-gift-for-the-youth',
);
const _hindi = Publication(
  title: 'Quraane Karim',
  type: 'PDF',
  size: '—',
  updated: 'Apr 06, 2024',
  language: 'Hindi',
  file: 'https://thestrongrope.com/downloads/hindi.pdf',
);
const _dua = Publication(
  title: 'Dua Faakshif',
  language: 'Multilingual',
  readOnlineUrl: 'https://thestrongrope.com/duas/dua-faakshif.html',
);

Future<_FakeService> _pump(
  WidgetTester tester,
  List<Future<List<Publication>> Function()> answers, {
  OpenUrl? openUrl,
}) async {
  final service = _FakeService(answers);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tsrWebServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: openUrl == null
            ? const PublicationsListScreen()
            : PublicationsListScreen(openUrl: openUrl),
      ),
    ),
  );
  return service;
}

void main() {
  testWidgets('shows that it is loading while the list loads', (tester) async {
    final never = Completer<List<Publication>>();
    await _pump(tester, [() => never.future]);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed load says so and offers Retry, not an empty list', (
    tester,
  ) async {
    final service = await _pump(tester, [
      () async => throw Exception('offline'),
      () async => [_gift],
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Could not load publications'), findsOneWidget);
    expect(find.text('No publications yet.'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(find.text('A Gift for the Youth'), findsOneWidget);
  });

  testWidgets('a failed pull-to-refresh shows the error, without an uncaught '
      'one', (tester) async {
    await _pump(tester, [
      () async => [_hindi],
      () async => throw Exception('offline'),
    ]);
    await tester.pumpAndSettle();

    // One short card: the pull must still reach the RefreshIndicator.
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Could not load publications'), findsOneWidget);
  });

  testWidgets('offers All plus the languages present, English first', (
    tester,
  ) async {
    await _pump(tester, [
      () async => [_dua, _hindi, _gift],
    ]);
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((c) => (c.label as Text).data)
        .toList();
    expect(labels, ['All', 'English', 'Hindi', 'Multilingual']);
  });

  testWidgets('choosing a language shows only it; All shows every one', (
    tester,
  ) async {
    await _pump(tester, [
      () async => [_gift, _hindi, _dua],
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hindi'));
    await tester.pumpAndSettle();
    expect(find.text('Quraane Karim'), findsOneWidget);
    expect(find.text('A Gift for the Youth'), findsNothing);
    expect(find.text('Dua Faakshif'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Quraane Karim'), findsOneWidget);
    expect(find.text('A Gift for the Youth'), findsOneWidget);
    expect(find.text('Dua Faakshif'), findsOneWidget);
  });

  testWidgets('shows summary and details, hiding an unknown size', (
    tester,
  ) async {
    await _pump(tester, [
      () async => [_gift, _hindi],
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Focuses on early marriage.'), findsOneWidget);
    expect(
      find.text('English · PDF · 7.2 MB · Updated Feb 15, 2026'),
      findsOneWidget,
    );
    expect(find.text('Hindi · PDF · Updated Apr 06, 2024'), findsOneWidget);
  });

  testWidgets('search matches title or summary, ignoring case', (tester) async {
    await _pump(tester, [
      () async => [_gift, _hindi, _dua],
    ]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'faakshif');
    await tester.pumpAndSettle();
    expect(find.text('Dua Faakshif'), findsOneWidget);
    expect(find.text('A Gift for the Youth'), findsNothing);
    expect(find.text('Quraane Karim'), findsNothing);

    // Only _gift's summary mentions marriage.
    await tester.enterText(find.byType(TextField), 'MARRIAGE');
    await tester.pumpAndSettle();
    expect(find.text('A Gift for the Youth'), findsOneWidget);
    expect(find.text('Dua Faakshif'), findsNothing);
  });

  testWidgets('search narrows within the chosen language', (tester) async {
    await _pump(tester, [
      () async => [_gift, _hindi, _dua],
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hindi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gift');
    await tester.pumpAndSettle();

    expect(
      find.text('A Gift for the Youth'),
      findsNothing,
      reason: 'an English match must stay hidden while Hindi is chosen',
    );
    expect(find.text('No publications match your search.'), findsOneWidget);
  });

  testWidgets('clearing the search shows every publication again', (
    tester,
  ) async {
    await _pump(tester, [
      () async => [_gift, _hindi, _dua],
    ]);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No publications match your search.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('A Gift for the Youth'), findsOneWidget);
    expect(find.text('Quraane Karim'), findsOneWidget);
    expect(find.text('Dua Faakshif'), findsOneWidget);
  });

  testWidgets('each card has a cover saying what a tap opens', (tester) async {
    await _pump(tester, [
      () async => [_gift, _hindi, _dua],
    ]);
    await tester.pumpAndSettle();

    // _gift and _dua open a reading page; _hindi opens its PDF.
    expect(find.text('READ'), findsNWidgets(2));
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('a tap opens the reading page; the file is a second action', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      [
        () async => [_gift, _hindi, _dua],
      ],
      openUrl: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.pumpAndSettle();

    // Only the item with both a reading page and a file gets the second action.
    expect(find.text('Open PDF'), findsOneWidget);

    await tester.tap(find.text('A Gift for the Youth'));
    await tester.tap(find.text('Open PDF'));
    await tester.tap(find.text('Quraane Karim'));
    await tester.pumpAndSettle();

    expect(opened.map((u) => u.toString()), [
      'https://thestrongrope.com/a-gift-for-the-youth',
      'https://thestrongrope.com/downloads/books/gift.pdf',
      'https://thestrongrope.com/downloads/hindi.pdf',
    ]);
  });

  testWidgets('a publication that cannot be opened says so', (tester) async {
    await _pump(
      tester,
      [
        () async => [_hindi, _dua],
      ],
      openUrl: (uri) async =>
          uri.path.endsWith('.pdf') ? false : throw Exception('no handler'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quraane Karim'));
    await tester.pump();
    expect(find.text('Could not open this publication.'), findsOneWidget);

    ScaffoldMessenger.of(
      tester.element(find.byType(ListView)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dua Faakshif'));
    await tester.pump();
    expect(find.text('Could not open this publication.'), findsOneWidget);
  });
}
