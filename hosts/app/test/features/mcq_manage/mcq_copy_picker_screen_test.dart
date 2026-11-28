import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_manage.dart';
import 'package:the_strong_rope/features/mcq_manage/providers/mcq_manage_provider.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/mcq_manage_repository.dart';
import 'package:the_strong_rope/features/mcq_manage/screens/mcq_copy_picker_screen.dart';

class _FakeRepository extends McqManageRepository {
  List<McqCopyClass> classes = const [
    McqCopyClass(id: 1, code: 'G1', level: 'MIQDAD', teacher: 'Ali'),
    McqCopyClass(id: 2, code: 'G2', level: 'MIQDAD', teacher: 'Zayd'),
  ];
  (int, int)? copied;

  @override
  Future<List<McqCopyClass>> getCopyClasses() async => classes;

  @override
  Future<List<String>> getCopyTopics(int classId) async => ['Fiqh'];

  @override
  Future<List<McqCopyQuiz>> getCopyQuizzes(int classId, String topic) async => [
    const McqCopyQuiz(id: 7, name: 'Wudu', createdAt: '2026-10-01T10:00:00'),
  ];

  @override
  Future<int> copyQuiz(int quizId, int targetClassId) async {
    copied = (quizId, targetClassId);
    return 55;
  }
}

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mcqManageRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: McqCopyPickerScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  await tester.tap(find.text(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each step appears after the one before it', (tester) async {
    await _pump(tester, _FakeRepository());
    expect(find.text('From class'), findsOneWidget);
    expect(find.text('Topic'), findsNothing);

    await _choose(tester, 'From class', 'G1 - Ali');
    expect(find.text('Topic'), findsOneWidget);
    expect(find.text('MCQ'), findsNothing);

    await _choose(tester, 'Topic', 'Fiqh');
    expect(find.text('MCQ'), findsOneWidget);
    expect(find.text('To class'), findsNothing);

    await _choose(tester, 'MCQ', 'Wudu - 2026-10-01');
    expect(find.text('To class'), findsOneWidget);
    expect(find.text('Copy Quiz'), findsOneWidget);
  });

  testWidgets('the target list leaves out the class copied from', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository());
    await _choose(tester, 'From class', 'G1 - Ali');
    await _choose(tester, 'Topic', 'Fiqh');
    await _choose(tester, 'MCQ', 'Wudu - 2026-10-01');

    await tester.tap(find.text('To class'));
    await tester.pumpAndSettle();
    expect(
      find.text('G1 - Ali'),
      findsOneWidget,
      reason: 'only the From field',
    );
    expect(find.text('G2 - Zayd'), findsOneWidget);
  });

  testWidgets('Copy is disabled until a target is chosen, then copies', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);
    await _choose(tester, 'From class', 'G1 - Ali');
    await _choose(tester, 'Topic', 'Fiqh');
    await _choose(tester, 'MCQ', 'Wudu - 2026-10-01');

    final button = find.widgetWithText(FilledButton, 'Copy Quiz');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await _choose(tester, 'To class', 'G2 - Zayd');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.copied, (7, 2));
  });

  testWidgets('a member with no copyable classes sees an empty message', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository()..classes = const []);
    expect(find.text('No classes to copy between.'), findsOneWidget);
    expect(find.text('From class'), findsNothing);
  });
}
