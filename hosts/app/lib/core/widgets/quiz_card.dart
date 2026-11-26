import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Status indicator for quizzes
enum QuizCardStatus { available, completed, locked }

/// A card displaying quiz information with status indicator.
/// Used in quiz list screens.
class QuizCard extends StatelessWidget {
  final String title;
  final int questionCount;
  final String? topic;
  final QuizCardStatus status;
  final int? score;
  final int? total;
  final double? percent;
  final VoidCallback? onTap;

  const QuizCard({
    super.key,
    required this.title,
    required this.questionCount,
    this.topic,
    required this.status,
    this.score,
    this.total,
    this.percent,
    this.onTap,
  });

  bool get isCompleted => status == QuizCardStatus.completed;
  bool get isLocked => status == QuizCardStatus.locked;
  bool get isAvailable => status == QuizCardStatus.available;

  Color get _statusColor {
    switch (status) {
      case QuizCardStatus.completed:
        return AppTheme.successGreen;
      case QuizCardStatus.locked:
        return AppTheme.lightText;
      case QuizCardStatus.available:
        return AppTheme.primaryGreen;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case QuizCardStatus.completed:
        return Icons.check_circle;
      case QuizCardStatus.locked:
        return Icons.lock;
      case QuizCardStatus.available:
        return Icons.quiz;
    }
  }

  String get _statusText {
    switch (status) {
      case QuizCardStatus.completed:
        return 'Completed';
      case QuizCardStatus.locked:
        return 'Locked';
      case QuizCardStatus.available:
        return 'Available';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_statusIcon, color: _statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isLocked ? Colors.grey : null,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$questionCount questions',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.mediumText),
                            ),
                            if (topic != null) ...[
                              const Text(' • '),
                              Text(
                                topic!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.mediumText),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isCompleted && score != null && total != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$score / $total (${percent?.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isAvailable)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.mediumText,
                    )
                  else if (isCompleted)
                    Icon(
                      Icons.visibility,
                      size: 16,
                      color: AppTheme.successGreen,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
