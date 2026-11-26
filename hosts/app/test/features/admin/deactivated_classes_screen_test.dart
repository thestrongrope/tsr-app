import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/deactivated_classes.dart';
import 'package:the_strong_rope/features/admin/providers/deactivated_classes_provider.dart';
import 'package:the_strong_rope/features/admin/screens/deactivated_classes_screen.dart';

final _mk1 = DeactivatedClass(
  id: 4,
  code: 'MK1',
  level: 'MIQDAD',
  gender: 1,
  teacher: 'Ali',
  type: 'shutdown',
  effectiveDate: '2026-09-01',
  reason: 'Low turnout',
  performedBy: 'Admin A',
  performedAt: DateTime.utc(2026, 9, 2, 10),
);

final _old = DeactivatedClass(
  id: 5,
  code: 'OLD1',
  level: 'AMMAR',
  gender: 2,
  teacher: '',
  type: 'completed',
  effectiveDate: '2024-05-01',
  reason: 'Course done',
  performedBy: '#8',
  performedAt: null,
);

const _entry = DeactivationLogEntry(
  id: 2,
  code: 'MK1',
  level: 'MIQDAD',
  gender: 1,
  type: 'shutdown',
  effectiveDate: '2026-09-01',
  reason: 'Low turnout',
  performedBy: 'Admin A',
  performedAt: null,
);

const _ab2 = DeactivationCandidate(
  id: 7,
  code: 'AB2',
  level: 'AMMAR',
  gender: 2,
  teacher: 'Zainab',
  city: 'Dubai',
  students: 12,
);

const _ab3 = DeactivationCandidate(
  id: 8,
  code: 'AB3',
  level: 'BILAL',
  gender: 1,
  teacher: 'Hasan',
  city: 'Pune',
  students: 1,
);

DeactivatedClasses _data({
  List<DeactivatedClass>? classes,
  List<DeactivationLogEntry> log = const [_entry],
}) => DeactivatedClasses(deactivated: classes ?? [_mk1, _old], log: log);

Widget _wrap(
  Future<DeactivatedClasses> Function() load, {
  Future<List<DeactivationCandidate>> Function()? candidates,
  DeactivateClass? deactivate,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      deactivatedClassesProvider.overrideWith((ref) => load()),
      if (candidates != null)
        deactivationCandidatesProvider.overrideWith((ref) => candidates()),
      if (deactivate != null)
        deactivateClassProvider.overrideWithValue(deactivate),
    ],
    child: const MaterialApp(home: DeactivatedClassesScreen()),
  );
}

Future<void> _tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The form's two text fields: the list screen under it has a search field too,
/// so each is found by its own label.
Finder _reasonField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == 'Reason',
);

Finder _searchField() => find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      w.decoration?.hintText == 'Search by code, level, teacher or city',
);

