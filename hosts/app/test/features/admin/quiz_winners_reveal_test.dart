import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/quiz_admin.dart';
import 'package:the_strong_rope/features/admin/screens/quiz_winners_reveal_screen.dart';

QuizWinner _winner(
  int prize,
  int rank,
  String name, {
  int token = 1,
  String city = 'Nowhere',
  bool known = true,
  String label = 'First',
}) => QuizWinner(
  prize: prize,
  label: label,
  rank: rank,
  token: token,
  name: name,
  city: city,
  known: known,
);

Future<void> _open(
  WidgetTester tester,
  List<QuizWinner> winners, {
  Map<String, String> colors = const {},
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: QuizWinnersRevealScreen(
        quizTitle: 'Invented Quiz',
        heading: 'Daily winners, episode 1',
        winners: winners,
        colors: colors,
      ),
    ),
  );
}

/// Taps a prize's Reveal and lets the scramble finish. The first frame of an
/// animation has no elapsed time, so it needs a pump of its own.
Future<void> _reveal(WidgetTester tester, int prize) async {
  await tester.tap(find.byKey(Key('reveal-button-$prize')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('names stay covered until Reveal, then uncover', (tester) async {
    await _open(tester, [_winner(1, 1, 'Invented One', token: 4711)]);

    expect(find.text('INVENTED QUIZ'), findsOneWidget);
    expect(find.text('Daily winners, episode 1'), findsOneWidget);
    expect(find.text('First Prize Winner'), findsOneWidget);
    expect(find.text('1'), findsOneWidget, reason: 'the rank is shown');
    expect(find.text('Invented One'), findsNothing);
    expect(find.text('4711'), findsNothing);

    await tester.tap(find.byKey(const Key('reveal-button-1')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Invented One'), findsNothing, reason: 'still scrambling');

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Invented One'), findsOneWidget);
    expect(find.text('4711'), findsOneWidget);
    expect(find.text('Nowhere'), findsOneWidget);
  });

  testWidgets('prizes are uncovered one at a time, highest prize first', (
    tester,
  ) async {
    await _open(tester, [
      _winner(1, 1, 'Invented One', label: 'First'),
      _winner(2, 1, 'Invented Two', label: 'Second', token: 2),
    ]);

    final first = tester.getTopLeft(find.text('Second Prize Winner')).dy;
    final second = tester.getTopLeft(find.text('First Prize Winner')).dy;
    expect(first, lessThan(second), reason: 'the highest prize is on top');

    await _reveal(tester, 2);
    expect(find.text('Invented Two'), findsOneWidget);
    expect(find.text('Invented One'), findsNothing, reason: 'its own button');

    await _reveal(tester, 1);
    expect(find.text('Invented One'), findsOneWidget);
  });

  testWidgets('winners of a prize show in rank order', (tester) async {
    await _open(tester, [
      _winner(1, 2, 'Invented Two', token: 2),
      _winner(1, 1, 'Invented One', token: 1),
    ]);
    await _reveal(tester, 1);

    expect(find.text('First Prize Winners'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Invented One')).dy,
      lessThan(tester.getTopLeft(find.text('Invented Two')).dy),
    );
  });

  testWidgets('a winner with no member record is still shown, as unknown', (
    tester,
  ) async {
    await _open(tester, [
      _winner(1, 1, '(unknown)', token: 9, city: '', known: false),
    ]);
    await _reveal(tester, 1);

    expect(find.text('Unknown member'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('(unknown)'), findsNothing);
  });

  testWidgets('the quiz colours paint the page, bad ones fall back', (
    tester,
  ) async {
    await _open(
      tester,
      [_winner(1, 1, 'Invented One')],
      colors: {'background': '#102030', 'heading': 'not a colour'},
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF102030));
    final heading = tester.widget<Text>(find.text('Daily winners, episode 1'));
    expect(heading.style?.color, const Color(0xFF222222));
  });

  group('parseColor', () {
    test('reads #rrggbb, rrggbb and #rgb', () {
      expect(
        QuizWinnersRevealScreen.parseColor('#ff0000'),
        const Color(0xFFFF0000),
      );
      expect(
        QuizWinnersRevealScreen.parseColor('00ff00'),
        const Color(0xFF00FF00),
      );
      expect(
        QuizWinnersRevealScreen.parseColor('#00f'),
        const Color(0xFF0000FF),
      );
    });

    test('anything else is null', () {
      expect(QuizWinnersRevealScreen.parseColor(null), isNull);
      expect(QuizWinnersRevealScreen.parseColor(''), isNull);
      expect(QuizWinnersRevealScreen.parseColor('red'), isNull);
      expect(QuizWinnersRevealScreen.parseColor('#12345'), isNull);
    });
  });
}
