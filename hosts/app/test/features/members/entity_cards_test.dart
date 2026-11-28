import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/members/models/entity_cards.dart';
import 'package:the_strong_rope/features/members/providers/members_provider.dart';
import 'package:the_strong_rope/features/members/screens/student_card_screen.dart';
import 'package:the_strong_rope/features/members/screens/subscriber_card_screen.dart';

// `GET /students/{token}` and `GET /subscribers/{token}` (#557), as the server
// sends them: no contact details on either.

const _student = {
  'token': 101,
  'name': 'Student One',
  'gender': 1,
  'classes': [
    {'id': 1, 'code': 'AYD1', 'level': 'AMMAR'},
    {'id': 4, 'code': 'AYD2', 'level': 'BILAL'},
  ],
};

const _subscriber = {
  'token': 103,
  'name': 'Sub Scriber',
  'gender': 2,
  'registeredOn': '2026-10-05',
  'requestedClass': 'AYD2',
};

Widget _wrap(Widget screen, {List<Override> overrides = const []}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(
            path: '/classes/:classId/dashboard',
            builder: (_, state) => Scaffold(
              body: Text('class ${state.pathParameters['classId']}'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('models', () {
    test('a student parses with its classes', () {
      final card = StudentCard.fromJson(_student);

      expect(card.token, 101);
      expect(card.name, 'Student One');
      expect(card.gender, 1);
      expect(card.classes.map((c) => c.code), ['AYD1', 'AYD2']);
      expect(card.classes.last.id, 4);
    });

    test('a subscriber parses, with the optional fields absent', () {
      final card = SubscriberCard.fromJson(_subscriber);
      expect(card.registeredOn, '2026-10-05');
      expect(card.requestedClass, 'AYD2');

      final bare = SubscriberCard.fromJson({
        'token': 103,
        'name': 'Sub Scriber',
        'gender': null,
        'registeredOn': null,
        'requestedClass': null,
      });
      expect(bare.gender, isNull);
      expect(bare.registeredOn, isNull);
      expect(bare.requestedClass, isNull);
    });

    test('a body that is not a card throws so the screen can retry', () {
      expect(() => StudentCard.fromJson('nope'), throwsFormatException);
      expect(() => StudentCard.fromJson({'token': 1}), throwsFormatException);
      expect(() => SubscriberCard.fromJson([]), throwsFormatException);
    });
  });

  group('student card', () {
    testWidgets('lists the classes and opens one', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StudentCardScreen(token: 101),
          overrides: [
            studentCardProvider.overrideWith(
              (ref, token) async => StudentCard.fromJson(_student),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student One'), findsWidgets);
      expect(find.text('AYD1'), findsOneWidget);
      expect(find.text('AYD2'), findsOneWidget);

      await tester.tap(find.text('AYD2'));
      await tester.pumpAndSettle();

      expect(find.text('class 4'), findsOneWidget);
    });

    testWidgets(
      'a 404 says the person could not be found and offers no retry',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const StudentCardScreen(token: 101),
            overrides: [
              studentCardProvider.overrideWith(
                (ref, token) async =>
                    throw ApiException('Person not found', 404),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('This person could not be found.'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
      },
    );

    testWidgets('any other error offers a retry', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          const StudentCardScreen(token: 101),
          overrides: [
            studentCardProvider.overrideWith((ref, token) async {
              calls++;
              if (calls == 1) throw Exception('boom');
              return StudentCard.fromJson(_student);
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The card could not be loaded.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('AYD1'), findsOneWidget);
    });
  });

  group('subscriber card', () {
    testWidgets('shows when they registered and the class they asked for', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SubscriberCardScreen(token: 103),
          overrides: [
            subscriberCardProvider.overrideWith(
              (ref, token) async => SubscriberCard.fromJson(_subscriber),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sub Scriber'), findsWidgets);
      expect(find.text('Registered 2026-10-05'), findsOneWidget);
      expect(find.text('Asked for class AYD2'), findsOneWidget);
    });

    testWidgets('no requested class and no date show neither line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SubscriberCardScreen(token: 103),
          overrides: [
            subscriberCardProvider.overrideWith(
              (ref, token) async => SubscriberCard.fromJson({
                'token': 103,
                'name': 'Sub Scriber',
                'gender': 2,
                'registeredOn': null,
                'requestedClass': null,
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Registered'), findsNothing);
      expect(find.textContaining('Asked for'), findsNothing);
    });

    testWidgets('a 404 says the person could not be found', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SubscriberCardScreen(token: 103),
          overrides: [
            subscriberCardProvider.overrideWith(
              (ref, token) async => throw ApiException('Person not found', 404),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This person could not be found.'), findsOneWidget);
    });
  });

  group('routes', () {
    test('the card paths carry the token and need a signed-in user', () {
      expect(AppRoutes.studentCardPath(101), '/students/101');
      expect(AppRoutes.subscriberCardPath(103), '/subscribers/103');
      expect(AppRoutes.isPublicRoute('/students/101'), isFalse);
      expect(AppRoutes.isPublicRoute('/subscribers/103'), isFalse);
    });
  });
}
