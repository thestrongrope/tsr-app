import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';
import '../models/scheduled_notification.dart';
import '../providers/providers.dart';

/// The class's scheduled and reminder notifications: list and delete. There is
/// deliberately no edit and no pause in v1: delete and recreate.
class ScheduledNotificationsScreen extends ConsumerStatefulWidget {
  final int classId;

  const ScheduledNotificationsScreen({super.key, required this.classId});

  @override
  ConsumerState<ScheduledNotificationsScreen> createState() =>
      _ScheduledNotificationsScreenState();
}

class _ScheduledNotificationsScreenState
    extends ConsumerState<ScheduledNotificationsScreen> {
  int? _busyId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      classScheduledNotificationsProvider(widget.classId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Notifications')),
      body: async.when(
        data: (payload) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(classScheduledNotificationsProvider(widget.classId));
            await ref.read(
              classScheduledNotificationsProvider(widget.classId).future,
            );
          },
          child: payload.items.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingLG),
                  itemCount: payload.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppTheme.spacingMD),
                  itemBuilder: (context, index) =>
                      _buildItem(context, payload.items[index]),
                ),
        ),
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
                  'Failed to load scheduled notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  userMessage(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.mediumText),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(
                    classScheduledNotificationsProvider(widget.classId),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 60),
        Icon(
          Icons.schedule_send_outlined,
          size: 56,
          color: AppTheme.mediumText,
        ),
        SizedBox(height: 16),
        Text(
          'Nothing scheduled',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Notifications you schedule or set as a reminder for this class will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.mediumText),
        ),
      ],
    );
  }

  Widget _buildItem(BuildContext context, ClassScheduledNotification item) {
    final busy = _busyId == item.id;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _chip(_kindLabel(item.kind), AppTheme.primaryGreen),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.body),
          if (item.actionLink != null && item.actionLink!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(item.actionLink!),
            ),
          const SizedBox(height: 6),
          Text(
            _scheduleSummary(item),
            style: const TextStyle(fontSize: 12, color: AppTheme.mediumText),
          ),
          const SizedBox(height: 10),
          _line(Icons.event_available_outlined, _nextRunLabel(item)),
          _line(
            Icons.person_outline,
            'Created by ${item.creatorName ?? 'a member'}',
          ),
          _line(Icons.circle, _statusLabel(item.status), small: true),
          if (item.lastRun != null) _line(Icons.history, _lastRunLabel(item)),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: busy ? null : () => _confirmDelete(item),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: small ? 8 : 14, color: AppTheme.mediumText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.mediumText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ClassScheduledNotification item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: const Text('Delete scheduled notification?'),
        content: Text(
          '"${item.title}" will be removed and will never send. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = item.id);
    try {
      await ref
          .read(classScheduledNotificationsRepositoryProvider)
          .delete(widget.classId, item.id);
      ref.invalidate(classScheduledNotificationsProvider(widget.classId));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(userMessage(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
  'ONCE' => 'Once',
  'WEEKLY' => 'Weekly',
  'REMINDER' => 'Reminder',
  _ => kind,
};

String _statusLabel(String status) => switch (status) {
  'active' => 'Active',
  'done' => 'Done',
  _ => status,
};

String _scheduleSummary(ClassScheduledNotification item) {
  if (item.kind == 'ONCE') {
    return 'Once, ${_formatWallClock(item.sendAt)} · ${item.timezone ?? '—'}';
  }
  if (item.kind == 'WEEKLY') {
    final days = item.weekdays.map(_dayShort).join(', ');
    return 'Every $days at ${item.sendTime ?? '—'} · ${item.timezone ?? '—'}';
  }
  final offset = item.offsetMinutes ?? 0;
  final when = item.schedule == null
      ? 'its class slot'
      : '${_dayShort(item.schedule!.day)} ${_two(item.schedule!.hour)}:${_two(item.schedule!.minute)}';
  return '${_offsetLabel(offset)} $when${item.repeatWeekly ? ' · every week' : ''}';
}

String _nextRunLabel(ClassScheduledNotification item) {
  if (item.nextRun == null) {
    return item.status == 'done' ? 'No further runs' : 'No next run';
  }
  final zone = item.timezone ?? item.schedule?.timezone;
  final label = _formatInstant(item.nextRun, zone);
  return zone == null ? 'Next: $label' : 'Next: $label · $zone';
}

String _lastRunLabel(ClassScheduledNotification item) {
  final run = item.lastRun!;
  if (run.skippedReason != null && run.skippedReason!.isNotEmpty) {
    return 'Last run skipped: ${_skipReasonLabel(run.skippedReason!)}';
  }
  if (run.deviceCount == 0) {
    return 'Last run sent nothing (no active devices)';
  }
  final delivery = run.delivery;
  if (delivery != null) {
    if (delivery.stillFailing > 0) {
      return 'Last run: ${delivery.sent} sent · ${delivery.stillFailing} still failing';
    }
    if (delivery.sent > 0) {
      return 'Last run: ${delivery.sent} sent';
    }
  }
  final devices = run.deviceCount == 1
      ? '1 device'
      : '${run.deviceCount} devices';
  return 'Last run: queued to $devices';
}

String _skipReasonLabel(String reason) => switch (reason) {
  'queue_failed' => 'the queue did not accept it; retrying',
  'schedule_missing' => 'its timetable slot was removed',
  'timezone_invalid' => 'its time zone was missing or invalid',
  'schedule_timezone_invalid' =>
    "its timetable slot's time zone was missing or invalid",
  'missed_window' => 'it missed its 2-hour window',
  'class_inactive' => 'the class is no longer active',
  'creator_lost_permission' => 'the sender can no longer send for this class',
  'dispatch_failed' => 'sending failed',
  'hourly_limit' => 'the hourly limit was reached',
  'daily_limit' => 'the daily limit was reached',
  _ => reason.replaceAll('_', ' '),
};

/// A wall-clock string with no offset, shown exactly as written.
String _formatWallClock(String? wallClock) {
  final parsed = wallClock == null ? null : DateTime.tryParse(wallClock);
  if (parsed == null) return '—';
  return '${_dayShort(parsed.weekday)} ${_date(parsed)} ${_two(parsed.hour)}:${_two(parsed.minute)}';
}

String _formatInstant(String? iso, String? zoneName) {
  if (iso == null || iso.isEmpty) return '—';
  final instant = DateTime.tryParse(iso);
  if (instant == null) return '—';
  try {
    final location = tz.getLocation(zoneName ?? '');
    final local = tz.TZDateTime.from(instant.toUtc(), location);
    return '${_dayShort(local.weekday)} ${_date(local)} ${_two(local.hour)}:${_two(local.minute)}';
  } catch (_) {
    final local = instant.toLocal();
    return '${_dayShort(local.weekday)} ${_date(local)} ${_two(local.hour)}:${_two(local.minute)}';
  }
}

String _offsetLabel(int minutes) {
  final abs = minutes.abs();
  final unit = abs % 1440 == 0
      ? '${abs ~/ 1440} day${abs == 1440 ? '' : 's'}'
      : abs % 60 == 0
      ? '${abs ~/ 60} hr'
      : '$abs min';
  return minutes < 0 ? '$unit before' : '$unit after';
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

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
