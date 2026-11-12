# domains/notifications/

Push, WhatsApp reminders, devices, scheduled class notifications and the notifier.

## Status

**Tables and placeholder routes (2026-11-10).** No slices and no public interface yet: every operation of this domain is a 501 placeholder in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
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
- Dependencies: `access` (`Permissions`) and `platform` (`PlatformCommands.RecordAdminAccessAsync`); `NotificationsModule.Dependencies`. Read through published views only: `classes.v_classes`, `v_enrolments`, `v_class_schedules`, `v_class_levels`, `identity.v_users`, `membership.v_members`, `platform.v_genders`.
- Push: `IPushSender` (`api/domain/IPushSender.cs`, internal), real implementation `FcmPushSender` (FCM HTTP v1, setting `TSR_GOOGLE_SERVICE_ACCOUNT_B64`, optional: without it the push routes answer 500 "Push notifications are not configured").
- **Lane notify-core (14 routes built, 12 Nov 2026):** devices (`device-register`, `device-remove`), the member inbox (`user-notifications*`, `user-notification-read`), announcements (`notifications-send`, `-history`, `-cleanup`, `-stats`) and class notifications (`class-notification-send`, `class-scheduled-create|list|delete`), all under `api/features/`, routes registered by `api/NotifyCoreRoutes.cs`. Shared: `domain/NotificationWriter.cs` (a notification and its inbox fan-out, one transaction, the `notifications.sent` event), `Audience.cs`, `PushBatch.cs`, `ScheduleInput.cs`, `ScheduleNextRun.cs`. Not built: the workers that send scheduled class notifications and drain the push queue. Notes: `docs/specs/initial-build/lane-notify-core-notes.md`.
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
