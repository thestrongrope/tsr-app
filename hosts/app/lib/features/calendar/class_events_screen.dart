import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/network/api_client.dart';
import '../../core/utils/user_message.dart';
import '../classes/providers/class_scheduled_notifications_provider.dart';
import 'calendar_models.dart';

class ClassEventsRepository {
  Future<List<CalendarEvent>> list(int classId) async {
    final json = await ApiClient().get<Map<String, Object?>>(
      '/classes/$classId/scheduled-events',
    );
    return [
      for (final kind in ['events', 'slots'])
        for (final item in json[kind] as List) CalendarEvent(calendarMap(item)),
    ];
  }

  Future<void> save(
    int classId,
    Map<String, Object?> input,
    String? key,
  ) async {
    if (key == null) {
      await ApiClient().post<Object?>(
        '/classes/$classId/scheduled-events',
        data: input,
      );
    } else {
      try {
        await ApiClient().dio.patch<Object?>(
          '/classes/$classId/scheduled-events/${key.split(':').last}',
          data: input,
        );
      } on DioException catch (error) {
        throw ApiException.fromDioException(error);
      }
    }
  }

  Future<void> delete(int classId, String key) async {
    await ApiClient().delete<Object?>(
      '/classes/$classId/scheduled-events/${key.split(':').last}',
    );
  }
}

final classEventsRepositoryProvider = Provider(
  (ref) => ClassEventsRepository(),
);
final classEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, int>(
      (ref, id) => ref.watch(classEventsRepositoryProvider).list(id),
    );

class ClassEventsScreen extends ConsumerWidget {
  const ClassEventsScreen({super.key, required this.classId});
  final int classId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    CalendarEvent? event,
  ]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(classId: classId, event: event),
      ),
    );
    if (changed == true) ref.invalidate(classEventsProvider(classId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class events'),
        actions: [
          IconButton(
            tooltip: 'Create event',
            icon: const Icon(Icons.add),
            onPressed: () => _edit(context, ref),
          ),
        ],
      ),
      body: ref
          .watch(classEventsProvider(classId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(userMessage(error))),
            data: (items) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                FilledButton.icon(
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create event'),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty) const Text('No scheduled events'),
                for (final event in items)
                  Card(
                    child: ListTile(
                      title: Text(event.message),
                      subtitle: Text(
                        '${event.description ?? ''}\n${event.cadence}${event.key.startsWith('slot:') ? '\nEdit this slot in the class timetable.' : ''}',
                      ),
                      trailing: event.editable
                          ? Wrap(
                              children: [
                                TextButton(
                                  onPressed: () => _edit(context, ref, event),
                                  child: Text(
                                    event.takeover ? 'Take over' : 'Edit',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete event',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Delete event for everyone?',
                                        ),
                                        content: Text(event.message),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    try {
                                      await ref
                                          .read(classEventsRepositoryProvider)
                                          .delete(classId, event.key);
                                      ref.invalidate(
                                        classEventsProvider(classId),
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(userMessage(error)),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, required this.classId, this.event});
  final int classId;
  final CalendarEvent? event;
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _message;
  late final TextEditingController _description;
  late final TextEditingController _link;
  late final TextEditingController _time;
  late final Set<int> _days;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _message = TextEditingController(text: event?.message);
    _description = TextEditingController(text: event?.description);
    _link = TextEditingController(text: event?.link);
    _time = TextEditingController(text: event?.time ?? '18:00');
    _days = {...?event?.weekdays};
  }

  @override
  void dispose() {
    for (final controller in [_message, _description, _link, _time]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_days.isEmpty) {
      setState(() => _error = 'Choose at least one weekday');
      return;
    }
    if (widget.event != null && !widget.event!.editable) {
      setState(() => _error = 'You cannot edit this event');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String zone = widget.event != null
          ? widget.event!.timezone
          : await ref.read(deviceTimezoneProvider.future);
      try {
        tz.getLocation(zone);
      } catch (_) {
        throw const ApiException('This phone has no valid time zone', 422);
      }
      final days = _days.toList()..sort();
      await ref.read(classEventsRepositoryProvider).save(widget.classId, {
        'message': _message.text.trim(),
        'description': _description.text.trim(),
        'action_link': _link.text.trim(),
        'weekdays': days,
        'send_time': _time.text,
        if (widget.event == null) 'timezone': zone,
      }, widget.event?.key);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = userMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zone =
        widget.event?.timezone ??
        ref.watch(deviceTimezoneProvider).asData?.value ??
        'unavailable';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Create event' : 'Edit event'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _message,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLength: 500,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Message is required'
                  : null,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLength: 2000,
              maxLines: 3,
            ),
            TextFormField(
              controller: _link,
              decoration: const InputDecoration(labelText: 'Link (optional)'),
              maxLength: 500,
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(
                      const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][day - 1],
                    ),
                    selected: _days.contains(day),
                    onSelected: (value) => setState(() {
                      value ? _days.add(day) : _days.remove(day);
                    }),
                  ),
              ],
            ),
            TextFormField(
              controller: _time,
              decoration: const InputDecoration(labelText: 'Time (HH:MM)'),
              validator: (value) =>
                  RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value ?? '')
                  ? null
                  : 'Enter a valid time (HH:MM)',
            ),
            Text(
              'Time zone: $zone (${widget.event == null ? 'this phone' : 'saved with this event'})',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save event'),
            ),
          ],
        ),
      ),
    );
  }
}
