import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/providers.dart';
import '../../../core/utils/user_message.dart';

/// Screen for taking a quiz - question by question
class QuizTakingScreen extends ConsumerStatefulWidget {
  final int quizId;

  const QuizTakingScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends ConsumerState<QuizTakingScreen> {
  bool _isSubmitting = false;
  bool _checkedAttemptStatus = false;

  @override
  void initState() {
    super.initState();
    // Check if quiz was already attempted and load questions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadQuiz();
    });
  }

  Future<void> _checkAndLoadQuiz() async {
    // First check if quiz is already attempted via quiz detail
    final quizDetail = await ref.read(quizDetailProvider(widget.quizId).future);

    if (!mounted) return;

    // If attempted AND score > 0, redirect to results.
    // If score is 0 (or null), we allow retaking.
    if (quizDetail.attempted && (quizDetail.score ?? 0) > 0) {
      // Quiz already attempted, redirect to results
      context.go('/quizzes/${widget.quizId}/result');
      return;
    }

    setState(() => _checkedAttemptStatus = true);

    // Load questions for new attempt
    ref.read(quizTakingProvider(widget.quizId).notifier).loadQuestions();
  }

  Future<void> _handleSubmit() async {
    final quizState = ref.read(quizTakingProvider(widget.quizId));

    // Check if all questions are answered
    final unansweredCount =
        quizState.questions.length - quizState.answers.length;

    if (unansweredCount > 0) {
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit Quiz?'),
          content: Text(
            'You have $unansweredCount unanswered question${unansweredCount > 1 ? 's' : ''}. Are you sure you want to submit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue Quiz'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit Anyway'),
            ),
          ],
        ),
      );

      if (shouldSubmit != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(quizTakingProvider(widget.quizId).notifier).submitQuiz();

      if (mounted) {
        // Navigate to result screen
        context.go('/quizzes/${widget.quizId}/result');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit quiz: ${userMessage(e)}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizTakingProvider(widget.quizId));
    final quizDetailAsync = ref.watch(quizDetailProvider(widget.quizId));

    // Show loading while checking attempt status
    if (!_checkedAttemptStatus) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Quiz...')),
        body: const ClassLoadingSkeleton(),
      );
    }

    if (quizState.questions.isEmpty && quizState.error == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Quiz...')),
        body: const ClassLoadingSkeleton(),
      );
    }

    if (quizState.error != null && quizState.questions.isEmpty) {
      // Check if error is about quiz already attempted (409 Conflict)
      final isAlreadyAttempted =
          quizState.error?.contains('409') == true ||
          quizState.error?.contains('already attempted') == true ||
          quizState.error?.contains('Cannot retake') == true;

      if (isAlreadyAttempted) {
        // Redirect to results
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/quizzes/${widget.quizId}/result');
          }
        });
        return Scaffold(
          appBar: AppBar(title: const Text('Quiz')),
          body: const ClassLoadingSkeleton(),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: AppErrorView(
          error: quizState.loadFailure ?? quizState.error ?? 'Unknown error',
          onRetry: () => ref
              .read(quizTakingProvider(widget.quizId).notifier)
              .loadQuestions(),
        ),
      );
    }

    final currentQuestion = quizState.currentQuestion;
    if (currentQuestion == null) {
      // If we're still loading questions and at an index beyond loaded questions
      if (quizState.isLoadingQuestions) {
        return Scaffold(
          appBar: AppBar(title: const Text('Loading...')),
          body: const ClassLoadingSkeleton(),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('No questions available')),
      );
    }

    final quizName = quizDetailAsync.when(
      data: (quiz) => quiz.name,
      loading: () => 'Quiz',
      error: (_, _) => 'Quiz',
    );
    final totalQuestions = quizState.totalQuestions; // Use total from API
    final currentIndex = quizState.currentQuestionIndex + 1;
    final progress = totalQuestions > 0 ? currentIndex / totalQuestions : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(quizName),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          _QuizProgressBar(
            currentQuestion: currentIndex,
            totalQuestions: totalQuestions,
            progress: progress,
          ),

          // Question Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Number Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Question $currentIndex',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Question Text
                  Text(
                    currentQuestion.text,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...currentQuestion.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected =
                        quizState.answers[currentQuestion.id] == index;

                    return _OptionCard(
                      label: _getOptionLabel(index),
                      text: option,
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(quizTakingProvider(widget.quizId).notifier)
                            .selectAnswer(currentQuestion.id, index, option);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),

          // Navigation Buttons
          _NavigationButtons(
            currentIndex: quizState.currentQuestionIndex,
            totalQuestions: totalQuestions,
            isSubmitting: _isSubmitting,
            onPrevious: () {
              ref
                  .read(quizTakingProvider(widget.quizId).notifier)
                  .previousQuestion();
            },
            onNext: () {
              ref
                  .read(quizTakingProvider(widget.quizId).notifier)
                  .nextQuestion();
            },
            onSubmit: _handleSubmit,
          ),
        ],
      ),
    );
  }

  String _getOptionLabel(int index) {
    return String.fromCharCode(65 + index); // A, B, C, D...
  }

  Future<void> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Quiz'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      context.pop();
    }
  }
}

class _QuizProgressBar extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final double progress;

  const _QuizProgressBar({
    required this.currentQuestion,
    required this.totalQuestions,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentQuestion of $totalQuestions',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.lightGreen.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? AppTheme.primaryGreen.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryGreen
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: AppTheme.primaryGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationButtons extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final bool isSubmitting;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _NavigationButtons({
    required this.currentIndex,
    required this.totalQuestions,
    required this.isSubmitting,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  bool get isFirstQuestion => currentIndex == 0;
  bool get isLastQuestion => currentIndex == totalQuestions - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Previous Button
            if (!isFirstQuestion)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else
              const Spacer(),

            const SizedBox(width: 16),

            // Next / Submit Button
            Expanded(
              child: isLastQuestion
                  ? ElevatedButton.icon(
                      onPressed: isSubmitting ? null : onSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(isSubmitting ? 'Submitting...' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
