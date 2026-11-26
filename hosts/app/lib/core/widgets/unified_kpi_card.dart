import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A unified KPI card that displays overall performance metrics
/// in a beautiful, compact card that can be tapped to see detailed view.
class UnifiedKpiCard extends StatelessWidget {
  final double? attendancePercent;
  final double? quizAverage;
  final int? quizzesAttempted;
  final int? totalRecitation;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? error;

  const UnifiedKpiCard({
    super.key,
    this.attendancePercent,
    this.quizAverage,
    this.quizzesAttempted,
    this.totalRecitation,
    this.onTap,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState(context);
    }

    if (error != null) {
      return _buildErrorState(context);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGreen,
              AppTheme.primaryGreen.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'My Performance',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Overall Score Ring
                    Row(
                      children: [
                        _buildOverallScore(context),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _KpiMiniStat(
                                icon: Icons.calendar_today_rounded,
                                label: 'Attendance',
                                value: attendancePercent != null
                                    ? '${attendancePercent!.toStringAsFixed(0)}%'
                                    : '--',
                                color: _getAttendanceColor(),
                              ),
                              const SizedBox(height: 12),
                              _KpiMiniStat(
                                icon: Icons.quiz_rounded,
                                label: 'Quiz Avg',
                                value: quizAverage != null
                                    ? '${quizAverage!.toStringAsFixed(0)}%'
                                    : '--',
                                color: _getQuizColor(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bottom stats row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _BottomStat(
                            icon: Icons.assignment_turned_in_rounded,
                            value: '${quizzesAttempted ?? 0}',
                            label: 'Quizzes',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          _BottomStat(
                            icon: Icons.menu_book_rounded,
                            value: '${totalRecitation ?? 0}',
                            label: 'Pages Read',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tap hint
                    Center(
                      child: Text(
                        'Tap for detailed view',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallScore(BuildContext context) {
    final overallScore = _calculateOverallScore();
    final scoreColor = _getOverallScoreColor(overallScore);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: overallScore / 100,
              strokeWidth: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                overallScore.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Text(
                'Overall',
                style: TextStyle(fontSize: 10, color: AppTheme.mediumText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateOverallScore() {
    double total = 0;
    int count = 0;

    if (attendancePercent != null) {
      total += attendancePercent!;
      count++;
    }
    if (quizAverage != null) {
      total += quizAverage!;
      count++;
    }

    return count > 0 ? total / count : 0;
  }

  Color _getOverallScoreColor(double score) {
    if (score >= 80) return AppTheme.successGreen;
    if (score >= 60) return Colors.orange.shade600;
    if (score >= 40) return Colors.amber.shade700;
    return AppTheme.errorRed;
  }

  Color _getAttendanceColor() {
    if (attendancePercent == null) return Colors.white;
    if (attendancePercent! >= 80) return Colors.lightGreenAccent;
    if (attendancePercent! >= 60) return Colors.amberAccent;
    return Colors.redAccent.shade100;
  }

  Color _getQuizColor() {
    if (quizAverage == null) return Colors.white;
    if (quizAverage! >= 80) return Colors.lightGreenAccent;
    if (quizAverage! >= 60) return Colors.amberAccent;
    return Colors.redAccent.shade100;
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorRed, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unable to load performance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pull to refresh',
                  style: TextStyle(color: AppTheme.mediumText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiMiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BottomStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
