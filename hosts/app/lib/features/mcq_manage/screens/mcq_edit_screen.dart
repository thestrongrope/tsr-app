import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/mcq_manage.dart';
import '../providers/mcq_manage_provider.dart';
import '../../../core/utils/user_message.dart';

/// Combined Add/Edit screen for class MCQs.
///
/// In **add** mode, creates a quiz shell (name + topic) then saves questions.
/// In **edit** mode, loads the existing quiz + questions for editing.
/// Supports adding/removing questions with an answer + up to 4 options.
class McqEditScreen extends ConsumerStatefulWidget {
  final int classId;
  final int? quizId; // null = add, non-null = edit

  const McqEditScreen({super.key, required this.classId, this.quizId});

  bool get isEdit => quizId != null;

  @override
  ConsumerState<McqEditScreen> createState() => _McqEditScreenState();
}

class _McqEditScreenState extends ConsumerState<McqEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _scrollController = ScrollController();
  bool _restrictToClass = true;

  // Dynamic question list
  final List<McqManageQuestion> _questions = [];
  final List<GlobalKey<FormFieldState<String>>> _questionKeys = [];

  bool _isSubmitting = false;
  bool _initialized = false;

  // Questions can only be added once a topic is entered; the API rejects a
  // quiz without one.
  bool get _hasTopic => _topicController.text.trim().isNotEmpty;

  String? _validateTopic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a topic';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      return _buildEditMode(context);
    }
    return _buildAddMode(context);
  }

  Widget _buildAddMode(BuildContext context) {
    // Pre-fill topic suggestions from existing topics.
    final topicsAsync = ref.watch(mcqTopicsProvider(widget.classId));
    return _buildScaffold(context, topicsAsync);
  }

  Widget _buildEditMode(BuildContext context) {
    final detailAsync = ref.watch(mcqManageDetailProvider(widget.quizId!));
    return detailAsync.when(
      data: (detail) {
        _initializeFromDetail(detail);
        final topicsAsync = ref.watch(mcqTopicsProvider(widget.classId));
        return _buildScaffold(context, topicsAsync);
      },
      loading: () => _buildLoadingScaffold(context),
      error: (error, _) => _buildErrorScaffold(context, error),
    );
  }

  void _initializeFromDetail(McqManageDetail detail) {
    if (_initialized) return;
    _initialized = true;

    _nameController.text = detail.name;
    _topicController.text = detail.topic ?? '';
    _restrictToClass = detail.restrictToClass == 1;

    _questions
      ..clear()
      ..addAll(detail.questions);
    _questionKeys
      ..clear()
      ..addAll(List.generate(detail.questions.length, (_) => GlobalKey()));
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<List<String>> topicsAsync,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Quiz' : 'New Quiz')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _buildQuizDetailsCard(context, topicsAsync),
              const SizedBox(height: 20),
              _buildQuestionsHeader(context),
              const SizedBox(height: 8),
              if (_questions.isEmpty)
                _buildNoQuestions(context)
              else
                ..._questions.asMap().entries.map(
                  (entry) => _QuestionCard(
                    key: _questionKeys[entry.key],
                    index: entry.key,
                    question: entry.value,
                    onChanged: (q) => _questions[entry.key] = q,
                    onRemove: _questions.length > 1
                        ? () => _removeQuestion(entry.key)
                        : null,
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _hasTopic ? _addQuestion : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: BorderSide(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Question'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _save,
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
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Saving…'
                      : widget.isEdit
                      ? 'Save Changes'
                      : 'Create Quiz',
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizDetailsCard(
    BuildContext context,
    AsyncValue<List<String>> topicsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quiz Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Quiz Name *',
              hintText: 'e.g. Surah Al-Fatiha Quiz',
              prefixIcon: Icon(Icons.quiz_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a quiz name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          topicsAsync.when(
            data: (topics) => Autocomplete<String>(
              initialValue: TextEditingValue(text: _topicController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return topics.where(
                  (t) => t.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              onSelected: (selection) {
                setState(() => _topicController.text = selection);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      // The Autocomplete owns this controller; copy typed text
                      // across so a topic that isn't picked from the list is kept.
                      onChanged: (value) {
                        setState(() => _topicController.text = value);
                      },
                      validator: _validateTopic,
                      decoration: const InputDecoration(
                        labelText: 'Topic *',
                        hintText: 'e.g. Quran, Aqaid, Fiqh…',
                        prefixIcon: Icon(Icons.topic_outlined),
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
            ),
            loading: () => TextFormField(
              controller: _topicController,
              validator: _validateTopic,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Topic *',
                hintText: 'e.g. Quran, Aqaid, Fiqh…',
                prefixIcon: Icon(Icons.topic_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            error: (_, _) => TextFormField(
              controller: _topicController,
              validator: _validateTopic,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Topic *',
                hintText: 'e.g. Quran, Aqaid, Fiqh…',
                prefixIcon: Icon(Icons.topic_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // The card's white background would hide the tile's ink splash.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              value: _restrictToClass,
              onChanged: (value) {
                setState(() => _restrictToClass = value);
              },
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Restrict to this class',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Off = open to all TSR subscribers',
                style: TextStyle(fontSize: 12),
              ),
              activeTrackColor: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          'Questions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Text(
            '${_questions.length} question${_questions.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoQuestions(BuildContext context) {
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
            Icons.help_outline_rounded,
            size: 40,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(height: 8),
          Text(
            _hasTopic
                ? 'No questions yet. Tap "Add Question" to get started.'
                : 'Enter a topic above to start adding questions.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }

  void _addQuestion() {
    setState(() {
      _questions.add(const McqManageQuestion(question: ''));
      _questionKeys.add(GlobalKey());
    });
    // Scroll to the new question after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      _questionKeys.removeAt(index);
    });
  }

  Future<void> _save() async {
    // Validate quiz name and topic.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate questions.
    final incomplete = _questions.indexed.where((e) => !e.$2.isComplete);
    if (incomplete.isNotEmpty) {
      final first = incomplete.first.$1;
      AppSnackBar.showWarning(
        context,
        message:
            'Question ${first + 1} is incomplete — add the question text and '
            'at least the correct answer.',
      );
      // Focus the first incomplete question.
      final key = _questionKeys[first];
      key.currentState?.validate();
      return;
    }

    setState(() => _isSubmitting = true);
    final repository = ref.read(mcqManageRepositoryProvider);

    try {
      if (widget.isEdit) {
        await repository.updateQuiz(
          widget.quizId!,
          name: _nameController.text.trim(),
          topic: _topicController.text.trim(),
          restrictToClass: _restrictToClass ? 1 : 0,
          questions: _questions,
        );
      } else {
        final quizId = await repository.createQuiz(
          widget.classId,
          name: _nameController.text.trim(),
          topic: _topicController.text.trim(),
          restrictToClass: _restrictToClass ? 1 : 0,
        );
        await repository.updateQuiz(
          quizId,
          name: _nameController.text.trim(),
          topic: _topicController.text.trim(),
          restrictToClass: _restrictToClass ? 1 : 0,
          questions: _questions,
        );
      }

      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: widget.isEdit
            ? 'Quiz updated successfully'
            : 'Quiz created successfully',
      );
      ref.invalidate(mcqManageListProvider(widget.classId));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: userMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Quiz')),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppTheme.spacingMD),
              child: SkeletonBox(height: 120, radius: AppTheme.radiusLG),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, Object error) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Quiz')),
      body: AppErrorView(
        error: error,
        onRetry: () => ref.invalidate(mcqManageDetailProvider(widget.quizId!)),
      ),
    );
  }
}

/// A single question editor card: question text, correct answer, and options.
class _QuestionCard extends StatefulWidget {
  final int index;
  final McqManageQuestion question;
  final ValueChanged<McqManageQuestion> onChanged;
  final VoidCallback? onRemove;

  const _QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  late final TextEditingController _option2Controller;
  late final TextEditingController _option3Controller;
  late final TextEditingController _option4Controller;
  late final TextEditingController _option5Controller;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question.question);
    _answerController = TextEditingController(text: widget.question.answer);
    _option2Controller = TextEditingController(text: widget.question.option2);
    _option3Controller = TextEditingController(text: widget.question.option3);
    _option4Controller = TextEditingController(text: widget.question.option4);
    _option5Controller = TextEditingController(text: widget.question.option5);
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    _option5Controller.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      McqManageQuestion(
        question: _questionController.text,
        answer: _answerController.text,
        option2: _option2Controller.text,
        option3: _option3Controller.text,
        option4: _option4Controller.text,
        option5: _option5Controller.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Question ${widget.index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: widget.onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorRed,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _questionController,
            maxLines: 2,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Question *',
              hintText: 'Type the question here…',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _answerController,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Correct Answer *',
              hintText: 'The correct option',
              prefixIcon: Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.successGreen,
              ),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _option2Controller,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Option 2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _option3Controller,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Option 3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _option4Controller,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Option 4',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _option5Controller,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Option 5',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
