import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/notification_settings_provider.dart';
import '../providers/providers.dart';

/// Opens a modal bottom sheet for configuring class notification preferences.
void showClassNotificationSettings(
  BuildContext context,
  WidgetRef ref, {
  required bool hasConductingClasses,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLG),
      ),
    ),
    builder: (_) => _ClassNotificationSettingsSheet(
      hasConductingClasses: hasConductingClasses,
    ),
  );
}

class _ClassNotificationSettingsSheet extends ConsumerWidget {
  const _ClassNotificationSettingsSheet({required this.hasConductingClasses});

  final bool hasConductingClasses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLG,
          vertical: AppTheme.spacingMD,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule Notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Configure reminders for your upcoming classes and reports.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mediumText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLG),

            Divider(height: 1, color: AppTheme.dividerColor),

            // Class Reminder toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppTheme.primaryGreen,
              title: Text(
                'Class Start Reminder',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              subtitle: Text(
                'Receive an alert 15 minutes before scheduled class time',
                style: TextStyle(fontSize: 12, color: AppTheme.mediumText),
              ),
              value: settings.classReminderEnabled,
              onChanged: (value) async {
                // Await the write: the setter only assigns `state` after its
                // box put completes, so rescheduling before it lands would
                // read the pre-toggle value and re-arm what was just switched
                // off.
                await ref
                    .read(notificationSettingsProvider.notifier)
                    .setClassReminderEnabled(value);
                _rescheduleAll(ref);
              },
            ),

            // Conduction Reminder toggle — visible for teachers and class admins
            if (hasConductingClasses) ...[
              Divider(height: 1, color: AppTheme.dividerColor),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryGreen,
                title: Text(
                  'Class Conduction Reminder (Teacher & Class Admin)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                subtitle: Text(
                  'Reminder for teachers and class admins to log session report 45 minutes after class begins',
                  style: TextStyle(fontSize: 12, color: AppTheme.mediumText),
                ),
                value: settings.conductionReminderEnabled,
                onChanged: (value) async {
                  await ref
                      .read(notificationSettingsProvider.notifier)
                      .setConductionReminderEnabled(value);
                  _rescheduleAll(ref);
                },
              ),
            ],

            const SizedBox(height: AppTheme.spacingLG),

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.mediumText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Class reminders are scheduled on your device based on your enrolled schedule and function reliably even without an active internet connection.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
          ],
        ),
      ),
    );
  }

  /// Reads the latest settings and classes, then reschedules all notifications.
  void _rescheduleAll(WidgetRef ref) {
    final classesState = ref.read(classesProvider);
    if (classesState.classes != null) {
      ref
          .read(classesProvider.notifier)
          .rescheduleNotifications(classesState.classes!);
    }
  }
}
