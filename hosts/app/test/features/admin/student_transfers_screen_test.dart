import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/student_transfers.dart';
import 'package:the_strong_rope/features/admin/providers/student_transfers_provider.dart';
import 'package:the_strong_rope/features/admin/screens/student_transfers_screen.dart';

TransferClass _class(
  int id,
  String code, {
  int gender = 1,
  String level = 'Bilal',
  String? teacher = 'Mr Raza',
  bool active = true,
}) => TransferClass(
  id: id,
  code: code,
  name: 'Class $code',
  level: level,
  gender: gender,
  teacher: teacher,
  city: 'Mumbai',
  country: 'IN',
  students: 2,
  active: active,
);

final _classes = TransferClasses(
  classes: [
    _class(1, 'AG1'),
    _class(2, 'AG2', level: 'Ammar', teacher: 'Mr Khan'),
    _class(3, 'AG3', active: false),
    _class(4, 'LG1', gender: 2, teacher: 'Mrs Ali'),
  ],
  levels: ['Bilal', 'Ammar'],
);

TransferStudent _student(int token, String name, {bool cohort = false}) =>
    TransferStudent(
      token: token,
      name: name,
      email: '$token@example.test',
      mobile: '+$token',
      joinedOn: '2026-09-01',
      removedOn: null,
      fromDeactivation: cohort,
    );

class _Moves {
  final calls = <Map<String, Object?>>[];
  Object? failWith;
  TransferResult result = const TransferResult(
    moved: [TransferOutcome(token: 101, name: 'Ali Raza')],
    failed: [],
  );

  Future<TransferResult> call({
    required int fromClassId,
    required int toClassId,
    required String type,
    required String reason,
    required List<int> tokens,
  }) async {
    calls.add({
      'from': fromClassId,
      'to': toClassId,
      'type': type,
      'reason': reason,
      'tokens': tokens,
    });
    if (failWith != null) throw failWith!;
    return result;
  }
}

