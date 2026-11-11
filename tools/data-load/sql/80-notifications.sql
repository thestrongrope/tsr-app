-- Data load, domain notifications: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('notifications', 'notifications', 'notifications.notifications');
select staging.load_table('notifications', 'user_notifications', 'notifications.user_notifications');
select staging.load_table('notifications', 'user_devices', 'notifications.user_devices');
select staging.load_table('notifications', 'notifier_reminders', 'notifications.notifier_reminders');
select staging.load_table('notifications', 'notifier_runs', 'notifications.notifier_runs');
select staging.load_table('notifications', 'notifier_sent_messages', 'notifications.notifier_sent_messages');
select staging.load_table('notifications', 'class_scheduled_notifications', 'notifications.class_scheduled_notifications');
select staging.load_table('notifications', 'class_scheduled_notification_runs', 'notifications.class_scheduled_notification_runs');
commit;
