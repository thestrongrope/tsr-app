import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/mcq_manage.dart';
import '../providers/mcq_manage_provider.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen showing the Standard MCQs library for a class, grouped by topic
/// then subject, with one-tap copy into the class.
class McqStandardScreen extends ConsumerStatefulWidget {
  final int classId;

  const McqStandardScreen({super.key, required this.classId});

  @override
  ConsumerState<McqStandardScreen> createState() => _McqStandardScreenState();
}

class _McqStandardScreenState extends ConsumerState<McqStandardScreen> {
  final Set<int> _copyingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedTopic;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final standardAsync = ref.watch(mcqStandardProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Standard MCQs')),
      body: standardAsync.when(
        data: (data) => _McqStandardBody(
          classId: widget.classId,
          data: data,
          copyingIds: _copyingIds,
          onCopy: _copyStandard,
          searchController: _searchController,
          query: _query,
          selectedTopic: _selectedTopic,
          onQueryChanged: (value) => setState(() => _query = value),
          onTopicSelected: (topic) => setState(() => _selectedTopic = topic),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _McqStandardErrorState(
          error: userMessage(error),
          onRetry: () => ref.invalidate(mcqStandardProvider(widget.classId)),
          onCreateCustom: () => context.pushReplacement(
            '/classes/${widget.classId}/mcq/manage/add',
          ),
        ),
      ),
    );
  }

  Future<void> _copyStandard(McqStandardQuiz quiz) async {
    if (_copyingIds.contains(quiz.id)) return;
    setState(() => _copyingIds.add(quiz.id));

    try {
      final newQuizId = await ref
          .read(mcqManageRepositoryProvider)
          .copyStandardQuiz(widget.classId, quiz.id);

      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: '"${quiz.displayName}" copied to your class',
      );
      ref.invalidate(mcqStandardProvider(widget.classId));
      ref.invalidate(mcqManageListProvider(widget.classId));
      if (newQuizId > 0) {
        context.push('/classes/${widget.classId}/mcq/manage/$newQuizId/edit');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    } finally {
      if (mounted) setState(() => _copyingIds.remove(quiz.id));
    }
  }
}

class _McqStandardBody extends StatelessWidget {
  final int classId;
  final McqStandardResponse data;
  final Set<int> copyingIds;
  final ValueChanged<McqStandardQuiz> onCopy;
  final TextEditingController searchController;
  final String query;
  final String? selectedTopic;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onTopicSelected;

