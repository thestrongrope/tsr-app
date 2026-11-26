import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/admin/models/teachers.dart';
import 'package:the_strong_rope/features/admin/providers/teachers_provider.dart';
import 'package:the_strong_rope/features/admin/screens/teacher_detail_screen.dart';
import 'package:the_strong_rope/features/admin/screens/teachers_screen.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions, {PermissionScopes? scopes}) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: scopes ?? const PermissionScopes(),
        issuedAt: '',
      ),
    );
  }
}

const _levels = [
  TeacherLevel(key: 'salman', code: 'SM', name: 'Salman'),
  TeacherLevel(key: 'abuzar', code: 'AG', name: 'Abuzar'),
  TeacherLevel(key: 'miqdad', code: 'MK', name: 'Miqdad'),
  TeacherLevel(key: 'ammar', code: 'AY', name: 'Ammar'),
  TeacherLevel(key: 'bilal', code: 'BL', name: 'Bilal'),
];

TeacherRow _row(
  int token,
  String name, {
  String level = '',
  int classes = 0,
  List<String> trained = const [],
  List<String> conducting = const [],
}) => TeacherRow(
  token: token,
  name: name,
  level: level,
  classes: classes,
  flags: {for (final l in _levels) l.key: trained.contains(l.key)},
  conducting: conducting,
);

final _ali = _row(
  7,
  'Ali',
  level: 'AMMAR',
  classes: 2,
  trained: ['salman', 'abuzar'],
  conducting: ['A1', 'B2'],
);
final _zayd = _row(8, 'Zayd', level: 'BILAL', classes: 0);
final _fatima = _row(
  9,
  'Fatima',
  level: 'AMMAR',
  classes: 3,
  trained: ['ammar'],
);

TeachersList _list({int gender = 1, List<TeacherRow>? teachers}) =>
    TeachersList(
      gender: gender,
      levels: _levels,
      teachers: teachers ?? [_zayd, _ali, _fatima],
    );

const _detail = TeacherDetail(
  token: 7,
  name: 'Ali',
  email: 'ali@example.test',
  mobile: null,
  state: 'MH',
  city: 'Pune',
  country: 'India',
  zip: null,
  trained: true,
  flags: {'salman': true},
  conducting: [
    TeacherClass(
      id: 1,
      code: 'A1',
      level: 'AMMAR',
      city: 'Pune',
      country: 'India',
      startedOn: '2026-01-01',
      endedOn: null,
      comments: null,
      teacher: null,
      teacherToken: null,
      removedBy: null,
      schedules: ['Monday 19:30 IST'],
    ),
  ],
  conducted: [],
  attending: [],
  attended: [],
  history: [
    TeacherHistoryEntry(
      comments: 'ADD: Imported',
      by: 'Admin A',
      on: '2026-03-03',
    ),
  ],
);

