import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../classes/models/models.dart';
import '../../classes/providers/providers.dart';
import '../models/mcq_manage.dart';
import '../providers/mcq_manage_provider.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen to copy a quiz to another class.
class McqCopyScreen extends ConsumerStatefulWidget {
  final int classId;
  final int quizId;

  const McqCopyScreen({super.key, required this.classId, required this.quizId});

  @override
  ConsumerState<McqCopyScreen> createState() => _McqCopyScreenState();
}

class _McqCopyScreenState extends ConsumerState<McqCopyScreen> {
  int? _selectedClassId;
  bool _isSubmitting = false;
  McqManageQuiz? _quiz;

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(classesProvider);
    final quizAsync = ref.watch(mcqManageListProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Copy Quiz')),
      body: quizAsync.when(
        data: (data) {
          _quiz ??= data.items.where((q) => q.id == widget.quizId).isEmpty
              ? null
              : data.items.firstWhere((q) => q.id == widget.quizId);
          return _buildBody(context, classesState);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(context, userMessage(error)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ClassesState classesState) {
    final classes = classesState.classes ?? const <ClassModel>[];
    final available = classes.where((c) => c.id != widget.classId).toList();

    return ListView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      children: [
        _buildQuizInfo(context),
        const SizedBox(height: 20),
        Text(
          'Copy to class',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 12),
        if (classesState.isLoading && classes.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (available.isEmpty)
          _buildNoClasses(context)
        else
          ...available.map(
            (classModel) => _ClassTile(
              classModel: classModel,
              selected: _selectedClassId == classModel.id,
              onTap: () {
                setState(() => _selectedClassId = classModel.id);
              },
            ),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _selectedClassId == null || _isSubmitting ? null : _copy,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.copy_rounded),
          label: Text(_isSubmitting ? 'Copying…' : 'Copy Quiz'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildQuizInfo(BuildContext context) {
    final quiz = _quiz;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(
        children: [
          const Icon(Icons.quiz_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz?.name ?? 'Quiz',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (quiz != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${quiz.questionCount} questions · ${quiz.topic ?? 'No topic'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClasses(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.class_outlined,
            size: 40,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(height: 8),
          Text(
            'No other classes available to copy to.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
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
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(mcqManageListProvider(widget.classId));
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy() async {
    final targetClassId = _selectedClassId;
    if (targetClassId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final newQuizId = await ref
          .read(mcqManageRepositoryProvider)
          .copyQuiz(widget.quizId, targetClassId);

      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: 'Quiz copied successfully');
      ref.invalidate(mcqManageListProvider(widget.classId));
      ref.invalidate(mcqManageListProvider(targetClassId));
      context.pop();
      if (newQuizId > 0) {
        context.push('/classes/$targetClassId/mcq/manage/$newQuizId/edit');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ClassTile extends StatelessWidget {
  final ClassModel classModel;
  final bool selected;
  final VoidCallback onTap;

  const _ClassTile({
    required this.classModel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: selected ? AppTheme.primaryGreen : AppTheme.lightGreen,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: selected
              ? AppTheme.primaryGreen
              : AppTheme.lightGreen,
          child: Icon(
            selected ? Icons.check_rounded : Icons.class_rounded,
            color: selected ? Colors.white : AppTheme.primaryGreen,
          ),
        ),
        title: Text(
          classModel.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        subtitle: Text(
          '${classModel.code} · ${classModel.displayFormat}',
          style: const TextStyle(color: AppTheme.mediumText),
        ),
        trailing: selected
            ? const Icon(
                Icons.radio_button_checked_rounded,
                color: AppTheme.primaryGreen,
              )
            : const Icon(
                Icons.radio_button_unchecked_rounded,
                color: AppTheme.mediumText,
              ),
      ),
    );
  }
}
