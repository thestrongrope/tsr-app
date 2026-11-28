import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_manage.dart';
import 'package:the_strong_rope/features/mcq_manage/providers/mcq_manage_provider.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/mcq_manage_repository.dart';
import 'package:the_strong_rope/features/mcq_manage/screens/mcq_edit_screen.dart';

/// Records what the screen sends instead of calling the API.
class _FakeRepository implements McqManageRepository {
  String? createdTopic;
  String? updatedTopic;
  List<McqManageQuestion>? updatedQuestions;

  @override
  Future<List<String>> getTopics(int classId) async => ['Quran'];

  @override
  Future<int> createQuiz(
    int classId, {
    required String name,
    required String topic,
    int restrictToClass = 1,
  }) async {
    createdTopic = topic;
    return 7;
  }

  @override
  Future<void> updateQuiz(
    int quizId, {
    required String name,
    required String topic,
    int? restrictToClass,
    required List<McqManageQuestion> questions,
  }) async {
    updatedTopic = topic;
    updatedQuestions = questions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepository repository;

  Widget createWidgetUnderTest() {
    // The screen pops itself after saving, so it needs a route to pop back to.
    final router = GoRouter(
      initialLocation: '/new',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const McqEditScreen(classId: 42),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [mcqManageRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Finder addQuestionButton() =>
      find.widgetWithText(OutlinedButton, 'Add Question');

  // Tall enough that the ListView builds the whole form, save button included.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
  }

  setUp(() => repository = _FakeRepository());

  testWidgets('Add Question is disabled until a topic is entered', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      tester.widget<OutlinedButton>(addQuestionButton()).onPressed,
      isNull,
    );
    expect(
      find.text('Enter a topic above to start adding questions.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Topic *'),
      'Aqaid',
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<OutlinedButton>(addQuestionButton()).onPressed,
      isNotNull,
    );
  });

  testWidgets('a typed topic not picked from suggestions is sent', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quiz Name *'),
      'Imams',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Topic *'),
      'Aqaid',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(addQuestionButton());
    await tester.tap(addQuestionButton());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Question *'),
      'Who is the 7th Imam?',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correct Answer *'),
      'Imam Musa e Kazim (as)',
    );

    await tester.ensureVisible(find.text('Create Quiz'));
    await tester.tap(find.text('Create Quiz'));
    await tester.pumpAndSettle();

    expect(repository.createdTopic, 'Aqaid');
    expect(repository.updatedTopic, 'Aqaid');
    expect(
      repository.updatedQuestions?.single.question,
      'Who is the 7th Imam?',
    );
  });

  testWidgets('saving without a topic shows a validation message', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quiz Name *'),
      'Imams',
    );
    await tester.ensureVisible(find.text('Create Quiz'));
    await tester.tap(find.text('Create Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a topic'), findsOneWidget);
    expect(repository.createdTopic, isNull);
  });

  testWidgets('Add Question scrolls to the new question', (tester) async {
    // The default 800x600 test view: short enough that the form scrolls.
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Topic *'),
      'Aqaid',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(addQuestionButton());
    await tester.pumpAndSettle();
    await tester.tap(addQuestionButton());
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, position.maxScrollExtent);
    expect(find.widgetWithText(TextFormField, 'Question *'), findsOneWidget);
  });
}
