import 'package:flutter/material.dart';

import 'submit_feedback_view_model.dart';

/// The submit feedback screen: widgets only, all state in [SubmitFeedbackViewModel].
class SubmitFeedbackView extends StatefulWidget {
  const SubmitFeedbackView({super.key, required this.viewModel});

  final SubmitFeedbackViewModel viewModel;

  @override
  State<SubmitFeedbackView> createState() => _SubmitFeedbackViewState();
}

class _SubmitFeedbackViewState extends State<SubmitFeedbackView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          if (vm.status == SendStatus.sent && _controller.text.isNotEmpty) {
            _controller.clear();
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('feedback-text'),
                  controller: _controller,
                  onChanged: vm.updateText,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Your feedback',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('feedback-send'),
                  onPressed: vm.canSend ? vm.send : null,
                  child: Text(vm.status == SendStatus.sending ? 'Sending...' : 'Send'),
                ),
                if (vm.message != null) ...[
                  const SizedBox(height: 12),
                  Text(vm.message!, key: const Key('feedback-message')),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
