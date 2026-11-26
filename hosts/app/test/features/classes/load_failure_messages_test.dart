import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/screens/quiz_list_screen.dart';
import 'package:the_strong_rope/features/classes/screens/syllabus_screen.dart';

class _QuizRepository extends ClassesRepository {
  _QuizRepository(this.failure);
  final ApiException failure;

  @override
  Future<QuizListResponse> getClassQuizzes(
    int classId, {
    int page = 1,
    int pageSize = 20,
  }) async => throw failure;
}

class _SyllabusRepository extends SyllabusRepository {
  _SyllabusRepository(this.failure);
  final ApiException failure;

  @override
  Future<SyllabusLevel> getSyllabusByLevel(
    int levelId, {
    bool forceRefresh = false,
  }) async => throw failure;
}

Future<void> _pumpQuizzes(WidgetTester tester, ApiException failure) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        classesRepositoryProvider.overrideWithValue(_QuizRepository(failure)),
      ],
      child: const MaterialApp(home: QuizListScreen(classId: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quizzes with no connection say so', (tester) async {
    await _pumpQuizzes(tester, const ApiException('x', 0));

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a refused quiz list shows the server reason', (tester) async {
    await _pumpQuizzes(tester, const ApiException('Quizzes are closed', 403));

    expect(find.text('Quizzes are closed'), findsOneWidget);
  });

  testWidgets('a syllabus that cannot load says it is the connection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syllabusRepositoryProvider.overrideWithValue(
            _SyllabusRepository(const ApiException('x', 0)),
          ),
        ],
        child: const MaterialApp(home: SyllabusScreen(classId: 1, levelId: 3)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
  });
}
