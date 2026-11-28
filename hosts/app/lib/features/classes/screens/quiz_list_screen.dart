import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/class_loading_skeleton.dart';
import '../providers/providers.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen showing all available quizzes for a class with pagination
class QuizListScreen extends ConsumerStatefulWidget {
  final int classId;

  const QuizListScreen({super.key, required this.classId});

  @override
  ConsumerState<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends ConsumerState<QuizListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when user is 200px from the bottom
      ref.read(quizListProvider(widget.classId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizListProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quizzes')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(quizListProvider(widget.classId).notifier).refresh();
        },
        child: _buildBody(quizState),
      ),
    );
  }

  Widget _buildBody(QuizListState state) {
    if (state.isLoading && state.quizzes.isEmpty) {
      return const ClassLoadingSkeleton();
    }

    if (state.error != null && state.quizzes.isEmpty) {
      return AppErrorView(
        error: state.loadFailure ?? state.error!,
        onRetry: () =>
            ref.read(quizListProvider(widget.classId).notifier).refresh(),
      );
    }

    if (state.quizzes.isEmpty) {
      return _EmptyState();
    }

    return _QuizListContent(state: state, scrollController: _scrollController);
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 80, color: AppTheme.lightText),
            const SizedBox(height: 16),
            Text(
              'No Quizzes Available',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new quizzes from your teacher.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizListContent extends StatelessWidget {
  final QuizListState state;
  final ScrollController scrollController;

  const _QuizListContent({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final pendingQuizzes = state.pendingQuizzes;
    final completedQuizzes = state.completedQuizzes;

    return ListView(
      controller: scrollController,
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      children: [
        // Pending Quizzes Section
        if (pendingQuizzes.isNotEmpty) ...[
          _SectionHeader(
            title: 'Available Quizzes',
            subtitle:
                '${pendingQuizzes.length} quiz${pendingQuizzes.length > 1 ? 'zes' : ''} to complete',
            icon: Icons.pending_actions,
            color: AppTheme.accentGold,
          ),
          const SizedBox(height: 12),
          ...pendingQuizzes.map(
            (quiz) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuizCard(
                title: quiz.name,
                topic: quiz.topic,
                questionCount: quiz.questionCount,
                status: QuizCardStatus.available,
                onTap: () => context.push('/quizzes/${quiz.id}'),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Completed Quizzes Section
        if (completedQuizzes.isNotEmpty) ...[
          _SectionHeader(
            title: 'Completed Quizzes',
            subtitle:
                '${completedQuizzes.length} quiz${completedQuizzes.length > 1 ? 'zes' : ''} completed',
            icon: Icons.check_circle_outline,
            color: AppTheme.successGreen,
          ),
          const SizedBox(height: 12),
          ...completedQuizzes.map(
            (quiz) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuizCard(
                title: quiz.name,
                topic: quiz.topic,
                questionCount: quiz.questionCount,
                status: QuizCardStatus.completed,
                score: quiz.score,
                total: quiz.total,
                percent: quiz.percent,
                onTap: () => context.push('/quizzes/${quiz.id}/result'),
              ),
            ),
          ),
        ],

        // Loading more indicator
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),

        // Show "no more quizzes" if we've loaded everything
        if (!state.hasMore && state.quizzes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No more quizzes',
                style: TextStyle(color: AppTheme.mediumText),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
