import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_config.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/parent_provider.dart';
import '../widgets/child_card.dart';

/// Screen listing all children linked to the parent (#633).
class MyChildrenScreen extends ConsumerWidget {
  const MyChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(childrenProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Children'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(childrenProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'My Links',
            onPressed: () => context.push(AppRoutes.parentLinks),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.children == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.children == null) {
            return AppErrorView(
              error: state.error!,
              onRetry: () => ref.read(childrenProvider.notifier).loadChildren(),
            );
          }

          final children = state.children ?? const [];

          if (children.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(childrenProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    Icon(
                      Icons.family_restroom,
                      size: 72,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Children Linked',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To view your child\'s classes and academic performance, '
                      'ask their teacher or school administrator for a parent invite link, '
                      'or accept an invite link sent to you.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          onPressed: () => ref.read(childrenProvider.notifier).refresh(),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.link),
                          label: const Text('View My Links'),
                          onPressed: () => context.push(AppRoutes.parentLinks),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(childrenProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ChildCard(
                  child: child,
                  onTap: () {
                    context.push(
                      AppRoutes.childClassesPath(child.token),
                      extra: child,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
