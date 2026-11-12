# domains/notifications/

Push, WhatsApp reminders, devices, scheduled class notifications and the notifier.

## Status

**Tables, the notify-core and WhatsApp slices (below) and published commands (12 Nov 2026; the notify-core routes are proven by the test lane: `docs/specs/initial-build/test-notify-notes.md`, Hurl `spec/tests/notify-*.hurl`, `tools/contract-notify.sh`).** The public interfaces are `NotificationsCommands` (announce to members) and `NotificationsErasure` (account deletion). Catalog: `docs/specs/initial-build/operations.csv`; notes: `docs/specs/initial-build/lane-notify-core-notes.md`, `lane-whatsapp-notes.md`, `lane-sheets-notes.md`.
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
- Published command (`NotificationsCommands.AnnounceAsync(db, Announcement, ct)`, on the caller's open transaction; nothing is sent, no worker exists): one queued push per device (deduped by the caller's key), then the inbox copy (found again by title, body and link among notifications of the same sender when `ReuseExisting`, else created and fanned out). `Announcement(Title, Body, ActionLink, DataType, DedupeKey, Tokens)`: `Tokens` null is every registered member, else exactly those member tokens (a class lane passes the class's students). Optional fields for a member's announcement: `Sender` (creator of the notification and the queued rows, default 0 the system), `Criteria`, `Data` (replaces the push's data object), `ReuseExisting` (false: a new notification every call), `CountsFromQueue` (success = rows queued), `SkipDemoDevices` (leave demo members' devices out of `Tokens`). `AnnounceCountedAsync` is the same and answers `AnnounceResult(Devices, Queued)`; `AnnounceAsync` returns `Queued`. The push is queued first because PHP sends (queues) before it records, and the counts kept on the notification need the queue's answer. Callers: assessment's quiz settings refresh (defaults), assessment's quiz publish, classes' `POST /reports/pending/nudge`. `NotificationsCommands.LastNudgeAsync(db, teacher, hours)` is the newest `CC_NUDGE` notification to a teacher.
- Events: none published, none consumed.
- **Owner decisions (12 Nov 2026; PHP does none of them):** `POST /devices` allows 10 registrations of a device id new to the member an hour (429, bucket `device_register`; a device the member already holds is never limited, so an app may register on every start) and holds at most 20 devices per member (a new device id beyond 20 deletes the least recently used rows, in the same transaction and advisory lock; re-registering a held id and the takeover are unchanged). A GENDER announcement uses one definition of the audience for the push and the inbox (`Audience.GenderCode`: first value 1 or 2, matched to the member's gender); CLASS_LEVEL still differs between its device and member queries (level id vs class id, removed enrolments), left as PHP. The gateway gives the three synchronous push routes (`/notifications/send`, `/classes/{id}/notifications`, `/notifications/cleanup-invalid-tokens`) `proxy_read_timeout 130s`. Tests: `db/tests/TestNotifyTests.cs`.
- Dependencies: `access` (`Permissions`) and `platform` (`PlatformCommands.RecordAdminAccessAsync`); `NotificationsModule.Dependencies`. Read through published views only: `classes.v_classes`, `v_enrolments`, `v_class_schedules`, `v_class_levels`, `identity.v_users`, `membership.v_members`, `platform.v_genders`.
- Push: `IPushSender` (`api/domain/IPushSender.cs`, internal), real implementation `FcmPushSender` (FCM HTTP v1, setting `TSR_GOOGLE_SERVICE_ACCOUNT_B64`, optional: without it the push routes answer 500 "Push notifications are not configured").
- **Lane notify-core (12 Nov 2026):** devices (`device-register`, `device-remove`), the member inbox (`user-notifications*`, `user-notification-read`), announcements (`notifications-send`, `-history`, `-cleanup`, `-stats`) and class notifications (`class-notification-send`, `class-scheduled-create|list|delete`), all under `api/features/`, routes registered by `api/NotifyCoreRoutes.cs`. Shared: `domain/NotificationWriter.cs` (a notification and its inbox fan-out, one transaction, the `notifications.sent` event), `Audience.cs`, `PushBatch.cs`, `ScheduleInput.cs`, `ScheduleNextRun.cs`. Not built: the worker that sends scheduled class notifications (the push drain is built, above). Notes: `docs/specs/initial-build/lane-notify-core-notes.md`.
- **Push drain worker (12 Nov 2026)**: `api/workers/PushDrain.cs` (one tick, PHP `cli/drain_push.php`) and `PushDrainWorker.cs` (the timer, once a minute). Runs ONLY in the host's run mode `--workers` with `push-drain` in `TSR_WORKERS` (`hosts/api/WorkerMode.cs`, loop base `shared/api/PeriodicWorker.cs`); `NotificationsModule.WorkerNames` and `AddNotificationsWorkers(services, enabled)` are the registration hook. The API containers never drain. **No compose or Dokploy service runs it yet**: the dev database holds real device tokens, so wiring a worker container is a separate decision. In worker mode the process needs `TSR_DB`, `TSR_GOTENBERG_URL` (platform validates it at start) and, to send, `TSR_GOOGLE_SERVICE_ACCOUNT_B64`; put `--workers` last on a command line.
  A tick: sender not configured, claim nothing; claim up to 50 `push` rows through `PlatformCommands.ClaimMessagesAsync`; send at most 16 at a time (the sender's own 10 s timeout); then record every outcome. Outcomes: sent; a past `deadline` (deadline first, as PHP; unreadable counts as none) or a payload that is not an object or lacks a text `title` and `body` is dead at once (`past_deadline`, `payload_invalid`; PHP burns attempts on the second, we end it: a retry cannot fix it); `TokenInvalid` and `Failed` burn the attempt (backoff, dead after the 5th; `token_invalid`, `send_failed`; no device row is deleted, only the cleanup route does that); `SenderMismatch` is dead at once; `Unavailable` (transport failure, token exchange refused, 401, PERMISSION_DENIED/UNAUTHENTICATED that is not a sender mismatch) releases the row and every row not started, with the attempt given back, and no further send starts (sends already running finish and are recorded). `PushResult` gained `Unavailable` and `SenderMismatch`; the three synchronous routes treat both as a failure, as before. Logs and the `error` column hold counts and reason codes only. Tests: `db/tests/TestPushDrainTests.cs`, `api/domain/FcmPushSender*.Tests.cs`.
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