void main() {
  late _Moves moves;
  late List<List<Object>> historyCalls;

  setUp(() {
    moves = _Moves();
    historyCalls = [];
  });

  Widget wrap({
    Map<int, List<TransferStudent>>? rosters,
    TransferHistoryPage? history,
  }) {
    final byClass =
        rosters ??
        {
          1: [_student(101, 'Ali Raza'), _student(102, 'Zayd Khan')],
          3: [_student(201, 'Hasan Ali', cohort: true)],
        };
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        transferClassesProvider.overrideWith((ref) async => _classes),
        transferStudentsProvider.overrideWith(
          (ref, id) async => byClass[id] ?? const [],
        ),
        moveStudentsProvider.overrideWithValue(moves.call),
        transferHistoryLoaderProvider.overrideWithValue((query, page) async {
          historyCalls.add([query, page]);
          return history ?? const TransferHistoryPage(total: 0, items: []);
        }),
      ],
      child: const MaterialApp(home: StudentTransfersScreen()),
    );
  }

  Future<void> open(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> chooseClass(
    WidgetTester tester,
    String field,
    String code,
  ) async {
    await tester.tap(find.widgetWithText(InkWell, field));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('$code — '));
    await tester.pumpAndSettle();
  }

  Finder moveButton() => find.widgetWithText(FilledButton, 'Move students');

  testWidgets(
    'a move cannot be confirmed without a destination, a type and a student',
    (tester) async {
      await open(tester, wrap());
      await chooseClass(tester, 'From class', 'AG1');

      expect(tester.widget<FilledButton>(moveButton()).onPressed, isNull);

      await tester.tap(find.text('Ali Raza'));
      await tester.pumpAndSettle();
      // A student chosen, still no destination or type.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Move 1 student(s)'),
            )
            .onPressed,
        isNull,
      );

      await chooseClass(tester, 'To class', 'AG2');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Move 1 student(s)'),
            )
            .onPressed,
        isNull,
        reason: 'no type yet',
      );

      await tester.tap(find.text('Promotion'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Move 1 student(s)'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'the roster has search, select all and a count of what is selected',
    (tester) async {
      await open(tester, wrap());
      await chooseClass(tester, 'From class', 'AG1');

      expect(find.text('Select all (2)'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      await tester.tap(find.text('Select all (2)'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search students'),
        'zayd',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ali Raza'), findsNothing);
      expect(find.text('Zayd Khan'), findsOneWidget);
      expect(find.text('Select all (1)'), findsOneWidget);
    },
  );

  testWidgets('the roster shows contact details', (tester) async {
    await open(tester, wrap());
    await chooseClass(tester, 'From class', 'AG1');

    expect(find.textContaining('101@example.test'), findsOneWidget);
    expect(find.textContaining('+101'), findsOneWidget);
  });

  testWidgets('a deactivated class lists the students it had, marked as such', (
    tester,
  ) async {
    await open(tester, wrap());
    await chooseClass(tester, 'From class', 'AG3');

    expect(find.textContaining('was deactivated'), findsOneWidget);
    expect(find.textContaining('from deactivation'), findsOneWidget);
  });

  testWidgets(
    'the destination list is active classes of the source class gender',
    (tester) async {
      await open(tester, wrap());
      await chooseClass(tester, 'From class', 'AG1');

      await tester.tap(find.widgetWithText(InkWell, 'To class'));
      await tester.pumpAndSettle();
      expect(find.textContaining('AG2 — '), findsOneWidget);
      expect(
        find.textContaining('AG3 — '),
        findsNothing,
        reason: 'deactivated',
      );
      expect(
        find.textContaining('LG1 — '),
        findsNothing,
        reason: 'other gender',
      );
    },
  );

  testWidgets('classes can be searched by teacher', (tester) async {
    await open(tester, wrap());
    await tester.tap(find.widgetWithText(InkWell, 'From class'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'khan');
    await tester.pumpAndSettle();
    expect(find.textContaining('AG2 — '), findsOneWidget);
    expect(find.textContaining('AG1 — '), findsNothing);
  });

  testWidgets('a move asks first, then sends what was chosen', (tester) async {
    await open(tester, wrap());
    await chooseClass(tester, 'From class', 'AG1');
    await tester.tap(find.text('Ali Raza'));
    await chooseClass(tester, 'To class', 'AG2');
    await tester.tap(find.text('Promotion'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason (optional)'),
      'New term',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Move 1 student(s)'));
    await tester.pumpAndSettle();
    expect(find.text('Promotion 1 student(s)?'), findsOneWidget);
    expect(moves.calls, isEmpty, reason: 'nothing before the confirmation');

    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();

    expect(moves.calls, [
      {
        'from': 1,
        'to': 2,
        'type': 'promotion',
        'reason': 'New term',
        'tokens': [101],
      },
    ]);
    expect(find.text('Moved 1, not moved 0'), findsOneWidget);
  });

  testWidgets(
    'a partial move says who moved and who did not, and keeps the rest chosen',
    (tester) async {
      moves.result = const TransferResult(
        moved: [TransferOutcome(token: 101, name: 'Ali Raza')],
        failed: [
          TransferOutcome(
            token: 102,
            name: 'Zayd Khan',
            reason: 'Student 102 is already enrolled in destination class #2',
          ),
        ],
      );
      await open(tester, wrap());
      await chooseClass(tester, 'From class', 'AG1');
      await tester.tap(find.text('Select all (2)'));
      await chooseClass(tester, 'To class', 'AG2');
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Move 2 student(s)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Move'));
      await tester.pumpAndSettle();

      expect(find.text('Moved 1, not moved 1'), findsOneWidget);
      expect(
        find.textContaining('Zayd Khan: Student 102 is already enrolled'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Move 1 student(s)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a refusal shows the server words and records no result', (
    tester,
  ) async {
    moves.failWith = const ApiException(
      'A student can only move to a class of the same gender',
      422,
    );
    await open(tester, wrap());
    await chooseClass(tester, 'From class', 'AG1');
    await tester.tap(find.text('Ali Raza'));
    await chooseClass(tester, 'To class', 'AG2');
    await tester.tap(find.text('Demotion'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move 1 student(s)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();

    expect(
      find.text('A student can only move to a class of the same gender'),
      findsOneWidget,
    );
    expect(find.textContaining('not moved'), findsNothing);
    expect(find.text('Select all (2)'), findsOneWidget);
  });

  testWidgets('History lists every field and searches', (tester) async {
    final entry = TransferHistoryEntry(
      id: 1,
      studentToken: 101,
      studentName: 'Ali Raza',
      type: 'promotion',
      fromCode: 'AG1',
      toCode: 'AG2',
      reason: 'New term',
      transferredBy: 'Admin One',
      transferredAt: DateTime(2026, 10, 20, 10),
    );
    await open(
      tester,
      wrap(history: TransferHistoryPage(total: 1, items: [entry])),
    );
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ali Raza (#101): Promotion, AG1 → AG2'),
      findsOneWidget,
    );
    expect(
      find.textContaining('20 Oct 2026, 10:00 · by Admin One · New term'),
      findsOneWidget,
    );
    expect(historyCalls.first, ['', 1]);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search student, class, reason or admin'),
      'ali',
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(historyCalls.last, ['ali', 1]);
  });

  testWidgets('History pages: Load more asks for the next page', (
    tester,
  ) async {
    final entries = [
      for (var i = 1; i <= 2; i++)
        TransferHistoryEntry(
          id: i,
          studentToken: 100 + i,
          studentName: 'Student $i',
          type: 'transfer',
          fromCode: 'AG1',
          toCode: 'AG2',
          reason: null,
          transferredBy: 'Admin',
          transferredAt: DateTime(2026, 10, i),
        ),
    ];
    await open(
      tester,
      wrap(history: TransferHistoryPage(total: 4, items: entries)),
    );
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load more (2 of 4)'));
    await tester.pumpAndSettle();
    expect(historyCalls.last, ['', 2]);
  });

  testWidgets('History with nothing says so', (tester) async {
    await open(tester, wrap());
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('No transfers found.'), findsOneWidget);
  });
}
