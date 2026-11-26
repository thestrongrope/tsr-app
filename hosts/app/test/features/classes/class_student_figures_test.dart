import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/widgets/skeleton_box.dart';
import 'package:the_strong_rope/features/classes/models/class_student_figures.dart';
import 'package:the_strong_rope/features/classes/providers/class_manage_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';
import 'package:the_strong_rope/features/classes/screens/class_student_figures_screen.dart';

ClassStudentFigures _figures({
  String from = '2025-10-22',
  String to = '2026-10-22',
  bool empty = false,
}) {
  if (empty) {
    return ClassStudentFigures.fromJson({
      'from': from,
      'to': to,
      'totalMcqs': 0,
      'maxMarks': {'total': 0, 'topics': []},
      'students': [
        {'token': 10, 'name': 'Ann', 'topics': {}},
      ],
    });
  }
  return ClassStudentFigures.fromJson({
    'from': from,
    'to': to,
    'totalMcqs': 4,
    'maxMarks': {
      'total': 8,
      'topics': [
        {'name': 'Quran', 'max': 5},
        {'name': 'Aqaed', 'max': 3},
      ],
    },
    'students': [
      {
        'token': 10,
        'name': 'Ann',
        'expected': 8,
        'present': 6,
        'attendance': 75,
        'mcqAttempted': 3,
        'mcqCorrect': 4,
        'topics': {'Quran': 3, 'Aqaed': 1},
        'recitation': 12,
      },
      {
        'token': 11,
        'name': 'Bob',
        'expected': 8,
        'present': 8,
        'attendance': 100,
        'mcqAttempted': 0,
        'mcqCorrect': 0,
        'topics': {'Quran': 0, 'Aqaed': 0},
        'recitation': 0,
      },
    ],
  });
}

class _FakeRepository extends ClassManageRepository {
  final List<({String? from, String? to})> calls = [];
  Object? failWith;
  bool empty = false;

  @override
  Future<ClassStudentFigures> getStudentFigures(
    int classId, {
    String? from,
    String? to,
  }) async {
    calls.add((from: from, to: to));
    final error = failWith;
    if (error != null) throw error;
    return _figures(
      from: from ?? '2025-10-22',
      to: to ?? '2026-10-22',
      empty: empty,
    );
  }
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    ClassManageRepository repo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [classManageRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ClassStudentFiguresScreen(classId: 10)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the attendance tab shows expected, present and percentage', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await pumpScreen(tester, repo);

    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // No range chosen: the server's default, the last year.
    expect(repo.calls, [(from: null, to: null)]);
    expect(find.text('Oct 22, 2025  to  Oct 22, 2026'), findsOneWidget);
  });

  testWidgets('the MCQ tab shows absolute figures, then percentages', (
    tester,
  ) async {
    await pumpScreen(tester, _FakeRepository());
    await tester.tap(find.text('MCQ'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 4'), findsOneWidget); // attempted
    expect(find.text('4 / 8'), findsOneWidget); // overall
    expect(find.text('3 / 5'), findsOneWidget); // Quran
    expect(find.text('1 / 3'), findsOneWidget); // Aqaed
    expect(find.text('Quran'), findsOneWidget);

    await tester.tap(find.text('%'));
    await tester.pumpAndSettle();

    expect(find.text('75%'), findsOneWidget); // attempted 3 of 4
    expect(find.text('50%'), findsOneWidget); // overall 4 of 8
    expect(find.text('60%'), findsOneWidget); // Quran 3 of 5
    expect(find.text('33%'), findsOneWidget); // Aqaed 1 of 3
    expect(find.text('3 / 4'), findsNothing);
  });

  testWidgets('a table wider than the screen scrolls with the name kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(260, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, _FakeRepository());
    await tester.tap(find.text('MCQ'));
    await tester.pumpAndSettle();

    final nameBefore = tester.getTopLeft(find.text('Ann')).dx;
    final overallBefore = tester.getTopLeft(find.text('4 / 8')).dx;

    await tester.drag(
      find.byKey(const Key('figuresScrollingColumns')),
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Ann')).dx, nameBefore);
    expect(tester.getTopLeft(find.text('4 / 8')).dx, lessThan(overallBefore));
  });

  testWidgets('the name column grows with text size and shows a full name', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classManageRepositoryProvider.overrideWithValue(
            _LongNameRepository(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const ClassStudentFiguresScreen(classId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final name = find.text('Hussain');
    expect(name, findsOneWidget);
    expect(tester.renderObject<RenderParagraph>(name).didExceedMaxLines, false);
  });

  testWidgets('while loading it shows a skeleton', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classManageRepositoryProvider.overrideWithValue(_NeverRepository()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: ClassStudentFiguresScreen(classId: 10),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the recitation tab shows the totals', (tester) async {
    await pumpScreen(tester, _FakeRepository());
    await tester.tap(find.text('Recitation').first);
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('changing the range asks again and every tab keeps it', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await pumpScreen(tester, repo);

    await tester.tap(find.byKey(const Key('studentFiguresRange')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.tap(find.text('2').first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    // The picker opens on the month the default range starts in.
    final month = '${now.year - 1}-${now.month.toString().padLeft(2, '0')}';
    expect(repo.calls.last, (from: '$month-01', to: '$month-02'));
    final y = now.year - 1;
    final shown =
        '${DateFormat('MMM d, yyyy').format(DateTime(y, now.month, 1))}'
        '  to  ${DateFormat('MMM d, yyyy').format(DateTime(y, now.month, 2))}';
    expect(repo.calls, hasLength(2));
    expect(find.text(shown), findsOneWidget);

    // Switching view keeps the range and does not fetch again.
    await tester.tap(find.text('MCQ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recitation').first);
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));
    expect(find.text(shown), findsOneWidget);
  });

  testWidgets('a class with no activity says so instead of showing a grid', (
    tester,
  ) async {
    await pumpScreen(tester, _FakeRepository()..empty = true);

    expect(
      find.text('No attendance, MCQs or recitation in this range.'),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('a class with no students says so', (tester) async {
    final repo = _EmptyClassRepository();
    await pumpScreen(tester, repo);

    expect(find.text('No students in this class.'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('a refused range shows the reason and offers a retry', (
    tester,
  ) async {
    final repo = _FakeRepository()
      ..failWith = const ApiException(
        'The range can cover at most a year',
        422,
      );
    await pumpScreen(tester, repo);

    expect(find.text('The range can cover at most a year'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });
}

class _EmptyClassRepository extends ClassManageRepository {
  @override
  Future<ClassStudentFigures> getStudentFigures(
    int classId, {
    String? from,
    String? to,
  }) async => ClassStudentFigures.fromJson({
    'from': '2025-10-22',
    'to': '2026-10-22',
    'totalMcqs': 0,
    'maxMarks': {'total': 0, 'topics': []},
    'students': [],
  });
}

class _NeverRepository extends ClassManageRepository {
  @override
  Future<ClassStudentFigures> getStudentFigures(
    int classId, {
    String? from,
    String? to,
  }) => Completer<ClassStudentFigures>().future;
}

class _LongNameRepository extends ClassManageRepository {
  @override
  Future<ClassStudentFigures> getStudentFigures(
    int classId, {
    String? from,
    String? to,
  }) async => ClassStudentFigures.fromJson({
    'from': '2025-10-22',
    'to': '2026-10-22',
    'totalMcqs': 0,
    'maxMarks': {'total': 0, 'topics': []},
    'students': [
      {
        'token': 1,
        'name': 'Hussain',
        'expected': 8,
        'present': 6,
        'attendance': 75,
        'topics': {},
      },
    ],
  });
}
