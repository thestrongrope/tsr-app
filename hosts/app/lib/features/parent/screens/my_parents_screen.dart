import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/my_parent_model.dart';
import '../providers/parent_provider.dart';
import '../widgets/add_parent_dialog.dart';

/// Screen for a logged-in student to view and revoke their linked parents (#633).
class MyParentsScreen extends ConsumerWidget {
  const MyParentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myParentsProvider);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final ownToken = user?.token ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Parents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Parent',
            onPressed: () => _openAddParent(context, ownToken, user?.name ?? 'Me'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.parents == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.parents == null) {
            return AppErrorView(
              error: state.error!,
              onRetry: () => ref.read(myParentsProvider.notifier).loadParents(),
            );
          }

          final parents = state.parents ?? const [];

          if (parents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.family_restroom_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Parents Linked',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have any parents or guardians linked to your account.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Add Parent'),
                      onPressed: () =>
                          _openAddParent(context, ownToken, user?.name ?? 'Me'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(myParentsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: parents.length,
              itemBuilder: (context, index) {
                final parent = parents[index];
                return _buildParentCard(context, ref, theme, parent);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildParentCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    MyParentModel parent,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    parent.parentName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    parent.relationshipDisplay,
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Linked on: ${parent.createdAt}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Revoke Parent'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () => _confirmRevoke(context, ref, parent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddParent(
    BuildContext context,
    int childToken,
    String childName,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AddParentDialog(
        childToken: childToken,
        childName: childName,
        allowDirectTokenEntry: false,
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    MyParentModel parent,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Parent Link'),
        content: Text(
          'Are you sure you want to revoke ${parent.parentName}? '
          'They will no longer be able to see your class performance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(myParentsProvider.notifier)
          .revokeParent(parent.parentToken);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${parent.parentName} link revoked')),
        );
      }
    }
  }
}
