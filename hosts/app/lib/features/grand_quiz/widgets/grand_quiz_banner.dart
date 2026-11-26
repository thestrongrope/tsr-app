import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quiz_info.dart';
import '../providers/grand_quiz_provider.dart';

/// A beautiful, modern banner widget for Grand/Mega Quiz events
///
/// Displays quiz info with dynamic theming based on API colors,
/// countdown timers, episode progress, and registration actions.
class GrandQuizBanner extends ConsumerStatefulWidget {
  const GrandQuizBanner({super.key});

  @override
  ConsumerState<GrandQuizBanner> createState() => _GrandQuizBannerState();
}

class _GrandQuizBannerState extends ConsumerState<GrandQuizBanner>
    with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Load quiz info on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(grandQuizProvider.notifier).loadQuizInfo();
    });

    // Start countdown timer for live updates
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(grandQuizProvider);
    final quizInfo = quizState.quizInfo;

    // Don't show if no quiz or offline
    if (!quizState.shouldShowBanner || quizInfo == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _QuizBannerCard(
        quizInfo: quizInfo,
        shimmerController: _shimmerController,
        onTap: () => _handleBannerTap(quizInfo),
        onActionTap: () => _handleActionTap(quizInfo),
        actionText: _getActionText(quizInfo),
        actionIcon: _getActionIcon(quizInfo),
      ),
    );
  }

  void _handleBannerTap(QuizInfo quizInfo) {
    // Open YouTube channel for live quizzes
    if (quizInfo.isLive && quizInfo.youtubeUrl != null) {
      _launchUrl(quizInfo.youtubeUrl!);
    }
  }

  void _handleActionTap(QuizInfo quizInfo) {
    final preferredUrl = _resolvePreferredActionUrl(quizInfo);
    if (preferredUrl != null) {
      _launchUrl(preferredUrl);
    }
  }

  String? _resolvePreferredActionUrl(QuizInfo quizInfo) {
    final episodeFormUrl = _resolveEpisodeFormUrl(quizInfo);
    if (episodeFormUrl != null) {
      return episodeFormUrl;
    }
    return quizInfo.youtubeUrl;
  }

  String? _resolveEpisodeFormUrl(QuizInfo quizInfo) {
    // A member the quiz leaves out is not offered the form (#868).
    if (!quizInfo.canTakePart) return null;

    final episode = quizInfo.currentOrNextEpisode;
    final participation = episode?.participation;

    final formId = participation?.formId ?? episode?.formId;
    final formBaseUrl = participation?.formBaseUrl;

    if (formId == null || formId.isEmpty) {
      return null;
    }

    if (formBaseUrl != null && formBaseUrl.isNotEmpty) {
      return formBaseUrl.replaceAll('{form_id}', formId);
    }

    return 'https://docs.google.com/forms/d/e/$formId/viewform';
  }

  IconData _getActionIcon(QuizInfo quizInfo) {
    if (_resolveEpisodeFormUrl(quizInfo) != null) {
      return Icons.description_outlined;
    }
    if (quizInfo.isLive) return Icons.play_arrow_rounded;
    if (quizInfo.isRegistered) return Icons.ondemand_video;
    if (quizInfo.isUpcoming) return Icons.ondemand_video;
    return Icons.arrow_forward_rounded;
  }

  String _getActionText(QuizInfo quizInfo) {
    if (_resolveEpisodeFormUrl(quizInfo) != null) {
      return 'Open Episode Form';
    }
    if (quizInfo.isLive) return 'Watch Live Now';
    if (quizInfo.isRegistered) return 'Go to YouTube Channel';
    if (quizInfo.isUpcoming) return 'Go to YouTube Channel';
    return 'View Details';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

/// The main banner card with all quiz information
class _QuizBannerCard extends StatelessWidget {
  final QuizInfo quizInfo;
  final AnimationController shimmerController;
  final VoidCallback onTap;
  final VoidCallback onActionTap;
  final String actionText;
  final IconData actionIcon;

  const _QuizBannerCard({
    required this.quizInfo,
    required this.shimmerController,
    required this.onTap,
    required this.onActionTap,
    required this.actionText,
    required this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [quizInfo.colors.primary, quizInfo.colors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: quizInfo.colors.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // Main content (this determines the size)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Badge + Status
                    _TopRow(quizInfo: quizInfo),
                    const SizedBox(height: 10),

                    // Quiz name
                    Text(
                      quizInfo.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Description/Dates
                    Text(
                      quizInfo.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // Episode progress for mega quizzes
                    if (quizInfo.isMegaQuiz && quizInfo.episodes != null)
                      _EpisodeProgress(
                        episodes: quizInfo.episodes!,
                        colors: quizInfo.colors,
                      ),

                    if (quizInfo.isMegaQuiz && quizInfo.episodes != null)
                      const SizedBox(height: 10),

                    // Status message
                    _StatusMessage(
                      quizInfo: quizInfo,
                      shimmerController: shimmerController,
                    ),
                    const SizedBox(height: 10),

                    // Action button
                    _ActionButton(
                      quizInfo: quizInfo,
                      onTap: onActionTap,
                      actionIcon: actionIcon,
                      actionText: actionText,
                    ),
                  ],
                ),
              ),

              // Background decorative elements (positioned, won't affect size)
              Positioned.fill(
                child: IgnorePointer(
                  child: _BackgroundDecorations(colors: quizInfo.colors),
                ),
              ),

              // Live indicator overlay
              if (quizInfo.isLive)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _LivePulse(shimmerController: shimmerController),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Background decorative elements
class _BackgroundDecorations extends StatelessWidget {
  final QuizColors colors;

  const _BackgroundDecorations({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Top right circle
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        // Bottom left circle
        Positioned(
          bottom: -30,
          left: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        // Geometric pattern
        Positioned(
          right: 20,
          bottom: 60,
          child: Transform.rotate(
            angle: math.pi / 6,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Top row with quiz type badge and mode
class _TopRow extends StatelessWidget {
  final QuizInfo quizInfo;

  const _TopRow({required this.quizInfo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Quiz type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                quizInfo.isMegaQuiz ? Icons.emoji_events : Icons.star,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                quizInfo.isMegaQuiz ? 'MEGA QUIZ' : 'GRAND QUIZ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Mode badge (Live/etc)
        if (quizInfo.mode.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: quizInfo.isLive
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (quizInfo.isLive) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  quizInfo.isLive ? 'LIVE' : quizInfo.mode.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Episode progress indicator for mega quizzes
class _EpisodeProgress extends StatelessWidget {
  final QuizEpisodes episodes;
  final QuizColors colors;

  const _EpisodeProgress({required this.episodes, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Episode Progress',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${episodes.completedCount}/${episodes.total} completed',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Episode dots
        Row(
          children: List.generate(episodes.total, (index) {
            final episode = episodes.list.length > index
                ? episodes.list[index]
                : null;
            final isCompleted = episode?.isEnded ?? false;
            final isLive = episode?.isLive ?? false;
            final isCurrent = episode?.number == episodes.currentEpisode;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < episodes.total - 1 ? 6 : 0,
                ),
                child: Column(
                  children: [
                    // Episode indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isCompleted
                            ? Colors.white
                            : isLive
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.3),
                        boxShadow: isLive
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Episode number
                    Text(
                      'E${index + 1}',
                      style: TextStyle(
                        color: isCurrent || isLive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                        fontSize: 9,
                        fontWeight: isCurrent || isLive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Status message with countdown or info
class _StatusMessage extends StatelessWidget {
  final QuizInfo quizInfo;
  final AnimationController shimmerController;

  const _StatusMessage({
    required this.quizInfo,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getStatusIcon(), color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusSubtitle(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (quizInfo.status) {
      case 'registered':
        return Icons.check_circle;
      case 'live':
        return Icons.play_circle_fill;
      case 'upcoming':
        return Icons.schedule;
      case 'ended':
        return Icons.emoji_events;
      default:
        return Icons.info;
    }
  }

  String _getStatusTitle() {
    if (!quizInfo.canTakePart && quizInfo.isActive) return 'Quiz Information';
    switch (quizInfo.status) {
      case 'registered':
        return 'You\'re Registered! ✓';
      case 'live':
        return 'Quiz is LIVE Now! 🔴';
      case 'upcoming':
        return 'Registration Open';
      case 'ended':
        return 'Quiz Completed';
      default:
        return 'Quiz Information';
    }
  }

  String _getStatusSubtitle() {
    if (!quizInfo.canTakePart && quizInfo.isActive) {
      return 'You cannot take part in this quiz.';
    }
    // Use the message from API if available
    if (quizInfo.message.isNotEmpty) {
      // Truncate if too long
      return quizInfo.message.length > 100
          ? '${quizInfo.message.substring(0, 100)}...'
          : quizInfo.message;
    }

    switch (quizInfo.status) {
      case 'registered':
        return 'Watch the quiz live on YouTube';
      case 'live':
        return 'Tap to watch on YouTube';
      case 'upcoming':
        return 'Register now to participate';
      case 'ended':
        return 'Thank you for participating';
      default:
        return 'Stay tuned for updates';
    }
  }
}

/// Action button at the bottom
class _ActionButton extends StatelessWidget {
  final QuizInfo quizInfo;
  final VoidCallback onTap;
  final String actionText;
  final IconData actionIcon;

  const _ActionButton({
    required this.quizInfo,
    required this.onTap,
    required this.actionText,
    required this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: quizInfo.colors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(actionIcon, size: 18),
            const SizedBox(width: 8),
            Text(
              actionText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated live pulse indicator
class _LivePulse extends StatelessWidget {
  final AnimationController shimmerController;

  const _LivePulse({required this.shimmerController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, child) {
        final scale =
            1.0 + (math.sin(shimmerController.value * math.pi * 2) * 0.15);
        final opacity =
            0.5 + (math.sin(shimmerController.value * math.pi * 2) * 0.5);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: opacity * 0.6),
                blurRadius: 12 * scale,
                spreadRadius: 2 * scale,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
