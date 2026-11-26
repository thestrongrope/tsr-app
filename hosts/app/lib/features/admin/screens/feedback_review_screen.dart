import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/tab_bar_inset.dart';
import '../models/feedback_item.dart';
import '../providers/feedback_provider.dart';

/// Review queue for member feedback (#891, #892, #893).
///
/// Shows unhandled messages first, then handled ones.
/// Toggling handled status updates the list optimistically and reverts on error.
class FeedbackReviewScreen extends ConsumerWidget {
  const FeedbackReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(feedbackNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Member Feedback'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(feedbackNotifierProvider),
          ),
        ],
      ),
      body: feedbackAsync.when(
        loading: () => const _FeedbackLoadingSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            child: AppSurfaceCard(
              child: AppErrorView(
                error: err,
                onRetry: () => ref.invalidate(feedbackNotifierProvider),
              ),
            ),
          ),
        ),
        data: (queue) {
          final items = queue.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingLG),
                child: AppEmptySection(
                  icon: Icons.rate_review_outlined,
                  message: 'No feedback submitted yet',
                ),
              ),
            );
          }

          final unhandled = items.where((i) => !i.isHandled).toList();
          final handled = items.where((i) => i.isHandled).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(feedbackNotifierProvider.future),
            child: ListView(
              padding: withTabBarInset(
                context,
                const EdgeInsets.all(AppTheme.spacingMD),
              ),
              children: [
                _SummaryChips(
                  unhandledCount: queue.unhandledCount,
                  handledCount: queue.handledCount,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                if (unhandled.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Unhandled (${queue.unhandledCount})',
                    icon: Icons.mark_chat_unread_outlined,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  for (final item in unhandled) ...[
                    _FeedbackCard(key: ValueKey(item.id), item: item),
                    const SizedBox(height: AppTheme.spacingSM),
                  ],
                ],
                if (handled.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  _SectionHeader(
                    title: 'Handled (${queue.handledCount})',
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  for (final item in handled) ...[
                    _FeedbackCard(key: ValueKey(item.id), item: item),
                    const SizedBox(height: AppTheme.spacingSM),
                  ],
                ],
                if (queue.hasMore) const _LoadMoreButton(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadMoreButton extends ConsumerStatefulWidget {
  const _LoadMoreButton();

  @override
  ConsumerState<_LoadMoreButton> createState() => _LoadMoreButtonState();
}

class _LoadMoreButtonState extends ConsumerState<_LoadMoreButton> {
  bool _isLoading = false;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(feedbackNotifierProvider.notifier).loadMore();
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Could not load more feedback');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator()
          : OutlinedButton(onPressed: _load, child: const Text('Load more')),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.unhandledCount,
    required this.handledCount,
  });

  final int unhandledCount;
  final int handledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Chip(
          avatar: const Icon(
            Icons.mark_chat_unread,
            size: 16,
            color: Colors.orange,
          ),
          label: Text(
            '$unhandledCount unhandled',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          side: BorderSide.none,
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Chip(
          avatar: const Icon(
            Icons.check_circle,
            size: 16,
            color: AppTheme.primaryGreen,
          ),
          label: Text(
            '$handledCount handled',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
          side: BorderSide.none,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: AppTheme.spacingSM),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _FeedbackCard extends ConsumerStatefulWidget {
  const _FeedbackCard({super.key, required this.item});

  final FeedbackItem item;

  @override
  ConsumerState<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<_FeedbackCard> {
  bool _isUpdating = false;

  Future<void> _toggle() async {
    setState(() => _isUpdating = true);
    try {
      await ref
          .read(feedbackNotifierProvider.notifier)
          .toggleHandled(widget.item.id);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Changes could not be saved');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dateSentStr = DateFormat.yMMMd().add_jm().format(
      item.createdAt.toLocal(),
    );

    return AppSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.sender.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  dateSentStr,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppTheme.mediumText),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            SelectableText(
              item.text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (item.isHandled && item.handledAt != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Handled on ${DateFormat.yMMMd().add_jm().format(item.handledAt!.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSM),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: item.isHandled
                  ? OutlinedButton.icon(
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo, size: 16),
                      label: const Text('Mark unhandled'),
                      onPressed: _isUpdating ? null : _toggle,
                    )
                  : ElevatedButton.icon(
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Mark handled'),
                      onPressed: _isUpdating ? null : _toggle,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackLoadingSkeleton extends StatelessWidget {
  const _FeedbackLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: const [
        AppSurfaceCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingLG),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}
