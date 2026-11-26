import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/scheduled_notification.dart';
import '../providers/providers.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The date and time the sender picked, as written on their clock, with no
/// offset. The server reads it in the phone's zone, which is sent beside it.
String localWallClock(DateTime date, TimeOfDay time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}T'
      '${two(time.hour)}:${two(time.minute)}:00';
}

/// How the next class notification leaves the sender's phone.
enum _NotifyMode { now, schedule, reminder }

/// Screen for teachers and class admins to send targeted push notifications
/// to students of a specific class: immediately, on a schedule, or as a
/// reminder relative to a class slot.
class ClassSendNotificationScreen extends ConsumerStatefulWidget {
  final int classId;
  final DateTime Function()? clock;

  const ClassSendNotificationScreen({super.key, required this.classId, this.clock});

  @override
  ConsumerState<ClassSendNotificationScreen> createState() =>
      _ClassSendNotificationScreenState();
}

class _ClassSendNotificationScreenState
    extends ConsumerState<ClassSendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _actionLinkController = TextEditingController();

  _NotifyMode _mode = _NotifyMode.now;
  bool _isSending = false;

  // Schedule
  bool _repeatWeekly = false;
  DateTime? _sendDate;
  TimeOfDay? _sendTime;
  final Set<int> _weekdays = {};

  // Reminder
  int? _scheduleSlotId;
  int _offsetMinutes = -15;
  bool _reminderRepeatWeekly = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _actionLinkController.dispose();
    super.dispose();
  }

  String _zoneText() =>
      ref.watch(deviceTimezoneProvider).asData?.value ??
      'time zone unavailable';

  String get _sendTimeText => _sendTime == null
      ? '—'
      : '${_two(_sendTime!.hour)}:${_two(_sendTime!.minute)}';

  Future<void> _handleSubmit(
    String classDisplayName,
    List<ClassScheduleSlot> slots,
  ) async {
    if (_isSending) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showError('Please enter both title and message');
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    final problem = _modeError(slots);
    if (problem != null) {
      _showError(problem);
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final actionLink = _actionLinkController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              color: AppTheme.primaryGreen,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _mode == _NotifyMode.now ? 'Send Notification' : 'Confirm',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                ),
                children: [
                  const TextSpan(
                    text: 'Audience: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Enrolled students of $classDisplayName\n\n'),
                  const TextSpan(
                    text: 'Title: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$title\n\n'),
                  if (_mode != _NotifyMode.now) ...[
                    const TextSpan(
                      text: 'When: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${_whenSummary(slots)}\n\n'),
                  ],
                ],
              ),
            ),
            Text(
              _mode == _NotifyMode.now
                  ? 'This push notification will be delivered immediately to students of this class.'
                  : 'This will send automatically. You can delete it from Scheduled Notifications.',
              style: const TextStyle(fontSize: 13, color: AppTheme.mediumText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: Text(_submitLabel()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);

    try {
      final apiClient = ApiClient();

      if (_mode == _NotifyMode.now) {
        final response = await apiClient.post<Map<String, dynamic>>(
          '/classes/${widget.classId}/notifications',
          data: {
            'title': title,
            'body': body,
            if (actionLink.isNotEmpty) 'action_link': actionLink,
          },
        );

        if (!mounted) return;

        final successCount = response['success_count'] ?? 0;
        final message =
            response['message'] ??
            'Notification sent to $successCount device(s)';
        _showSuccess(message.toString());
      } else {
        final response = await ref
            .read(classScheduledNotificationsRepositoryProvider)
            .create(widget.classId, {
              ..._payload(title, body, actionLink),
              'timezone': await ref.read(deviceTimezoneProvider.future),
            });

        if (!mounted) return;

        ref.invalidate(classScheduledNotificationsProvider(widget.classId));
        _showSuccess(
          _mode == _NotifyMode.schedule
              ? 'Scheduled: ${response.title}'
              : 'Reminder saved: ${response.title}',
        );
      }

      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(
        _mode == _NotifyMode.now
            ? 'Failed to send notification: ${userMessage(e)}'
            : 'Failed to save: ${userMessage(e)}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// The mode-specific payload. `title`, `body` and the link are shared.
  Map<String, dynamic> _payload(String title, String body, String link) {
    final base = <String, dynamic>{
      'title': title,
      'body': body,
      if (link.isNotEmpty) 'action_link': link,
    };

    if (_mode == _NotifyMode.schedule) {
      if (_repeatWeekly) {
        return {
          ...base,
          'kind': 'WEEKLY',
          'weekdays': _weekdays.toList()..sort(),
          'send_time': _sendTimeText,
        };
      }
      return {
        ...base,
        'kind': 'ONCE',
        'send_at': localWallClock(_sendDate!, _sendTime!),
      };
    }

    return {
      ...base,
      'kind': 'REMINDER',
      'class_schedule_id': _scheduleSlotId,
      'offset_minutes': _offsetMinutes,
      'repeat_weekly': _reminderRepeatWeekly,
    };
  }

  DateTime _sendAtLocal() => DateTime(
    _sendDate!.year,
    _sendDate!.month,
    _sendDate!.day,
    _sendTime!.hour,
    _sendTime!.minute,
  );

  String? _modeError(List<ClassScheduleSlot> slots) {
    if (_mode == _NotifyMode.now) return null;

    if (_mode == _NotifyMode.schedule) {
      if (_sendTime == null) return 'Pick a time to send at';
      if (_repeatWeekly) {
        if (_weekdays.isEmpty) return 'Pick at least one weekday';
      } else {
        if (_sendDate == null) return 'Pick a date to send on';
        if (!_sendAtLocal().isAfter(widget.clock?.call() ?? DateTime.now())) {
          return 'Pick a moment in the future';
        }
      }
      return null;
    }

    if (slots.isEmpty) return 'This class has no schedule slots yet';
    if (_scheduleSlotId == null) return 'Pick a class schedule slot';
    return null;
  }

  String _whenSummary(List<ClassScheduleSlot> slots) {
    if (_mode == _NotifyMode.schedule) {
      if (_repeatWeekly) {
        final days = (_weekdays.toList()..sort()).map(_dayShort).join(', ');
        return 'Every $days at $_sendTimeText · ${_zoneText()}';
      }
      final date = _sendDate!;
      return 'Once on ${_dayShort(date.weekday)} '
          '${_two(date.day)}/${_two(date.month)}/${date.year} at $_sendTimeText · ${_zoneText()}';
    }

    ClassScheduleSlot? slot;
    for (final candidate in slots) {
      if (candidate.id == _scheduleSlotId) {
        slot = candidate;
        break;
      }
    }
    final when = slot == null
        ? 'the class slot'
        : '${_dayShort(slot.day)} ${_two(slot.hour)}:${_two(slot.minute)}';
    return '${_offsetLabel(_offsetMinutes)} $when'
        '${_reminderRepeatWeekly ? ' · every week' : ' · once'}';
  }

  String _submitLabel() => switch (_mode) {
    _NotifyMode.now => 'Send Now',
    _NotifyMode.schedule => 'Schedule',
    _NotifyMode.reminder => 'Save Reminder',
  };

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classDetailAsync = ref.watch(classDetailProvider(widget.classId));
    // Watched only when a scheduling tab is open, so send-now makes exactly the
    // requests it always did. Read again from this list by the handlers, never
    // with ref.watch.
    final slots = _mode == _NotifyMode.now
        ? const <ClassScheduleSlot>[]
        : ref
                  .watch(classScheduledNotificationsProvider(widget.classId))
                  .value
                  ?.schedules ??
              const <ClassScheduleSlot>[];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Class Notification'),
        actions: [
          IconButton(
            tooltip: 'Scheduled notifications',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push(
              '/classes/${widget.classId}/notifications/scheduled',
            ),
          ),
        ],
      ),
      body: classDetailAsync.when(
        data: (classModel) {
          final classLevel =
              classModel.levelName ?? 'Level ${classModel.level}';
          final classDisplayName = classModel.code.isNotEmpty
              ? '$classLevel - ${classModel.code}'
              : classLevel;

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: withTabBarInset(
                context,
                const EdgeInsets.all(AppTheme.spacingLG),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildClassInfoCard(theme, classDisplayName),
                    const SizedBox(height: AppTheme.spacingLG),

                    _buildModeSelector(theme),
                    const SizedBox(height: AppTheme.spacingLG),

                    _buildMessageFieldsCard(theme),
                    const SizedBox(height: AppTheme.spacingLG),

                    if (_mode == _NotifyMode.schedule) ...[
                      _buildScheduleCard(theme, slots),
                      const SizedBox(height: AppTheme.spacingLG),
                    ],
                    if (_mode == _NotifyMode.reminder) ...[
                      _buildReminderCard(theme, slots),
                      const SizedBox(height: AppTheme.spacingLG),
                    ],

                    _buildActionLinkCard(theme),
                    const SizedBox(height: AppTheme.spacingXL),

                    _buildSendButton(classDisplayName, slots),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load class info',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userMessage(error),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(classDetailProvider(widget.classId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return SegmentedButton<_NotifyMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppTheme.primaryGreen,
        selectedForegroundColor: Colors.white,
      ),
      segments: const [
        ButtonSegment(value: _NotifyMode.now, label: Text('Send now')),
        ButtonSegment(value: _NotifyMode.schedule, label: Text('Schedule')),
        ButtonSegment(value: _NotifyMode.reminder, label: Text('Reminder')),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) {
        setState(() => _mode = selection.first);
      },
    );
  }

  Widget _buildClassInfoCard(ThemeData theme, String classDisplayName) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classDisplayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recipients: All enrolled active students in this class.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageFieldsCard(ThemeData theme) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message Details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          TextFormField(
            controller: _titleController,
            decoration: _inputDecoration(
              labelText: 'Title *',
              hintText: 'e.g., Class Rescheduled / Special Announcement',
              prefixIcon: const Icon(Icons.title, color: AppTheme.mediumText),
            ),
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Title is required';
              }
              if (value.trim().length > 255) {
                return 'Title must be 255 characters or less';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingSM),
          TextFormField(
            controller: _bodyController,
            decoration: _inputDecoration(
              labelText: 'Message Body *',
              hintText: 'Enter notification text here...',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            minLines: 3,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Message is required';
              }
              if (value.trim().length > 2000) {
                return 'Message must be 2000 characters or less';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ThemeData theme, List<ClassScheduleSlot> slots) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, Icons.schedule, 'When to send'),
          const SizedBox(height: 6),
          Text(
            _repeatWeekly
                ? 'Repeats every week at the time you pick.'
                : 'Sends once at the date and time you pick.',
            style: const TextStyle(fontSize: 12, color: AppTheme.mediumText),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryGreen,
            title: const Text(
              'Repeat weekly',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            value: _repeatWeekly,
            onChanged: (value) => setState(() => _repeatWeekly = value),
          ),
          if (_repeatWeekly) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_dayShort(day)),
                    selected: _weekdays.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weekdays.add(day);
                      } else {
                        _weekdays.remove(day);
                      }
                    }),
                  ),
              ],
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_outlined,
                color: AppTheme.primaryGreen,
              ),
              title: const Text('Date'),
              subtitle: Text(
                _sendDate == null
                    ? 'Not set'
                    : '${_dayShort(_sendDate!.weekday)} '
                          '${_two(_sendDate!.day)}/${_two(_sendDate!.month)}/${_sendDate!.year}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.access_time,
              color: AppTheme.primaryGreen,
            ),
            title: const Text('Time'),
            subtitle: Text(_sendTimeText),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTime,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Time zone: ${_zoneText()} (this phone)',
              style: const TextStyle(fontSize: 12, color: AppTheme.mediumText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(ThemeData theme, List<ClassScheduleSlot> slots) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, Icons.alarm, 'Reminder'),
          const SizedBox(height: 6),
          Text(
            'Send relative to one of this class\'s weekly schedule slots.',
            style: const TextStyle(fontSize: 12, color: AppTheme.mediumText),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (slots.isEmpty)
            Text(
              'This class has no schedule slots yet. Add them from the class schedule first.',
              style: const TextStyle(fontSize: 12, color: AppTheme.errorRed),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _scheduleSlotId,
              decoration: _inputDecoration(labelText: 'Class slot *'),
              items: [
                for (final slot in slots)
                  DropdownMenuItem(
                    value: slot.id,
                    child: Text(
                      '${_dayShort(slot.day)} ${_two(slot.hour)}:${_two(slot.minute)}'
                      ' · ${slot.timezone}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _scheduleSlotId = value),
            ),
          const SizedBox(height: AppTheme.spacingMD),
          DropdownButtonFormField<int>(
            initialValue: _offsetMinutes,
            decoration: _inputDecoration(labelText: 'When *'),
            items: const [
              DropdownMenuItem(value: -15, child: Text('15 minutes before')),
              DropdownMenuItem(value: -60, child: Text('1 hour before')),
              DropdownMenuItem(value: -1440, child: Text('1 day before')),
              DropdownMenuItem(value: 15, child: Text('15 minutes after')),
            ],
            onChanged: (value) => setState(() => _offsetMinutes = value ?? -15),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primaryGreen,
            title: const Text(
              'Repeat every week',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Off sends it once, at the next matching slot.',
              style: TextStyle(fontSize: 12),
            ),
            value: _reminderRepeatWeekly,
            onChanged: (value) => setState(() => _reminderRepeatWeekly = value),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLinkCard(ThemeData theme) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 20, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Action Link (Optional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tapping the notification opens this link or app page.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mediumText,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          TextFormField(
            controller: _actionLinkController,
            decoration: _inputDecoration(
              hintText:
                  'https://example.com or /classes/${widget.classId}/syllabus',
              prefixIcon: const Icon(
                Icons.open_in_new,
                color: AppTheme.mediumText,
              ),
            ),
            maxLength: 500,
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(
    String classDisplayName,
    List<ClassScheduleSlot> slots,
  ) {
    final label = switch (_mode) {
      _NotifyMode.now => 'Send to Class Students',
      _NotifyMode.schedule => 'Schedule Notification',
      _NotifyMode.reminder => 'Save Reminder',
    };

    return FilledButton(
      onPressed: _isSending
          ? null
          : () => _handleSubmit(classDisplayName, slots),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
      ),
      child: _isSending
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _mode == _NotifyMode.now
                      ? 'Sending Notification...'
                      : 'Saving...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _mode == _NotifyMode.now
                      ? Icons.send_rounded
                      : Icons.schedule_send_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }

  Widget _sectionTitle(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      alignLabelWithHint: alignLabelWithHint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: BorderSide(color: AppTheme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = widget.clock?.call() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _sendDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => _sendDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sendTime ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _sendTime = picked);
    }
  }
}

String _dayShort(int day) => switch (day) {
  1 => 'Mon',
  2 => 'Tue',
  3 => 'Wed',
  4 => 'Thu',
  5 => 'Fri',
  6 => 'Sat',
  7 => 'Sun',
  _ => '—',
};

String _two(int value) => value.toString().padLeft(2, '0');

String _offsetLabel(int minutes) {
  final abs = minutes.abs();
  final unit = abs % 1440 == 0
      ? '${abs ~/ 1440} day${abs == 1440 ? '' : 's'}'
      : abs % 60 == 0
      ? '${abs ~/ 60} hr'
      : '$abs min';
  return minutes < 0 ? '$unit before' : '$unit after';
}
