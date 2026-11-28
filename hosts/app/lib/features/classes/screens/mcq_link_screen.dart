import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/utils/user_message.dart';

/// What opening an MCQ link does for the signed-in member:
/// `GET /mcq/by-code/{code}`. [quizId] is set for `open` and `attempted` only.
class McqLinkResolution {
  const McqLinkResolution({required this.state, this.quizId});

  final String state;
  final int? quizId;

  factory McqLinkResolution.fromJson(Map<String, dynamic> json) =>
      McqLinkResolution(
        state: (json['state'] as String?) ?? 'not_found',
        quizId: json['quizId'] as int?,
      );
}

/// One MCQ the member may attempt now: `GET /mcq/open`.
class McqOpenItem {
  const McqOpenItem({
    required this.id,
    required this.name,
    this.topic,
    required this.classCode,
  });

  final int id;
  final String name;
  final String? topic;
  final String classCode;

  factory McqOpenItem.fromJson(Map<String, dynamic> json) => McqOpenItem(
    id: json['id'] as int,
    name: (json['name'] as String?) ?? '',
    topic: json['topic'] as String?,
    classCode: (json['classCode'] as String?) ?? '',
  );
}

final mcqLinkResolutionProvider = FutureProvider.autoDispose
    .family<McqLinkResolution, String>((ref, code) async {
      final json = await ApiClient().get<Map<String, dynamic>>(
        '/mcq/by-code/${Uri.encodeComponent(code)}',
      );
      return McqLinkResolution.fromJson(json);
    });

final mcqOpenListProvider = FutureProvider.autoDispose<List<McqOpenItem>>((
  ref,
) async {
  final json = await ApiClient().get<Map<String, dynamic>>('/mcq/open');
  return (json['items'] as List<dynamic>? ?? const [])
      .map((e) => McqOpenItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// An MCQ link (#860, #861): opens that MCQ, shows the result of one already
/// attempted, or says why it cannot be opened and lists what can.
class McqLinkScreen extends ConsumerStatefulWidget {
  const McqLinkScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<McqLinkScreen> createState() => _McqLinkScreenState();
}

class _McqLinkScreenState extends ConsumerState<McqLinkScreen> {
  bool _navigated = false;

  /// Where the link leads, or null when the member cannot open it.
  String? _destination(McqLinkResolution link) {
    final id = link.quizId;
    if (id == null) return null;
    if (link.state == 'open') return '/quizzes/$id';
    if (link.state == 'attempted') return '/quizzes/$id/result';
    return null;
  }

  String _message(String state) {
    switch (state) {
      case 'closed':
        return 'This MCQ is closed.';
      case 'not_released':
        return 'This MCQ has not been released yet.';
      case 'not_eligible':
        return 'You are not in the class this MCQ is for, so you cannot open it.';
      default:
        return 'We could not find this MCQ. The link may be wrong.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolution = ref.watch(mcqLinkResolutionProvider(widget.code));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('MCQ')),
      body: resolution.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(userMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(mcqLinkResolutionProvider(widget.code)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (link) {
          final destination = _destination(link);
          if (destination != null) {
            if (!_navigated) {
              _navigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.pushReplacement(destination);
              });
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _McqLinkMessage(message: _message(link.state));
        },
      ),
    );
  }
}

/// Says why the MCQ cannot be opened, then lists the MCQs the member can.
class _McqLinkMessage extends ConsumerWidget {
  const _McqLinkMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(mcqOpenListProvider);
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(message, style: textTheme.titleMedium),
        const SizedBox(height: 24),
        open.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(mcqOpenListProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'There are no MCQs for you to attempt right now.',
                style: textTheme.bodyMedium,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MCQs you can attempt now', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        if (item.topic != null && item.topic!.isNotEmpty)
                          item.topic!,
                        item.classCode,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushReplacement('/quizzes/${item.id}'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
