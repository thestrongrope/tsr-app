import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/guide_authoring.dart';
import '../models/guide_html.dart';
import '../providers/guides_provider.dart';

/// Edit one level's guide in a rich-text editor (#417). The editor only opens
/// once the guide has loaded, so a failed load can never be saved over.
class GuideEditorScreen extends ConsumerWidget {
  const GuideEditorScreen({super.key, required this.levelId});

  final int levelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(guideForEditProvider(levelId));

    return Scaffold(
      appBar: AppBar(title: Text(guide.asData?.value.levelName ?? 'Guide')),
      body: guide.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load the guide."),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(guideForEditProvider(levelId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _GuideEditor(levelId: levelId, guide: data),
      ),
    );
  }
}

class _GuideEditor extends ConsumerStatefulWidget {
  const _GuideEditor({required this.levelId, required this.guide});

  final int levelId;
  final EditableGuide guide;

  @override
  ConsumerState<_GuideEditor> createState() => _GuideEditorState();
}

class _GuideEditorState extends ConsumerState<_GuideEditor> {
  late final QuillController _controller;
  late final FocusNode _focusNode = FocusNode();
  late final ScrollController _scrollController = ScrollController();

  /// What the server has: the editor's content when it opened or last saved.
  late var _saved = _controller.document.toDelta();
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: guideHtmlToDocument(widget.guide.guide ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _saved = _controller.document.toDelta();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _controller.document.toDelta() != _saved &&
      _controller.document.toPlainText().trim().isNotEmpty;

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final content = _controller.document.toDelta();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(guidesRepositoryProvider)
          .saveGuide(widget.levelId, guideDocumentToHtml(_controller.document));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = content;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Guide saved.')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuillSimpleToolbar(
          controller: _controller,
          config: const QuillSimpleToolbarConfig(
            showFontFamily: false,
            showFontSize: false,
            showSmallButton: false,
            showStrikeThrough: false,
            showInlineCode: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showClearFormat: false,
            showAlignmentButtons: false,
            showListCheck: false,
            showCodeBlock: false,
            showQuote: false,
            showDirection: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showLineHeightButton: false,
            multiRowsDisplay: false,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: QuillEditor(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
            ),
          ),
        ),
        if (_saveFailed)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              "Couldn't save the guide.",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ),
      ],
    );
  }
}
