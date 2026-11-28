import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_manage.dart';
import 'package:the_strong_rope/features/mcq_manage/providers/mcq_manage_provider.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/mcq_manage_repository.dart';
import 'package:the_strong_rope/features/mcq_manage/screens/mcq_manage_list_screen.dart';
import 'package:the_strong_rope/features/mcq_manage/screens/mcq_standard_screen.dart';

class _FakeRepository extends McqManageRepository {
  _FakeRepository({
    required this.standardTopics,
    this.libraryFails = false,
    this.listFails = false,
  });

  final bool listFails;

  final List<McqStandardTopic> standardTopics;
  final bool libraryFails;

  @override
  Future<McqManageListResponse> getManageQuizzes(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    if (listFails) throw Exception('offline');
    return const McqManageListResponse(
      total: 0,
      page: 1,
      pageSize: 20,
      hasNext: false,
      items: [],
    );
  }

  @override
  Future<McqStandardResponse> getStandardQuizzes(int classId) async {
    if (libraryFails) throw Exception('offline');
    return McqStandardResponse(classCode: 'G1', topics: standardTopics);
  }
}

const _oneTopic = [
  McqStandardTopic(
    topic: 'Fiqh',
    subjects: [
      McqStandardSubject(
        subject: 'Wudu',
        quizzes: [
          McqStandardQuiz(
            id: 7,
            code: 'S7',
            topic: 'Fiqh',
            subject: 'Wudu',
            lesson: 'L1',
            name: 'Basics',
          ),
        ],
      ),
    ],
  ),
];

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  final router = GoRouter(
    initialLocation: '/manage',
    routes: [
      GoRoute(
        path: '/manage',
        builder: (_, _) => const McqManageListScreen(classId: 5),
      ),
      GoRoute(
        path: '/classes/5/mcq/manage/standard',
        builder: (_, _) => const McqStandardScreen(classId: 5),
      ),
      GoRoute(
        path: '/classes/5/mcq/manage/add',
        builder: (_, _) => const Scaffold(body: Text('custom form')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mcqManageRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inLibrary(Finder finder) =>
    find.descendant(of: find.byType(McqStandardScreen), matching: finder);

Future<void> _openLibrary(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'New MCQ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a library that fails to load still lets a teacher create one', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(standardTopics: _oneTopic, libraryFails: true),
    );
    await _openLibrary(tester);

    expect(find.text('Could not load standard MCQs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create_custom_mcq')));
    await tester.pumpAndSettle();

    expect(find.text('custom form'), findsOneWidget);
  });

  testWidgets('New MCQ opens the Standard MCQs library, not the form', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository(standardTopics: _oneTopic));

    await _openLibrary(tester);

    expect(find.byType(McqStandardScreen), findsOneWidget);
    expect(find.text('custom form'), findsNothing);
  });

  testWidgets('empty list: its one action link opens the library', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository(standardTopics: _oneTopic));

    expect(find.textContaining('No MCQs yet'), findsOneWidget);
    await tester.tap(find.text('Start from the Standard MCQs'));
    await tester.pumpAndSettle();

    expect(find.byType(McqStandardScreen), findsOneWidget);
    expect(find.text('custom form'), findsNothing);
  });

  testWidgets('the library offers the custom form as a secondary link', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository(standardTopics: _oneTopic));
    await _openLibrary(tester);

    expect(
      find.text('There is no Standard MCQ for this class yet.'),
      findsNothing,
    );

    await tester.tap(find.text('Cannot find one? Create a custom MCQ'));
    await tester.pumpAndSettle();

    expect(find.text('custom form'), findsOneWidget);
  });

  testWidgets('the custom action is on the Standard screen with results and '
      'with none', (tester) async {
    const key = ValueKey('create_custom_mcq');

    await _pump(tester, _FakeRepository(standardTopics: _oneTopic));
    await _openLibrary(tester);
    expect(find.byKey(key), findsOneWidget);
    expect(_inLibrary(find.byType(TextButton)), findsOneWidget);

    await _pump(tester, _FakeRepository(standardTopics: const []));
    await _openLibrary(tester);
    expect(find.byKey(key), findsOneWidget);
    expect(
      _inLibrary(find.widgetWithText(FilledButton, 'Create a custom MCQ')),
      findsOneWidget,
    );
  });

  testWidgets('an empty library makes the custom form the primary action', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository(standardTopics: const []));
    await _openLibrary(tester);

    expect(
      find.text('There is no Standard MCQ for this class yet.'),
      findsOneWidget,
    );
    expect(find.text('Cannot find one? Create a custom MCQ'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Create a custom MCQ'));
    await tester.pumpAndSettle();

    expect(find.text('custom form'), findsOneWidget);
  });

  testWidgets('a quiz list that fails to load shows a message and Retry', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(standardTopics: _oneTopic, listFails: true),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('No MCQs yet'), findsNothing);
  });
}