/// Opens the deactivate form and chooses [code], leaving it ready for a reason.
Future<void> _choose(WidgetTester tester, String code) async {
  await tester.tap(find.text('Deactivate a class'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(code));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, {String reason = 'Finished'}) async {
  await tester.enterText(_reasonField(), reason);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Deactivate class'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the deactivated classes with why, when and by whom', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_wrap(() async => _data()));
    await tester.pumpAndSettle();

    expect(find.text('2 deactivated'), findsOneWidget);
    expect(find.text('MK1 · Shutdown'), findsOneWidget);
    expect(find.text('MIQDAD · Gents · Ali'), findsOneWidget);
    expect(find.text('Effective 2026-09-01'), findsOneWidget);
    expect(find.text('Low turnout'), findsOneWidget);
    expect(find.textContaining('By Admin A · '), findsOneWidget);
    expect(find.text('OLD1 · Completed'), findsOneWidget);
    expect(
      find.text('By #8'),
      findsOneWidget,
      reason: 'no time: none is shown',
    );
    expect(
      tester.getTopLeft(find.text('MK1 · Shutdown')).dy,
      lessThan(tester.getTopLeft(find.text('OLD1 · Completed')).dy),
    );
  });

  testWidgets('the time is shown in the device\'s own time', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(_wrap(() async => _data()));
    await tester.pumpAndSettle();

    final local = DateFormat(
      'd MMM y, HH:mm',
    ).format(DateTime.utc(2026, 9, 2, 10).toLocal());
    expect(find.text('By Admin A · $local'), findsOneWidget);
  });

  testWidgets('searching narrows by any of the web table\'s fields', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_wrap(() async => _data()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'turnout');
    await tester.pumpAndSettle();
    expect(find.text('MK1 · Shutdown'), findsOneWidget);
    expect(find.text('OLD1 · Completed'), findsNothing);
    expect(find.text('1 of 2 deactivated'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No class matches your search.'), findsOneWidget);
  });

  testWidgets('nothing deactivated yet says so', (tester) async {
    await tester.pumpWidget(_wrap(() async => _data(classes: [], log: [])));
    await tester.pumpAndSettle();

    expect(find.text('No class has been deactivated.'), findsOneWidget);
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('No log entries yet.'), findsOneWidget);
  });

  testWidgets('Activity shows the log', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(_wrap(() async => _data()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Latest 1'), findsOneWidget);
    expect(find.text('MK1 · Shutdown'), findsOneWidget);
    expect(find.text('By Admin A'), findsOneWidget);
    expect(find.text('OLD1 · Completed'), findsNothing);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(() async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _data();
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The deactivated classes could not be loaded.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('MK1 · Shutdown'), findsOneWidget);
  });

  testWidgets('the picker lists the classes, searches them, and chooses one', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(() async => _data(), candidates: () async => [_ab2, _ab3]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate a class'));
    await tester.pumpAndSettle();

    expect(find.text('AB2'), findsOneWidget);
    expect(
      find.text('AMMAR · Ladies · Zainab · Dubai · 12 students'),
      findsOneWidget,
    );

    await tester.enterText(_searchField(), 'pune');
    await tester.pumpAndSettle();
    expect(find.text('AB2'), findsNothing);
    expect(find.text('AB3'), findsOneWidget);

    await tester.tap(find.text('AB3'));
    await tester.pumpAndSettle();
    expect(find.text('Change'), findsOneWidget);
    expect(
      find.text('BILAL · Gents · Hasan · Pune · 1 students'),
      findsOneWidget,
    );
  });

  testWidgets('the button waits for a class and a reason', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(() async => _data(), candidates: () async => [_ab2]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate a class'));
    await tester.pumpAndSettle();

    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Deactivate class'),
    );
    expect(button().onPressed, isNull, reason: 'no class yet');

    await tester.tap(find.text('AB2'));
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull, reason: 'no reason yet');

    await tester.enterText(_reasonField(), '   ');
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull, reason: 'a blank reason is no reason');

    await tester.enterText(_reasonField(), 'Done');
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('the reason stops at three hundred characters', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(() async => _data(), candidates: () async => [_ab2]),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'AB2');

    await tester.enterText(_reasonField(), 'a' * 301);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(_reasonField());
    expect(field.controller!.text.length, 300);
  });

  testWidgets(
    'the confirmation shows the class and its students, and Cancel does nothing',
    (tester) async {
      await _tall(tester);
      var asked = 0;
      await tester.pumpWidget(
        _wrap(
          () async => _data(),
          candidates: () async => [_ab2],
          deactivate:
              ({
                required classId,
                required type,
                required effectiveDate,
                required reason,
              }) async => asked++,
        ),
      );
      await tester.pumpAndSettle();
      await _choose(tester, 'AB2');
      await tester.enterText(_reasonField(), 'Finished');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate class'));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate this class?'), findsOneWidget);
      expect(find.text('12 students will be removed from it.'), findsOneWidget);
      expect(find.text('This cannot be undone from the app.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(asked, 0);
      expect(find.text('Deactivate this class?'), findsNothing);
      expect(find.text('Deactivate a class'), findsWidgets);
    },
  );

  testWidgets('one student is not "1 students"', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(() async => _data(), candidates: () async => [_ab3]),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'AB3');
    await tester.enterText(_reasonField(), 'Done');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate class'));
    await tester.pumpAndSettle();

    expect(find.text('1 student will be removed from it.'), findsOneWidget);
  });

  testWidgets('confirming deactivates, reloads the list and says so', (
    tester,
  ) async {
    await _tall(tester);
    var loads = 0;
    final asked = <Map<String, Object>>[];
    await tester.pumpWidget(
      _wrap(
        () async {
          loads++;
          return _data();
        },
        candidates: () async => [_ab2],
        deactivate:
            ({
              required classId,
              required type,
              required effectiveDate,
              required reason,
            }) async => asked.add({
              'classId': classId,
              'type': type,
              'effectiveDate': effectiveDate,
              'reason': reason,
            }),
      ),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'AB2');
    await tester.tap(find.text('Shutdown'));
    await tester.pumpAndSettle();
    await _submit(tester, reason: '  Low turnout  ');

    expect(asked, [
      {
        'classId': 7,
        'type': 'shutdown',
        'effectiveDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'reason': 'Low turnout',
      },
    ]);
    expect(loads, 2);
    expect(find.text('AB2 deactivated.'), findsOneWidget);
    expect(
      find.text('Deactivate a class'),
      findsOneWidget,
      reason: 'back on the list',
    );
  });

  testWidgets(
    'a class already deactivated by someone else closes the form and reloads',
    (tester) async {
      await _tall(tester);
      var loads = 0;
      await tester.pumpWidget(
        _wrap(
          () async {
            loads++;
            return _data();
          },
          candidates: () async => [_ab2],
          deactivate:
              ({
                required classId,
                required type,
                required effectiveDate,
                required reason,
              }) async => throw const ApiException(
                'Class #7 is not active (status=I)',
                409,
              ),
        ),
      );
      await tester.pumpAndSettle();
      await _choose(tester, 'AB2');
      await _submit(tester);

      expect(find.text('Class #7 is not active (status=I)'), findsOneWidget);
      expect(
        find.text('Deactivate a class'),
        findsOneWidget,
        reason: 'back on the list',
      );
      expect(loads, 2);
    },
  );

  testWidgets(
    'a refusal keeps the form with the server\'s words and writes nothing',
    (tester) async {
      await _tall(tester);
      var loads = 0;
      await tester.pumpWidget(
        _wrap(
          () async {
            loads++;
            return _data();
          },
          candidates: () async => [_ab2],
          deactivate:
              ({
                required classId,
                required type,
                required effectiveDate,
                required reason,
              }) async => throw const ApiException(
                'Invalid effective date; expected YYYY-MM-DD',
                422,
              ),
        ),
      );
      await tester.pumpAndSettle();
      await _choose(tester, 'AB2');
      await _submit(tester, reason: 'Keep me');

      expect(
        find.text('Invalid effective date; expected YYYY-MM-DD'),
        findsOneWidget,
      );
      expect(find.text('Reason'), findsOneWidget, reason: 'still on the form');
      expect(
        find.text('Keep me'),
        findsOneWidget,
        reason: 'the reason is kept',
      );
      expect(loads, 1, reason: 'nothing changed, so no reload');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Deactivate class'),
            )
            .onPressed,
        isNotNull,
        reason: 'they can fix it and try again',
      );
    },
  );

  testWidgets('a failure that rolled back shows the server\'s message', (
    tester,
  ) async {
    await _tall(tester);
    const message =
        'The class could not be deactivated, and nothing was changed. Please try again.';
    await tester.pumpWidget(
      _wrap(
        () async => _data(),
        candidates: () async => [_ab2],
        deactivate:
            ({
              required classId,
              required type,
              required effectiveDate,
              required reason,
            }) async => throw const ApiException(message, 500),
      ),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'AB2');
    await _submit(tester);

    expect(find.text(message), findsOneWidget);
  });

  testWidgets('any other failure says to try again', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(
        () async => _data(),
        candidates: () async => [_ab2],
        deactivate:
            ({
              required classId,
              required type,
              required effectiveDate,
              required reason,
            }) async => throw Exception('boom'),
      ),
    );
    await tester.pumpAndSettle();
    await _choose(tester, 'AB2');
    await _submit(tester);

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('classes that fail to load offer a retry; none says so', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        () async => _data(),
        candidates: () async {
          calls++;
          if (calls == 1) throw Exception('boom');
          return <DeactivationCandidate>[];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate a class'));
    await tester.pumpAndSettle();
    expect(find.text('The classes could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('There are no active classes.'), findsOneWidget);
  });
}
