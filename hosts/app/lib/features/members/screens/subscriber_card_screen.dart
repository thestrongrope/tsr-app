import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/members_provider.dart';

/// A subscriber (#557): a registered person who is not in a class, when they
/// registered and the class they asked for. The super admin's to see; anyone
/// else gets the same 404 as for a person who does not exist. No contact
/// details (#316).
class SubscriberCardScreen extends ConsumerWidget {
  const SubscriberCardScreen({super.key, required this.token});

  final int token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(subscriberCardProvider(token));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: Text(card.value?.name ?? 'Subscriber')),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final notFound = e is ApiException && e.statusCode == 404;
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
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(subscriberCardProvider(token)),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          );
        },
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
            const SizedBox(height: 16),
            if (c.registeredOn != null) Text('Registered ${c.registeredOn}'),
            if (c.requestedClass != null)
              Text('Asked for class ${c.requestedClass}'),
          ],
        ),
      ),
    );
  }
}
