# domains/notifications/

Push, WhatsApp reminders, devices, scheduled class notifications and the notifier.

## Status

**Tables, the notify-core and WhatsApp slices (below) and published commands (12 Nov 2026, build-out: ported, not yet proven against PHP).** The public interfaces are `NotificationsCommands` (announce to members) and `NotificationsErasure` (account deletion). Catalog: `docs/specs/initial-build/operations.csv`; notes: `docs/specs/initial-build/lane-notify-core-notes.md`, `lane-whatsapp-notes.md`, `lane-sheets-notes.md`.
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `notifications`, 8 tables: `notifications`, `user_notifications`, `user_devices`, `notifier_reminders`, `notifier_runs`, `notifier_sent_messages`, `class_scheduled_notifications`, `class_scheduled_notification_runs` | built; migration `Initial` |
| The Node notifier | keeps its own MariaDB connection until this domain is filled (design decision 6) |
| `ON UPDATE CURRENT_TIMESTAMP` of `user_devices.last_accessed_at` and `notifier_reminders.updated_at`, `class_scheduled_notifications.updated_at` | not ported: the handler that updates the row sets it |

## Owns

- Schema `notifications` (above). Names, keys and indexes follow PHP's. A class, a schedule slot or a member is a plain integer; the two foreign keys PHP declares
  (`user_notifications` to `notifications`, `notifier_sent_messages` to `notifier_runs`) stay inside the schema.
- **Wall-clock columns** (not instants): `class_scheduled_notifications.send_at` is `timestamp without time zone`; `send_time` here and in `notifier_reminders` is `time`.
  They are read in the row's own zone (`tz`, `timezone`). Every other date-time is `timestamptz`, read as UTC.
- Dependencies: `access` (only because platform needs it to start), `platform` (`PlatformCommands.QueueMessagesAsync`, the push queue), `identity` (SQL read of `identity.v_users`: token and email, to leave the demo cohort out).
- Published command (`NotificationsCommands.AnnounceAsync(db, Announcement, ct)`, on the caller's open transaction; nothing is sent, no worker exists): the inbox copy (found again by title, body and link among system notifications, else created with created_by 0 and fanned out) and one queued push per device, deduped by the caller's key. `Announcement(Title, Body, ActionLink, DataType, DedupeKey, Tokens)`: `Tokens` null is every registered member, else exactly those member tokens (a class lane passes the class's students). First caller: assessment's quiz settings refresh. `Announcement.Extras` (`AnnouncementExtras`: criteria JSON, sender, extra push data, leave demo devices out) records a member-sent notification as a NEW row; `NotificationsCommands.LastNudgeAsync(db, teacher, hours)` is the newest `CC_NUDGE` notification to a teacher. Caller: classes' `POST /reports/pending/nudge`.
- Events: none published, none consumed.
- Dependencies: `access` (`Permissions`) and `platform` (`PlatformCommands.RecordAdminAccessAsync`); `NotificationsModule.Dependencies`. Read through published views only: `classes.v_classes`, `v_enrolments`, `v_class_schedules`, `v_class_levels`, `identity.v_users`, `membership.v_members`, `platform.v_genders`.
- Push: `IPushSender` (`api/domain/IPushSender.cs`, internal), real implementation `FcmPushSender` (FCM HTTP v1, setting `TSR_GOOGLE_SERVICE_ACCOUNT_B64`, optional: without it the push routes answer 500 "Push notifications are not configured").
- **Lane notify-core (12 Nov 2026):** devices (`device-register`, `device-remove`), the member inbox (`user-notifications*`, `user-notification-read`), announcements (`notifications-send`, `-history`, `-cleanup`, `-stats`) and class notifications (`class-notification-send`, `class-scheduled-create|list|delete`), all under `api/features/`, routes registered by `api/NotifyCoreRoutes.cs`. Shared: `domain/NotificationWriter.cs` (a notification and its inbox fan-out, one transaction, the `notifications.sent` event), `Audience.cs`, `PushBatch.cs`, `ScheduleInput.cs`, `ScheduleNextRun.cs`. Not built: the workers that send scheduled class notifications and drain the push queue. Notes: `docs/specs/initial-build/lane-notify-core-notes.md`.
- Events (outbox, in the transaction of the change; no consumer yet; never a device token, title or body):

| Event | Payload | Written by |
|---|---|---|
| `notifications.device_registered` | token, reassignedFrom (count) | POST /devices |
| `notifications.device_removed` | token | DELETE /devices |
| `notifications.sent` | notificationId, recipientCount, source (`announcement`, `class`), sentBy | POST /notifications/send, POST /classes/{id}/notifications |
| `notifications.invalid_devices_removed` | count | POST /notifications/cleanup-invalid-tokens |
| `notifications.class_schedule_created` | id, classId, kind, createdBy | POST .../notifications/scheduled |
| `notifications.class_schedule_deleted` | id, classId, deletedBy | DELETE .../notifications/scheduled/{id} |

  Consumed: none.

## Checks

```
dotnet test domains/notifications/api/tests   # the model: the 8 tables in schema "notifications"
dotnet test db/tests                          # the migrated database
```
