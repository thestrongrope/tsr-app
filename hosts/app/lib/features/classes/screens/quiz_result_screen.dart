import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/providers.dart';

/// Screen showing quiz results after completion
class QuizResultScreen extends ConsumerWidget {
  final int quizId;

  const QuizResultScreen({super.key, required this.quizId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizTakingProvider(quizId));
    final quizDetailAsync = ref.watch(quizDetailProvider(quizId));

    // First check if we have a result from just-submitted quiz
    final submitResponse = quizState.result;

    // If no submit response, this is viewing a previously completed quiz
    // Fetch the score from the API
    if (submitResponse == null) {
      final scoreAsync = ref.watch(quizScoreProvider(quizId));

      return scoreAsync.when(
        data: (score) =>
            _buildResultContent(context, ref, score, quizDetailAsync),
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Result')),
          body: const ClassLoadingSkeleton(),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Result')),
          body: AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(quizScoreProvider(quizId)),
          ),
        ),
      );
    }

    return _buildResultContent(context, ref, submitResponse, quizDetailAsync);
  }

  Widget _buildResultContent(
    BuildContext context,
    WidgetRef ref,
    QuizSubmitResponse result,
    AsyncValue<Quiz?> quizDetailAsync,
  ) {
    final score = result.correct;
    final total = result.total;
    final percent = result.percent;
    final quizName = quizDetailAsync.when(
      data: (quiz) => quiz?.name ?? 'Quiz',
      loading: () => 'Quiz',
      error: (_, _) => 'Quiz',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Go back to classes list instead of popping to quiz taking screen
        context.go('/classes');
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _getGradeColor(percent).withValues(alpha: 0.2),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Result Icon
                  _ResultIcon(percent: percent),

                  const SizedBox(height: 24),

                  // Quiz Name
                  Text(
                    quizName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.mediumText,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Grade Text
                  Text(
                    _getGradeText(percent),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _getGradeColor(percent),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Score Card
                  _ScoreCard(score: score, total: total, percent: percent),

                  const SizedBox(height: 24),

                  // Stats Row
                  _StatsRow(correct: score, incorrect: total - score),

                  const SizedBox(height: 32),

                  // Feedback Message
                  _FeedbackCard(percent: percent),

                  const SizedBox(height: 32),

                  // Action Buttons
                  _ActionButtons(
                    onGoBack: () {
                      // Clear the quiz state and go back
                      context.go('/classes');
                    },
                    onViewAnswers: () => _showAnswers(context, result),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAnswers(BuildContext context, QuizSubmitResponse result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnswersSheet(result: result),
    );
  }

  Color _getGradeColor(double percent) {
    if (percent >= 80) return AppTheme.successGreen;
    if (percent >= 60) return Colors.orange.shade600;
    if (percent >= 40) return Colors.amber.shade700;
    return AppTheme.errorRed;
  }

  String _getGradeText(double percent) {
    if (percent >= 90) return 'Excellent!';
    if (percent >= 80) return 'Great Job!';
    if (percent >= 70) return 'Good Work!';
    if (percent >= 60) return 'Not Bad!';
    if (percent >= 40) return 'Keep Trying!';
    return 'Need Improvement';
  }
}

class _ResultIcon extends StatelessWidget {
  final double percent;

  const _ResultIcon({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(icon, size: 64, color: color),
    );
  }

  Color _getColor() {
    if (percent >= 70) return AppTheme.successGreen;
    if (percent >= 50) return Colors.orange.shade600;
    return AppTheme.errorRed;
  }

  IconData _getIcon() {
    if (percent >= 70) return Icons.emoji_events;
    if (percent >= 50) return Icons.thumb_up;
    return Icons.school;
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  final int total;
  final double percent;

  const _ScoreCard({
    required this.score,
    required this.total,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              'Your Score',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppTheme.mediumText),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$score',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' / $total',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getPercentColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _getPercentColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPercentColor() {
    if (percent >= 70) return AppTheme.successGreen;
    if (percent >= 50) return Colors.orange.shade600;
    return AppTheme.errorRed;
  }
}

class _StatsRow extends StatelessWidget {
  final int correct;
  final int incorrect;

  const _StatsRow({required this.correct, required this.incorrect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.check_circle,
            label: 'Correct',
            value: '$correct',
            color: AppTheme.successGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatItem(
            icon: Icons.cancel,
            label: 'Incorrect',
            value: '$incorrect',
            color: AppTheme.errorRed,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final double percent;

  const _FeedbackCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: AppTheme.accentGold, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _getFeedbackMessage(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }

  String _getFeedbackMessage() {
    if (percent >= 90) {
      return 'MashaAllah! Outstanding performance! Keep up the excellent work.';
    }
    if (percent >= 80) {
      return 'Great job! Your dedication to learning is commendable.';
    }
    if (percent >= 70) {
      return 'Good work! A little more practice will help you excel.';
    }
    if (percent >= 60) {
      return 'Not bad! Review the topics you missed and try again.';
    }
    if (percent >= 40) {
      return 'Keep trying! Focus on understanding the concepts better.';
    }
    return 'Don\'t give up! Review the material and practice more.';
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onGoBack;
  final VoidCallback onViewAnswers;

  const _ActionButtons({required this.onGoBack, required this.onViewAnswers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onViewAnswers,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('View Answers'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onGoBack,
            icon: const Icon(Icons.home),
            label: const Text('Back to Classes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswersSheet extends StatelessWidget {
  final QuizSubmitResponse result;

  const _AnswersSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Quiz Answers',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: result.responses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = result.responses[index];
                final isCorrect = item.isCorrect == 1;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isCorrect
                                          ? AppTheme.successGreen
                                          : AppTheme.errorRed)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Question ${index + 1}',
                              style: TextStyle(
                                color: isCorrect
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect
                                ? AppTheme.successGreen
                                : AppTheme.errorRed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Question Text
                      if (item.questionText != null) ...[
                        Text(
                          item.questionText!,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Text(
                        'Your Answer:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.selectedText ?? 'No answer',
                        style: TextStyle(
                          color: isCorrect
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      if (!isCorrect && item.correctText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Correct Answer:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.mediumText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.correctText!,
                          style: const TextStyle(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
