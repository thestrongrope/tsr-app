import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_config.dart';
import '../../../core/widgets/app_error_view.dart';
import '../models/child_model.dart';
import '../providers/parent_provider.dart';
import '../widgets/child_class_card.dart';

/// Screen listing a child's enrolled classes (active and inactive) (#633).
///
/// NOTE: Meeting links are intentionally never displayed here for privacy.
class ChildClassesScreen extends ConsumerWidget {
  final int childToken;
  final ChildModel? initialChild;

  const ChildClassesScreen({
    super.key,
    required this.childToken,
    this.initialChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(childClassesProvider(childToken));
    final theme = Theme.of(context);

    // Look up child details if available from childrenProvider
    final childrenState = ref.watch(childrenProvider);
    final child = initialChild ??
        childrenState.children?.where((c) => c.token == childToken).firstOrNull;
    final title = child != null ? '${child.name}\'s Classes' : 'Classes';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(childClassesProvider(childToken)),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Classes Found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This student is not currently enrolled in any classes.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(childClassesProvider(childToken));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final cls = classes[index];
                return ChildClassCard(
                  childClass: cls,
                  onTap: () {
                    context.push(
                      AppRoutes.childClassPerformancePath(
                        childToken,
                        cls.classId,
                      ),
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