Widget _app({
  required Future<TeachersList> Function(int gender) load,
  List<String> permissions = const ['teachers:read:all'],
  PermissionScopes? scopes,
  Future<TeacherDetail> Function(int token)? detail,
  ChangeTraining? change,
  ImportTeachers? import,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith(
        (ref) => _FixedPermissions(permissions, scopes: scopes),
      ),
      teachersProvider.overrideWith((ref, gender) => load(gender)),
      if (change != null) changeTrainingProvider.overrideWithValue(change),
      if (import != null) importTeachersProvider.overrideWithValue(import),
      if (detail != null)
        teacherDetailProvider.overrideWith((ref, token) => detail(token)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TeachersScreen()),
          GoRoute(
            path: '/admin/teachers/:token',
            builder: (_, state) => TeacherDetailScreen(
              token: int.parse(state.pathParameters['token']!),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<String> _names(WidgetTester tester) => [
  for (final n in ['Ali', 'Zayd', 'Fatima'])
    if (find.text(n).evaluate().isNotEmpty) n,
];

void main() {
  testWidgets('lists the teachers with the legend, counts and conducting', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_app(load: (_) async => _list()));
    await tester.pumpAndSettle();

    expect(find.text('3 teachers'), findsOneWidget);
    expect(
      find.text('SM Salman · AG Abuzar · MK Miqdad · AY Ammar · BL Bilal'),
      findsOneWidget,
    );
    expect(find.text('#7 · AMMAR · 2 classes'), findsOneWidget);
    expect(find.text('#8 · BILAL · 0 classes'), findsOneWidget);
    expect(find.text('Conducts A1, B2'), findsOneWidget);
  });

  testWidgets('search finds a name, a token or a class they conduct', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_app(load: (_) async => _list()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'b2');
    await tester.pumpAndSettle();
    expect(_names(tester), ['Ali']);
    expect(find.text('1 of 3 teachers'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '8');
    await tester.pumpAndSettle();
    expect(_names(tester), ['Zayd']);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No teacher matches your search.'), findsOneWidget);
  });

  testWidgets('filters by trained level and by number of classes', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_app(load: (_) async => _list()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter and sort'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Trained AY'));
    await tester.pumpAndSettle();
    expect(_names(tester), ['Fatima']);

    await tester.tap(find.widgetWithText(FilterChip, 'Trained AY'));
    await tester.tap(find.byKey(const ValueKey('class-count-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No classes').last);
    await tester.pumpAndSettle();
    expect(_names(tester), ['Zayd']);
  });

  testWidgets('sorts by name by default and by classes either way', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_app(load: (_) async => _list()));
    await tester.pumpAndSettle();

    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('Ali') < y('Fatima') && y('Fatima') < y('Zayd'), isTrue);

    await tester.tap(find.text('Filter and sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classes').last);
    await tester.pumpAndSettle();
    expect(y('Zayd') < y('Ali') && y('Ali') < y('Fatima'), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(y('Fatima') < y('Ali') && y('Ali') < y('Zayd'), isTrue);
  });

  testWidgets('only someone who reaches both genders chooses one', (
    tester,
  ) async {
    await _tall(tester);
    final asked = <int>[];
    await tester.pumpWidget(
      _app(
        load: (g) async {
          asked.add(g);
          return _list(gender: g);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsOneWidget);

    await tester.tap(find.text('Ladies'));
    await tester.pumpAndSettle();
    expect(asked, [1, 2]);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(
        load: (g) async {
          asked.add(g);
          return _list(gender: g);
        },
        permissions: ['teachers:read:gender'],
        scopes: const PermissionScopes(gender: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsNothing);
    expect(asked.last, 2, reason: 'a gender admin asks for their own');
  });

  testWidgets('a load failure offers a retry', (tester) async {
    var fail = true;
    await tester.pumpWidget(
      _app(
        load: (_) async {
          if (fail) throw const ApiException('boom', 500);
          return _list();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The teachers could not be loaded.'), findsOneWidget);

    fail = false;
    await _tall(tester);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('tapping a teacher opens their detail', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _app(load: (_) async => _list(), detail: (_) async => _detail),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ali'));
    await tester.pumpAndSettle();

    expect(find.text('ali@example.test'), findsOneWidget);
    expect(find.text('Pune, MH, India'), findsOneWidget);
    expect(find.text('A1 · AMMAR'), findsOneWidget);
    expect(find.text('Monday 19:30 IST'), findsOneWidget);
    expect(find.text('ADD: Imported'), findsOneWidget);
    expect(find.text('Admin A · 2026-03-03'), findsOneWidget);
    expect(
      find.text('None.'),
      findsNothing,
      reason: 'past sections start folded',
    );
    await tester.tap(find.text('Conducted before'));
    await tester.pumpAndSettle();
    expect(find.text('None.'), findsOneWidget);
  });

  testWidgets('a teacher that cannot be opened says so, with no retry', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(
      _app(
        load: (_) async => _list(),
        detail: (_) async => throw const ApiException('Teacher not found', 404),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali'));
    await tester.pumpAndSettle();

    expect(find.text('This teacher could not be opened.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('another detail failure offers a retry', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _app(
        load: (_) async => _list(),
        detail: (_) async => throw const ApiException('boom', 500),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali'));
    await tester.pumpAndSettle();

    expect(find.text('The teacher could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('editing', () {
    Finder flag(String name, String code) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
      matching: find.widgetWithText(ActionChip, code),
    );

    Future<void> edit(WidgetTester tester, {ChangeTraining? change}) async {
      await _tall(tester);
      await tester.pumpWidget(_app(load: (_) async => _list(), change: change));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('flags are read-only until Edit, then Changed counts them', (
      tester,
    ) async {
      await _tall(tester);
      await tester.pumpWidget(_app(load: (_) async => _list()));
      await tester.pumpAndSettle();
      expect(find.byType(ActionChip), findsNothing);
      expect(find.textContaining('Changed:'), findsNothing);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Changed: 0'), findsOneWidget);

      await tester.tap(flag('Ali', 'AY'));
      await tester.tap(flag('Zayd', 'SM'));
      await tester.pumpAndSettle();
      expect(find.text('Changed: 2'), findsOneWidget);

      // Putting a flag back as it was is not a change.
      await tester.tap(flag('Zayd', 'SM'));
      await tester.pumpAndSettle();
      expect(find.text('Changed: 1'), findsOneWidget);
    });

    testWidgets('Changed lists the changes and can clear them', (tester) async {
      await edit(tester);
      await tester.tap(flag('Ali', 'AY')); // not trained -> trained
      await tester.tap(flag('Ali', 'SM')); // trained -> not
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changed: 2'));
      await tester.pumpAndSettle();
      expect(find.text('Ali: +AY −SM'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Changed: 0'), findsOneWidget);
    });

    testWidgets('Save needs a comment, then sends the batch and reloads', (
      tester,
    ) async {
      List<TrainingChange>? sent;
      String? comment;
      await edit(
        tester,
        change: ({required changes, required comments}) async {
          sent = changes;
          comment = comments;
          return 1;
        },
      );
      await tester.tap(flag('Ali', 'AY'));
      await tester.tap(flag('Ali', 'SM'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save').last;
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '  Passed  ');
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(comment, 'Passed');
      expect(sent!.map((c) => c.toJson()), [
        {'token': 7, 'level': 'ammar', 'action': 'added'},
        {'token': 7, 'level': 'salman', 'action': 'removed'},
      ]);
      expect(find.text('1 teacher updated.'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget, reason: 'editing is over');
    });

    testWidgets('a refusal keeps the changes and the comment, with its words', (
      tester,
    ) async {
      await edit(
        tester,
        change: ({required changes, required comments}) async =>
            throw const ApiException(
              'You do not have permission to change teacher #7',
              403,
            ),
      );
      await tester.tap(flag('Ali', 'AY'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Passed');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to change teacher #7'),
        findsOneWidget,
      );
      expect(find.text('Passed'), findsOneWidget, reason: 'comment kept');

      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Changed: 1'), findsOneWidget, reason: 'changes kept');
    });

    testWidgets('a failure with no usable reply says something generic', (
      tester,
    ) async {
      await edit(
        tester,
        change: ({required changes, required comments}) async =>
            throw const ApiException('socket detail', 408),
      );
      await tester.tap(flag('Ali', 'AY'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'x');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('socket detail'), findsNothing);
    });

    testWidgets('Cancel drops the changes and leaves edit mode', (
      tester,
    ) async {
      await edit(tester);
      await tester.tap(flag('Ali', 'AY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNothing);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Changed: 0'), findsOneWidget);
    });
  });

  group('import', () {
    Future<void> openImport(WidgetTester tester, ImportTeachers? import) async {
      await _tall(tester);
      await tester.pumpWidget(
        _app(
          load: (g) async => _list(gender: g),
          import: import,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import active teachers'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, then says how many it added', (tester) async {
      int? asked;
      await openImport(tester, ({required int gender}) async {
        asked = gender;
        return 3;
      });
      expect(asked, isNull, reason: 'nothing runs before the confirmation');

      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(find.text('3 teachers imported.'), findsOneWidget);
    });

    testWidgets('Cancel imports nothing', (tester) async {
      var ran = false;
      await openImport(tester, ({required int gender}) async {
        ran = true;
        return 1;
      });
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(ran, isFalse);
    });

    testWidgets('a failure keeps the dialog with the server words', (
      tester,
    ) async {
      await openImport(
        tester,
        ({required int gender}) async => throw const ApiException(
          'The teachers could not be imported, and nothing was changed. Please try again.',
          500,
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('could not be imported, and nothing was changed'),
        findsOneWidget,
      );
    });
  });
}
