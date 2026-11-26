import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_config.dart';
import '../providers/guides_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Pick the level whose guide to edit (#417).
class GuidesAdminScreen extends ConsumerWidget {
  const GuidesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(guideLevelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Guides')),
      body: levels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load the levels."),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(guideLevelsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (levels) => ListView(
          padding: withTabBarInset(context, const EdgeInsets.all(16)),
          children: [
            for (final level in levels)
              Card(
                child: ListTile(
                  title: Text(level.name),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () =>
                      context.push('${AppRoutes.adminGuides}/${level.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
