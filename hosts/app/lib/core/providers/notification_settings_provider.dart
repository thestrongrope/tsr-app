import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../constants/app_constants.dart';

/// User-facing settings that control scheduled class notifications.
class NotificationSettings {
  /// Whether to show a reminder before class starts.
  final bool classReminderEnabled;

  /// Whether to show a conduction-report reminder after class (teacher only).
  final bool conductionReminderEnabled;

  /// How many minutes before the scheduled class time the reminder fires.
  final int classReminderLeadMinutes;

  /// How many minutes after the scheduled class time the conduction reminder
  /// fires.
  final int conductionReminderDelayMinutes;

  const NotificationSettings({
    this.classReminderEnabled = true,
    this.conductionReminderEnabled = true,
    this.classReminderLeadMinutes = 15,
    this.conductionReminderDelayMinutes = 45,
  });

  NotificationSettings copyWith({
    bool? classReminderEnabled,
    bool? conductionReminderEnabled,
    int? classReminderLeadMinutes,
    int? conductionReminderDelayMinutes,
  }) {
    return NotificationSettings(
      classReminderEnabled: classReminderEnabled ?? this.classReminderEnabled,
      conductionReminderEnabled:
          conductionReminderEnabled ?? this.conductionReminderEnabled,
      classReminderLeadMinutes:
          classReminderLeadMinutes ?? this.classReminderLeadMinutes,
      conductionReminderDelayMinutes:
          conductionReminderDelayMinutes ?? this.conductionReminderDelayMinutes,
    );
  }
}

/// Riverpod [Notifier] backed by Hive's `settings_box`.
///
/// Reading is synchronous (Hive is in-memory), writing is fire-and-forget.
/// Whenever a toggle changes, the caller should also trigger
/// [ScheduledNotificationService.rescheduleAll] so alarms stay in sync.
class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  late final Box _box;

  @override
  NotificationSettings build() {
    _box = Hive.box(AppConstants.settingsBoxKey);
    return _readFromBox();
  }

  // ── Read ────────────────────────────────────────────────────────────────

  NotificationSettings _readFromBox() {
    return NotificationSettings(
      classReminderEnabled:
          _box.get(AppConstants.classReminderEnabledKey, defaultValue: true)
              as bool,
      conductionReminderEnabled:
          _box.get(
                AppConstants.conductionReminderEnabledKey,
                defaultValue: true,
              )
              as bool,
      classReminderLeadMinutes:
          _box.get(AppConstants.classReminderLeadMinutesKey, defaultValue: 15)
              as int,
      conductionReminderDelayMinutes:
          _box.get(
                AppConstants.conductionReminderDelayMinutesKey,
                defaultValue: 45,
              )
              as int,
    );
  }

  // ── Write ───────────────────────────────────────────────────────────────

  Future<void> setClassReminderEnabled(bool value) async {
    await _box.put(AppConstants.classReminderEnabledKey, value);
    state = state.copyWith(classReminderEnabled: value);
    debugPrint('🔔 Class reminder ${value ? "enabled" : "disabled"}');
  }

  Future<void> setConductionReminderEnabled(bool value) async {
    await _box.put(AppConstants.conductionReminderEnabledKey, value);
    state = state.copyWith(conductionReminderEnabled: value);
    debugPrint('🔔 Conduction reminder ${value ? "enabled" : "disabled"}');
  }

  Future<void> setClassReminderLeadMinutes(int minutes) async {
    await _box.put(AppConstants.classReminderLeadMinutesKey, minutes);
    state = state.copyWith(classReminderLeadMinutes: minutes);
  }

  Future<void> setConductionReminderDelayMinutes(int minutes) async {
    await _box.put(AppConstants.conductionReminderDelayMinutesKey, minutes);
    state = state.copyWith(conductionReminderDelayMinutes: minutes);
  }
}

/// Provider for notification settings.
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );
