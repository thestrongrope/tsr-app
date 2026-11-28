import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/user_message.dart';
import 'calendar_models.dart';
import 'calendar_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(calendarProvider.notifier).refresh();
      ref.invalidate(notificationsAllowedProvider);
    });
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(calendarProvider);
    final allowed = ref.watch(notificationsAllowedProvider);
    final dropped = ref.watch(calendarAlarmNoticeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My class alerts')),
      body: calendar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userMessage(error)),
              TextButton(
                onPressed: () => ref.read(calendarProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(calendarProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (allowed.asData?.value == false)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Notifications are blocked in this phone’s settings. Alerts cannot fire.',
                    ),
                  ),
                ),
              if (dropped > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Alerts for $dropped events are not armed on this phone. Turn off an event to free a slot.',
                    ),
                  ),
                ),
              if (data == null || data.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No class events'),
                ),
              if (data != null)
                for (final event in data.events)
                  _event(event, data.setting(event.key)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _event(CalendarEvent event, EventSetting setting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.message, style: Theme.of(context).textTheme.titleMedium),
            Text(event.className),
            if (event.description?.isNotEmpty == true) Text(event.description!),
            Text(event.cadence),
            if (event.link != null)
              TextButton(
                onPressed: () => _action(() async {
                  if (event.link!.startsWith('/')) {
                    context.push(event.link!);
                  } else if (!await launchUrl(
                    Uri.parse(event.link!),
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw StateError('Could not open link');
                  }
                }),
                child: Text(event.link!),
              ),
            DropdownButton<int>(
              value: setting.muted ? 1 : setting.offset,
              isExpanded: true,
              items: [
                for (final offset in eventOffsets)
                  DropdownMenuItem(
                    value: offset,
                    child: Text(offsetLabel(offset)),
                  ),
                const DropdownMenuItem(value: 1, child: Text('Off')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _action(
                    () => ref
                        .read(calendarProvider.notifier)
                        .change(
                          event,
                          EventSetting(
                            offset: value == 1 ? setting.offset : value,
                            muted: value == 1,
                          ),
                        ),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete for me'),
              onPressed: () => _action(() async {
                await ref
                    .read(calendarProvider.notifier)
                    .change(
                      event,
                      EventSetting(
                        offset: setting.offset,
                        muted: setting.muted,
                        deleted: true,
                      ),
                      deleting: true,
                    );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Event removed'),
                    // Shorter than the repository's ten-second hold, which starts
                    // before the alarms are re-armed.
                    duration: const Duration(seconds: 8),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => _action(
                        () =>
                            ref.read(calendarProvider.notifier).undo(event.key),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
