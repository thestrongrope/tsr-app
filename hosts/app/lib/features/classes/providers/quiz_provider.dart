import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../models/models.dart';
import '../repositories/classes_repository.dart';
import 'classes_provider.dart';

// ============ Quiz List State with Pagination ============

class QuizListState {
  final List<Quiz> quizzes;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  /// The exception behind [error], so the screen can say what went wrong.
  final Object? loadFailure;

  const QuizListState({
    this.quizzes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
    this.loadFailure,
  });

  QuizListState copyWith({
    List<Quiz>? quizzes,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    Object? loadFailure,
  }) {
    return QuizListState(
      quizzes: quizzes ?? this.quizzes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      loadFailure: loadFailure,
    );
  }

  /// Get pending (not attempted) quizzes
  List<Quiz> get pendingQuizzes => quizzes.where((q) => !q.attempted).toList();

  /// Get completed quizzes
  List<Quiz> get completedQuizzes => quizzes.where((q) => q.attempted).toList();
}

class QuizListNotifier extends StateNotifier<QuizListState> {
  final ClassesRepository _repository;
  final int _classId;

  QuizListNotifier(this._repository, this._classId)
    : super(const QuizListState());

  Future<void> loadInitial() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getClassQuizzes(_classId, page: 1);
      state = state.copyWith(
        quizzes: response.items,
        isLoading: false,
        hasMore: response.hasNext,
        currentPage: 1,
      );
    } catch (e) {
      debugPrint('Error loading quizzes: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        loadFailure: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getClassQuizzes(
        _classId,
        page: nextPage,
      );
      state = state.copyWith(
        quizzes: [...state.quizzes, ...response.items],
        isLoadingMore: false,
        hasMore: response.hasNext,
        currentPage: nextPage,
      );
    } catch (e) {
      debugPrint('Error loading more quizzes: $e');
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = const QuizListState(); // Reset state
    await loadInitial();
  }
}

final quizListProvider = StateNotifierProvider.autoDispose
    .family<QuizListNotifier, QuizListState, int>((ref, classId) {
      final repository = ref.watch(classesRepositoryProvider);
      final notifier = QuizListNotifier(repository, classId);
      // Auto-load initial data
      notifier.loadInitial();
      return notifier;
    });

// ============ Quiz Detail Provider ============

final quizDetailProvider = FutureProvider.autoDispose.family<Quiz, int>((
  ref,
  quizId,
) async {
  final repository = ref.watch(classesRepositoryProvider);
  return repository.getQuizDetail(quizId);
});

// ============ Quiz History Provider ============