  const _McqStandardBody({
    required this.classId,
    required this.data,
    required this.copyingIds,
    required this.onCopy,
    required this.searchController,
    required this.query,
    required this.selectedTopic,
    required this.onQueryChanged,
    required this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTopics = _filterTopics(data.topics);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          _buildHeader(context),
          if (data.topics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('create_custom_mcq'),
                onPressed: () => _openCustomForm(context),
                child: const Text('Cannot find one? Create a custom MCQ'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildSearchField(context),
          if (data.topics.length > 1) ...[
            const SizedBox(height: 12),
            _buildTopicFilter(context),
          ],
          const SizedBox(height: 16),
          if (data.topics.isEmpty)
            _buildEmptyState(context)
          else if (filteredTopics.isEmpty)
            _buildNoMatchState(context)
          else
            ...filteredTopics.map(
              (topic) => _TopicSection(
                topic: topic,
                copyingIds: copyingIds,
                onCopy: onCopy,
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Replaces the library with the custom form, so saving returns to the
  /// MCQ list rather than back to the library.
  void _openCustomForm(BuildContext context) {
    context.pushReplacement('/classes/$classId/mcq/manage/add');
  }

  /// Filters topics → subjects → quizzes by the search query and topic chip.
  List<McqStandardTopic> _filterTopics(List<McqStandardTopic> topics) {
    final q = query.trim().toLowerCase();
    final result = <McqStandardTopic>[];

    for (final topic in topics) {
      if (selectedTopic != null && topic.topic != selectedTopic) continue;

      final subjects = <McqStandardSubject>[];
      for (final subject in topic.subjects) {
        final quizzes = subject.quizzes.where((quiz) {
          if (q.isEmpty) return true;
          return quiz.topic.toLowerCase().contains(q) ||
              quiz.subject.toLowerCase().contains(q) ||
              quiz.lesson.toLowerCase().contains(q) ||
              quiz.name.toLowerCase().contains(q) ||
              quiz.displayName.toLowerCase().contains(q);
        }).toList();
        if (quizzes.isNotEmpty) {
          subjects.add(
            McqStandardSubject(subject: subject.subject, quizzes: quizzes),
          );
        }
      }
      if (subjects.isNotEmpty) {
        result.add(McqStandardTopic(topic: topic.topic, subjects: subjects));
      }
    }
    return result;
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: searchController,
      onChanged: onQueryChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by topic, subject or lesson…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  searchController.clear();
                  onQueryChanged('');
                },
              ),
        filled: true,
        fillColor: AppTheme.cardBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: BorderSide(color: AppTheme.lightGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTopicFilter(BuildContext context) {
    final topics = data.topics.map((t) => t.topic).toList();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TopicChip(
              label: 'All',
              selected: selectedTopic == null,
              onTap: () => onTopicSelected(null),
            );
          }
          final topic = topics[index - 1];
          return _TopicChip(
            label: topic,
            selected: selectedTopic == topic,
            onTap: () => onTopicSelected(topic),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius2XL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(
              Icons.library_books_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Standard MCQs Library',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready-made quizzes — copy one into your class',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.library_books_outlined,
            size: 56,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(height: 16),
          Text(
            'No standard MCQs available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There is no Standard MCQ for this class yet.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('create_custom_mcq'),
            onPressed: () => _openCustomForm(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a custom MCQ'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 56,
            color: AppTheme.mediumText,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching MCQs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or clear the topic filter.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : AppTheme.lightGreen,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.mediumText,
          ),
        ),
      ),
    );
  }
}

class _TopicSection extends StatelessWidget {
  final McqStandardTopic topic;
  final Set<int> copyingIds;
  final ValueChanged<McqStandardQuiz> onCopy;

  const _TopicSection({
    required this.topic,
    required this.copyingIds,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                topic.topic,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
        ),
        ...topic.subjects.map(
          (subject) => _SubjectSection(
            subject: subject,
            copyingIds: copyingIds,
            onCopy: onCopy,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SubjectSection extends StatelessWidget {
  final McqStandardSubject subject;
  final Set<int> copyingIds;
  final ValueChanged<McqStandardQuiz> onCopy;

  const _SubjectSection({
    required this.subject,
    required this.copyingIds,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              subject.subject,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          ...subject.quizzes.map(
            (quiz) => _StandardQuizCard(
              quiz: quiz,
              copying: copyingIds.contains(quiz.id),
              onCopy: () => onCopy(quiz),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardQuizCard extends StatelessWidget {
  final McqStandardQuiz quiz;
  final bool copying;
  final VoidCallback onCopy;

  const _StandardQuizCard({
    required this.quiz,
    required this.copying,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: quiz.copied
              ? AppTheme.successGreen.withValues(alpha: 0.4)
              : AppTheme.lightGreen,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(
              Icons.quiz_outlined,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${quiz.questionCount} questions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (quiz.copied)
            const _CopiedBadge()
          else
            FilledButton.tonalIcon(
              onPressed: copying ? null : onCopy,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: copying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.copy_rounded, size: 16),
              label: Text(copying ? 'Copying…' : 'Copy'),
            ),
        ],
      ),
    );
  }
}

class _CopiedBadge extends StatelessWidget {
  const _CopiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppTheme.successGreen,
          ),
          SizedBox(width: 4),
          Text(
            'Copied',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.successGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _McqStandardErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  /// The library is only one way to make an MCQ; a failed load must not
  /// block writing one's own.
  final VoidCallback onCreateCustom;

  const _McqStandardErrorState({
    required this.error,
    required this.onRetry,
    required this.onCreateCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load standard MCQs',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('create_custom_mcq'),
              onPressed: onCreateCustom,
              child: const Text('Create a custom MCQ instead'),
            ),
          ],
        ),
      ),
    );
  }
}
