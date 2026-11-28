import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/classes/models/class_create.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/providers/class_create_provider.dart';
import 'package:the_strong_rope/features/classes/screens/create_class_screen.dart';

CreateClassOptions _options(List<int> genders) => CreateClassOptions(
  genders: genders,
  tags: const [ManageOption(id: 3, name: 'Kids')],
  timezones: const [ManageTimezone(timezone: 'Asia/Kolkata', label: 'India')],
);

const _levels = [ManageOption(id: 2, name: 'Ammar')];

/// Every call the screen made to create a class, in order.
class _Calls {
  final List<Map<String, Object?>> made = [];
}

Widget _wrap({
  List<int> genders = const [1],
  CreateClass? create,
  _Calls? calls,
  Object? optionsError,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      createClassOptionsProvider.overrideWith(
        (ref) => optionsError != null
            ? Future<CreateClassOptions>.error(optionsError)
            : Future.value(_options(genders)),
      ),
      classLevelsProvider.overrideWith((ref) async => _levels),
      searchNewClassTeachersProvider.overrideWithValue(
        (gender, query) async => const [ManageOption(id: 1234, name: 'Ali')],
      ),
      createClassProvider.overrideWithValue(
        create ??
            ({
              required gender,
              required levelId,
              required location,
              required city,
              required country,
              required teacher,
              required tags,
              required schedules,
            }) async {
              calls?.made.add({
                'gender': gender,
                'levelId': levelId,
                'location': location,
                'city': city,
                'country': country,
                'teacher': teacher,
                'tags': tags,
                'slots': schedules.length,
              });
              return 88;
            },
      ),
    ],
    child: const MaterialApp(home: CreateClassScreen()),
  );
}

Finder get _createButton => find.widgetWithText(FilledButton, 'Create class');
Finder get _creatingButton => find.widgetWithText(FilledButton, 'Creating…');

/// A tall screen, so the whole lazily built form is on it.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _fillIn(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ammar').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Location'), 'Hall');
  await tester.enterText(find.widgetWithText(TextField, 'City'), 'Mumbai');
  await tester.enterText(find.widgetWithText(TextField, 'Country'), 'India');
  await tester.tap(find.text('Teacher'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Name or token'), 'al');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ali'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kids'));
  await tester.tap(find.text('Add a day'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a caller who may create for one gender is not asked', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(genders: [2]));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('Choose a gender first'), findsNothing);
  });

  testWidgets('a caller who may create for both chooses a gender', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(genders: [1, 2]));
    await tester.pumpAndSettle();

    expect(find.text('Gents'), findsOneWidget);
    expect(find.text('Ladies'), findsOneWidget);
    expect(find.text('Choose a gender first'), findsOneWidget);
  });

  testWidgets('Create stays disabled until every answer is given', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_createButton).onPressed, isNull);

    await _fillIn(tester);
    expect(tester.widget<FilledButton>(_createButton).onPressed, isNotNull);
  });

  testWidgets('it sends what was chosen and hands back the new class id', (
    tester,
  ) async {
    _tall(tester);
    final calls = _Calls();
    int? popped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          createClassOptionsProvider.overrideWith((ref) async => _options([1])),
          classLevelsProvider.overrideWith((ref) async => _levels),
          searchNewClassTeachersProvider.overrideWithValue(
            (g, q) async => const [ManageOption(id: 1234, name: 'Ali')],
          ),
          createClassProvider.overrideWithValue(({
            required gender,
            required levelId,
            required location,
            required city,
            required country,
            required teacher,
            required tags,
            required schedules,
          }) async {
            calls.made.add({
              'gender': gender,
              'levelId': levelId,
              'location': location,
              'city': city,
              'country': country,
              'teacher': teacher,
              'tags': tags,
              'slots': schedules.length,
            });
            return 88;
          }),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async =>
                  popped = await Navigator.of(context).push<int>(
                    MaterialPageRoute(
                      builder: (_) => const CreateClassScreen(),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _fillIn(tester);
    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    expect(popped, 88);
    expect(calls.made, [
      {
        'gender': 1,
        'levelId': 2,
        'location': 'Hall',
        'city': 'Mumbai',
        'country': 'India',
        'teacher': 1234,
        'tags': [3],
        'slots': 1,
      },
    ]);
  });

  testWidgets('Create is disabled from the first tap until the answer comes', (
    tester,
  ) async {
    _tall(tester);
    final reply = Completer<int>();
    var sent = 0;
    await tester.pumpWidget(
      _wrap(
        create:
            ({
              required gender,
              required levelId,
              required location,
              required city,
              required country,
              required teacher,
              required tags,
              required schedules,
            }) {
              sent++;
              return reply.future;
            },
      ),
    );
    await tester.pumpAndSettle();
    await _fillIn(tester);
    await tester.tap(_createButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(_creatingButton).onPressed, isNull);
    await tester.tap(_creatingButton, warnIfMissed: false);
    await tester.pump();
    expect(sent, 1);
  });

  testWidgets('a refusal shows the server\'s words and lets the user retry', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _wrap(
        create:
            ({
              required gender,
              required levelId,
              required location,
              required city,
              required country,
              required teacher,
              required tags,
              required schedules,
            }) async =>
                throw const ApiException('This class was just created', 409),
      ),
    );
    await tester.pumpAndSettle();
    await _fillIn(tester);
    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    expect(find.text('This class was just created'), findsOneWidget);
    expect(tester.widget<FilledButton>(_createButton).onPressed, isNotNull);
  });

  testWidgets('a form that cannot load offers a retry', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(optionsError: Exception('offline')));
    await tester.pumpAndSettle();

    expect(find.text('The form could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