final classQuizHistoryProvider = FutureProvider.autoDispose
    .family<List<QuizScoreHistory>, ClassPerformanceFilter>((
      ref,
      filter,
    ) async {
      ref.keepAlive();
      final repository = ref.watch(classesRepositoryProvider);
      return repository.getClassQuizHistory(
        filter.classId,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
    }, retry: (_, _) => null);

// ============ Quiz Score Provider (for viewing completed quizzes) ============

final quizScoreProvider = FutureProvider.autoDispose
    .family<QuizSubmitResponse, int>((ref, quizId) async {
      final repository = ref.watch(classesRepositoryProvider);
      final response = await repository.getQuizScore(quizId);
      return QuizSubmitResponse(
        total: response['total'] as int,
        answered: response['answered'] as int,
        correct: response['correct'] as int,
        percent: (response['percent'] as num).toDouble(),
        responses: (response['responses'] as List)
            .map(
              (e) => QuizResponseResult(
                questionId: e['questionId'] as int,
                // 'selected' comes as String from backend, parse it to int
                selected: int.tryParse(e['selected'].toString()) ?? 0,
                isCorrect: (e['isCorrect'] is int)
                    ? e['isCorrect'] as int
                    : (int.tryParse(e['isCorrect'].toString()) ?? 0),
                questionText: e['questionText'] as String?,
                selectedText: e['selectedText'] as String?,
                correctText: e['correctText'] as String?,
              ),
            )
            .toList(),
      );
    }, retry: (_, _) => null);

// ============ Quiz Taking State with Progressive Loading ============

class QuizTakingState {
  final int quizId;
  final List<QuizQuestion> questions;
  final Map<int, int> answers; // questionId -> selected option index (1-based)
  final Map<int, String> answersText; // questionId -> selected option text
  final int currentQuestionIndex;
  final bool isSubmitting;
  final bool isLoadingQuestions;
  final bool hasMoreQuestions;
  final int totalQuestionCount;
  final int questionsPage;
  final QuizSubmitResponse? result;
  final String? error;

  /// The exception behind [error], so the screen can say what went wrong.
  final Object? loadFailure;

  const QuizTakingState({
    required this.quizId,
    this.questions = const [],
    this.answers = const {},
    this.answersText = const {},
    this.currentQuestionIndex = 0,
    this.isSubmitting = false,
    this.isLoadingQuestions = false,
    this.hasMoreQuestions = true,
    this.totalQuestionCount = 0,
    this.questionsPage = 0,
    this.result,
    this.error,
    this.loadFailure,
  });

  QuizTakingState copyWith({
    int? quizId,
    List<QuizQuestion>? questions,
    Map<int, int>? answers,
    Map<int, String>? answersText,
    int? currentQuestionIndex,
    bool? isSubmitting,
    bool? isLoadingQuestions,
    bool? hasMoreQuestions,
    int? totalQuestionCount,
    int? questionsPage,
    QuizSubmitResponse? result,
    String? error,
    Object? loadFailure,
  }) {
    return QuizTakingState(
      quizId: quizId ?? this.quizId,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      answersText: answersText ?? this.answersText,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingQuestions: isLoadingQuestions ?? this.isLoadingQuestions,
      hasMoreQuestions: hasMoreQuestions ?? this.hasMoreQuestions,
      totalQuestionCount: totalQuestionCount ?? this.totalQuestionCount,
      questionsPage: questionsPage ?? this.questionsPage,
      result: result ?? this.result,
      error: error,
      loadFailure: loadFailure,
    );
  }

  QuizQuestion? get currentQuestion =>
      questions.isNotEmpty && currentQuestionIndex < questions.length
      ? questions[currentQuestionIndex]
      : null;

  bool get isFirstQuestion => currentQuestionIndex == 0;
  bool get isLastQuestion => currentQuestionIndex >= totalQuestionCount - 1;
  int get answeredCount => answers.length;
  int get totalQuestions => totalQuestionCount;
  double get progress =>
      totalQuestions > 0 ? answeredCount / totalQuestions : 0;
  bool get isCompleted => result != null;
  bool get canSubmit =>
      answeredCount == totalQuestions && !isSubmitting && totalQuestions > 0;

  /// Check if we need to load more questions (approaching end of loaded questions)
  bool get shouldLoadMore =>
      hasMoreQuestions &&
      !isLoadingQuestions &&
      currentQuestionIndex >= questions.length - 3;
}

class QuizTakingNotifier extends StateNotifier<QuizTakingState> {
  final ClassesRepository _repository;
  final Ref _ref;
  static const int _pageSize = 20;

  QuizTakingNotifier(this._repository, this._ref, int quizId)
    : super(QuizTakingState(quizId: quizId));

  Future<void> loadQuestions() async {
    // Don't reload if questions are already loaded or quiz is completed
    if (state.questions.isNotEmpty || state.result != null) {
      debugPrint(
        'Quiz questions already loaded or quiz completed, skipping load',
      );
      return;
    }

    state = state.copyWith(isLoadingQuestions: true, error: null);

    try {
      final response = await _repository.getQuizQuestions(
        state.quizId,
        page: 1,
        pageSize: _pageSize,
      );
      state = state.copyWith(
        questions: response.items,
        isLoadingQuestions: false,
        totalQuestionCount: response.total,
        questionsPage: 1,
        hasMoreQuestions: response.items.length < response.total,
      );
    } catch (e) {
      debugPrint('Error loading questions: $e');
      state = state.copyWith(
        isLoadingQuestions: false,
        error: e.toString(),
        loadFailure: e,
      );
    }
  }

  Future<void> loadMoreQuestions() async {
    if (!state.hasMoreQuestions || state.isLoadingQuestions) return;

    state = state.copyWith(isLoadingQuestions: true);

    try {
      final nextPage = state.questionsPage + 1;
      final response = await _repository.getQuizQuestions(
        state.quizId,
        page: nextPage,
        pageSize: _pageSize,
      );
      state = state.copyWith(
        questions: [...state.questions, ...response.items],
        isLoadingQuestions: false,
        questionsPage: nextPage,
        hasMoreQuestions:
            state.questions.length + response.items.length < response.total,
      );
    } catch (e) {
      debugPrint('Error loading more questions: $e');
      state = state.copyWith(isLoadingQuestions: false);
    }
  }

  void selectAnswer(int questionId, int optionIndex, String optionText) {
    final newAnswers = Map<int, int>.from(state.answers);
    newAnswers[questionId] = optionIndex;

    final newAnswersText = Map<int, String>.from(state.answersText);
    newAnswersText[questionId] = optionText;

    state = state.copyWith(
      answers: newAnswers,
      answersText: newAnswersText,
      error: null,
    );
  }

  void nextQuestion() {
    if (!state.isLastQuestion) {
      final newIndex = state.currentQuestionIndex + 1;
      state = state.copyWith(currentQuestionIndex: newIndex);

      // Load more questions if approaching end of loaded questions
      if (state.shouldLoadMore) {
        loadMoreQuestions();
      }
    }
  }

  void previousQuestion() {
    if (!state.isFirstQuestion) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  void goToQuestion(int index) {
    if (index >= 0 && index < state.totalQuestionCount) {
      state = state.copyWith(currentQuestionIndex: index);

      // Load more questions if needed
      if (state.shouldLoadMore) {
        loadMoreQuestions();
      }
    }
  }

  Future<bool> submitQuiz() async {
    if (!state.canSubmit) return false;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final responses = state.answers.entries
          .map(
            (e) => {
              'questionId': e.key,
              'option': e.value,
              'selectedText': state.answersText[e.key] ?? '',
            },
          )
          .toList();

      final result = await _repository.submitQuiz(state.quizId, responses);
      state = state.copyWith(isSubmitting: false, result: result);

      // Invalidate quiz providers to refresh data
      _ref.invalidate(quizListProvider);
      _ref.invalidate(quizDetailProvider);
      _ref.invalidate(classQuizHistoryProvider);

      return true;
    } catch (e) {
      debugPrint('Error submitting quiz: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = QuizTakingState(quizId: state.quizId);
  }
}

final quizTakingProvider = StateNotifierProvider.autoDispose
    .family<QuizTakingNotifier, QuizTakingState, int>((ref, quizId) {
      final repository = ref.watch(classesRepositoryProvider);
      return QuizTakingNotifier(repository, ref, quizId);
    });
