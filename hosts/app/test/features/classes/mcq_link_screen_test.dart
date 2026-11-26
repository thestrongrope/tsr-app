import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/classes/screens/mcq_link_screen.dart';

/// The MCQ link screen (#860, #863): opens the MCQ, shows the result of one
/// already attempted, or says why it cannot be opened and lists what can.
void main() {
  const openItems = [
    McqOpenItem(id: 7, name: 'Wudu basics', topic: 'Fiqh', classCode: 'AYD1'),
  ];

  Future<GoRouter> pump(
    WidgetTester tester, {
    required McqLinkResolution link,
    List<McqOpenItem> open = const [],
    bool openFails = false,
  }) async {
    final router = GoRouter(
      initialLocation: '/mcq/AbCd1234',
      routes: [
        GoRoute(
          path: '/mcq/:code',
          builder: (_, state) =>
              McqLinkScreen(code: state.pathParameters['code']!),
        ),
        GoRoute(
          path: '/quizzes/:id',
          builder: (_, state) =>
              Text('questions ${state.pathParameters['id']}'),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, state) =>
                  Text('result ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcqLinkResolutionProvider('AbCd1234').overrideWith((_) async => link),
          mcqOpenListProvider.overrideWith((_) async {
            if (openFails) throw Exception('offline');
            return open;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a failed MCQ list shows an error with Retry, not nothing', (
    tester,
  ) async {
    await pump(
      tester,
      link: const McqLinkResolution(state: 'closed'),
      openFails: true,
    );
    expect(find.text('This MCQ is closed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('There are no MCQs for you to attempt right now.'),
      findsNothing,
    );
  });

  testWidgets('open: shows the MCQ questions', (tester) async {
    await pump(tester, link: const McqLinkResolution(state: 'open', quizId: 5));
    expect(find.text('questions 5'), findsOneWidget);
  });

  testWidgets('attempted: shows the result, not the questions', (tester) async {
    await pump(
      tester,
      link: const McqLinkResolution(state: 'attempted', quizId: 5),
    );
    expect(find.text('result 5'), findsOneWidget);
    expect(find.text('questions 5'), findsNothing);
  });

  for (final entry in {
    'closed': 'This MCQ is closed.',
    'not_released': 'This MCQ has not been released yet.',
    'not_eligible':
        'You are not in the class this MCQ is for, so you cannot open it.',
    'not_found': 'We could not find this MCQ. The link may be wrong.',
  }.entries) {
    testWidgets('${entry.key}: says so and lists what can be attempted', (
      tester,
    ) async {
      await pump(
        tester,
        link: McqLinkResolution(state: entry.key),
        open: openItems,
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('MCQs you can attempt now'), findsOneWidget);
      expect(find.text('Wudu basics'), findsOneWidget);
      expect(find.textContaining('questions'), findsNothing);
    });
  }

  testWidgets('tapping a listed MCQ opens it', (tester) async {
    await pump(
      tester,
      link: const McqLinkResolution(state: 'closed'),
      open: openItems,
    );
    await tester.tap(find.text('Wudu basics'));
    await tester.pumpAndSettle();
    expect(find.text('questions 7'), findsOneWidget);
  });

  testWidgets('nothing to attempt: says there are none, no empty list', (
    tester,
  ) async {
    await pump(tester, link: const McqLinkResolution(state: 'closed'));
    expect(
      find.text('There are no MCQs for you to attempt right now.'),
      findsOneWidget,
    );
    expect(find.text('MCQs you can attempt now'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('open without an id is treated as not found', (tester) async {
    await pump(tester, link: const McqLinkResolution(state: 'open'));
    expect(
      find.text('We could not find this MCQ. The link may be wrong.'),
      findsOneWidget,
    );
  });
}
