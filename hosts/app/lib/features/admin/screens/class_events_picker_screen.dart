import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/user_message.dart';

final _managedClassesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final classes = await ApiClient().get<List<dynamic>>(
        '/classes',
        queryParameters: const {'include': 'managed'},
      );
      return classes
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

/// Lets an administrator choose a class without loading every managed class
/// into the reminder list that the Classes tab uses.
class ClassEventsPickerScreen extends ConsumerStatefulWidget {
  const ClassEventsPickerScreen({super.key});

  @override
  ConsumerState<ClassEventsPickerScreen> createState() =>
      _ClassEventsPickerScreenState();
}

class _ClassEventsPickerScreenState
    extends ConsumerState<ClassEventsPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(_managedClassesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a class')),
      body: classes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userMessage(error)),
              TextButton(
                onPressed: () => ref.invalidate(_managedClassesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          final filtered = items.where((item) {
            final query = _query.trim().toLowerCase();
            if (query.isEmpty) return true;
            return '${item['code']} ${item['name']} ${item['levelName']}'
                .toLowerCase()
                .contains(query);
          });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search classes',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matching classes'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered.elementAt(index);
                          final id = (item['id'] as num).toInt();
                          return ListTile(
                            leading: const Icon(Icons.class_outlined),
                            title: Text(item['code'] as String? ?? 'Class $id'),
                            subtitle: Text(
                              '${item['name'] ?? ''} · ${item['levelName'] ?? ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/classes/$id/scheduled-events'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
