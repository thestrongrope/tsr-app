import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_classes.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../parent/providers/parent_provider.dart';
import '../../parent/widgets/add_parent_dialog.dart';
import '../providers/members_provider.dart';

/// A student (#557): who they are and the classes they are in that you may see,
/// each opening that class. The server answers 404 for a person that does not
/// exist and for one the viewer may not see, and this says so without saying
/// which. No contact details (#316).
class StudentCardScreen extends ConsumerWidget {
  const StudentCardScreen({super.key, required this.token});

  final int token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(studentCardProvider(token));
    final capabilities = ref.watch(capabilitiesProvider);
    final canAddParent = capabilities.canAddParents;
    final canAddParentByToken = capabilities.canAddParentByToken;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: Text(card.value?.name ?? 'Student')),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _CardError(
          notFound: e is ApiException && e.statusCode == 404,
          onRetry: () => ref.invalidate(studentCardProvider(token)),
        ),
        data: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(c.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              c.gender == 1
                  ? 'Gents'
                  : c.gender == 2
                  ? 'Ladies'
                  : '',
            ),
            if (canAddParent) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('add-parent-button'),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add parent'),
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddParentDialog(
                      childToken: token,
                      childName: c.name,
                      allowDirectTokenEntry: canAddParentByToken,
                    ),
                  );
                  if (added == true && context.mounted) {
                    ref.invalidate(childrenProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Parent linked successfully'),
                      ),
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Text('Classes', style: Theme.of(context).textTheme.titleMedium),
            for (final cls in c.classes)
              Card(
                child: ListTile(
                  title: Text(cls.code),
                  subtitle: Text(cls.level),
                  trailing: const Icon(Icons.chevron_right),
                  // The card is outside the tab shell and the class screen is
                  // inside it, so go rather than push; see isPersonCard.
                  onTap: () => context.go(
                    AppRoutes.classDashboardDetail.replaceFirst(
                      ':classId',
                      '${cls.id}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 404 and the failure, shared by both cards.
class _CardError extends StatelessWidget {
  const _CardError({required this.notFound, required this.onRetry});

  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notFound
                ? 'This person could not be found.'
                : 'The card could not be loaded.',
          ),
          if (!notFound) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
