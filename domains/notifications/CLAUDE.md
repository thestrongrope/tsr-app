# domains/notifications/

Push, WhatsApp reminders, devices, the member inbox, scheduled class notifications, the class calendar and the notifier.
Owns schema `notifications` and two workers. The public interfaces are `NotificationsCommands` (announce to members) and
`NotificationsErasure` (account deletion).

## Status

Every operation is built. Routes and field shapes: `spec/api.yaml`. Each slice's header comment states its order of checks, limits and deviations from PHP.

| Group | Routes | Registered by |
|---|---|---|
| Devices, the member inbox, announcements, class notifications (send, scheduled create, list, delete) | 14 | `api/NotifyCoreRoutes.cs` |
| The calendar: `GET /me/calendar`, `PUT /me/calendar/settings`, `GET` and `POST /classes/{id}/scheduled-events`, `PATCH` and `DELETE .../{event_id}` | 6 | `api/NotifyCoreRoutes.cs` |
| `/admin/whatsapp/*`: proxies to the notifier, no table of this domain | 10 | `api/WhatsAppRoutes.cs` |

| Part | State |
|---|---|
| 10 tables in schema `notifications` | built; migrations `Initial` (8) and `CalendarEvents` (`class_scheduled_events`, `member_event_settings`) |
| The Node notifier | keeps its own MariaDB connection until this domain is filled (design decision 6) |
| `ON UPDATE CURRENT_TIMESTAMP` of `user_devices.last_accessed_at`, `notifier_reminders.updated_at`, `class_scheduled_notifications.updated_at` | not ported: the handler that updates the row sets it |

Tables, keys and the **wall-clock columns** (`send_at`, `send_time`: read in the row's own zone, not UTC): the summary of
`api/NotificationsContext.cs`.

## Dependencies

`access`, `identity`, `platform` (`NotificationsModule.Dependencies`).

- `access`: `Permissions`. The class schedule worker also needs `access` to start, which the host already registers.
- `platform`: `PlatformCommands.QueueMessagesAsync` (the push queue), `ClaimMessagesAsync` and the result commands (the push drain), `RecordAdminAccessAsync`.
- `identity`: SQL read of `identity.v_users` (token and email, to leave the demo cohort out).
- Read through published views only: `classes.v_classes`, `v_enrolments`, `v_class_schedules`, `v_class_levels`, `identity.v_users`, `membership.v_members`, `platform.v_genders`.

## Published commands

- `NotificationsCommands.AnnounceAsync(db, Announcement, ct)`, on the caller's open transaction; nothing is sent here: the push drain worker below sends what is queued, in worker mode only, and neither it nor the class schedule worker has been verified against real FCM. It queues one push per device (deduped by the caller's key), then writes the inbox copy. The push is queued first because PHP sends (queues) before it records, and the counts kept on the notification need the queue's answer. The fields of `Announcement` (`Tokens` null is every registered member) are described on the record in `api/NotificationsCommands.cs`. `AnnounceCountedAsync` is the same and answers `AnnounceResult(Devices, Queued)`; `AnnounceAsync` returns `Queued`.
- Callers: assessment's quiz settings refresh (defaults), assessment's quiz publish, classes' `POST /reports/pending/nudge`.
- `NotificationsCommands.LastNudgeAsync(db, teacher, hours)`: the newest `CC_NUDGE` notification to a teacher.
- `NotificationsErasure.EraseDevicesAsync` and `EraseEventSettingsAsync(db, token, ct)`: identity's deletion completion calls them, inside its transaction. The events a member created stay (PHP keeps them).

## Push and settings

`IPushSender` (`api/domain/IPushSender.cs`, internal), real implementation `FcmPushSender` (FCM HTTP v1).

| Setting | Meaning |
|---|---|
| `TSR_GOOGLE_SERVICE_ACCOUNT_B64` | Optional. Without it the push routes answer 500 "Push notifications are not configured" and the push drain claims nothing |
| `TSR_NOTIFIER_URL` | Optional. The notifier's address (`api/domain/NotifierSettings.cs`) |
| `TSR_WORKERS` | The workers to run in the mode `--workers`: `push-drain`, `class-schedules` |

The gateway gives the three synchronous push routes (`/notifications/send`, `/classes/{id}/notifications`,
`/notifications/cleanup-invalid-tokens`) `proxy_read_timeout 130s`. `PushResult` has `Unavailable` and `SenderMismatch`;
the three synchronous routes treat both as a failure.

## Workers

Both run ONLY in the host's run mode `--workers` with their name in `TSR_WORKERS` (`hosts/api/WorkerMode.cs`, loop base
`shared/api/PeriodicWorker.cs`); `NotificationsModule.WorkerNames` and `AddNotificationsWorkers(services, enabled)` are the
registration hook. The API containers never drain. **No stack runs a sending worker**: the compose files have a `workers` service behind the profile `workers`, the test stack names only `search-feed` and `content-refresh` in it, and the dev database holds real device tokens, so a sending worker there would push to real phones (`docs/testing.md`). Production is not wired.
In worker mode the process needs `TSR_DB`, `TSR_GOTENBERG_URL` (platform validates it at start) and, to send,
`TSR_GOOGLE_SERVICE_ACCOUNT_B64`; put `--workers` last on a command line. ONE worker instance is the supported setup.

**Push drain** (`push-drain`; `api/workers/PushDrain.cs` is one tick, `PushDrainWorker.cs` the timer, once a minute). A
tick takes batches of 50 rows for up to 50 seconds. What ends a tick, every outcome and its reason code: the class summary
of `PushDrain.cs`. **Unverified against real FCM** (fake sender only). Rules to keep:

- A payload that is not an object or lacks a text `title` and `body` is dead at once (`payload_invalid`). PHP burns attempts on it; we end it: a retry cannot fix it.
- No device row is deleted here (only the cleanup route does that). Logs and the `error` column hold counts and reason codes only.

**Class schedule worker** (`class-schedules`; `api/workers/ClassScheduleSend.cs` is one tick, `ClassScheduleLedger.cs` its
SQL, `ClassScheduleWorker.cs` the timer, once a minute; the pure due, lapsed and zone decisions are `domain/ScheduleDue.cs`).
It never sends: a due occurrence is queued for the push drain. The order of steps, the run reasons and the paging: the
class summary of `ClassScheduleSend.cs`. Unverified against real FCM. Rules to keep:

- Limits per class from the run ledger: 10 sends an hour, 3 a day in the row's zone; over a limit the occurrence is held (nothing written).
- The inbox copy goes to every current student, demo members included (only their devices are left out of the push), as PHP (`ClassNotificationsModel::audience`, `recordScheduledInbox`).
- **Known limits:** if the worker is down past the 2 hour grace after a slot's pushes were queued but before its claim transaction, the slot is recorded as `missed_window` although the push went out; the per-class limits are counted without a lock, so two worker instances could exceed a limit by one.
- **Differences from PHP:** an occurrence already claimed is skipped (PHP re-delivers it every minute of its grace window, writing nothing new); the inbox write and the claim are one transaction (PHP: inbox first, then claim); `queue_failed` is the queue command throwing (PHP reads the queue table to tell a duplicate from a failure; this domain may not).
- The citext guard `hosts/api/tests/SqlCitextCastTests` does not list `target_audience_criteria` yet.

## Rules specific to this domain

1. **Devices** (PHP has neither limit): `POST /devices` allows 10 registrations an hour of a device id new to the member (429, bucket `device_register`) and holds at most 20 devices per member; a device the member already holds is never limited, so an app may register on every start. Details: the header of `api/features/device-register/DeviceRegister.cs`.
2. **Audience**: a GENDER announcement uses one definition of the audience for the push and the inbox (`Audience.GenderCode`). CLASS_LEVEL still differs between its device and member queries (level id vs class id, removed enrolments), left as PHP.
3. **Who manages a class's events**: `notifications:send` on the class, as for sending to it; refusal 403 "You cannot manage events for this class". The class is NOT looked up first (PHP does not), so an unknown class is that 403 too, never a 404 (what `access` answers for a super administrator on an unknown or closed class is not pinned by a test here).
4. **Who edits an event**: its owner, or another sender once the owner can no longer send for the class (`takeover`; the owner does not change). While the owner keeps access nobody else edits or deletes it, a super administrator included.
5. **Who sees what** (`GET /me/calendar`): only a current STUDENT (enrolment `A`, not removed) of a live class sees its live events and live timetable slots. Teaching or administering a class puts nothing in one's own calendar.
6. **Settings sync** (`member_event_settings`, one row per member (identity's user id) and item key): the rules are in the header of `api/features/calendar-settings-sync/CalendarSettingsSync.cs` and in `domain/CalendarSettings.cs`.
7. **An event is not sent anywhere**: it is a calendar entry the app turns into local alerts; no worker reads the calendar tables. An event's zone is the creator's, and an edit never changes it.
8. **Calendar differences from PHP not stated in a slice header**: a `client_updated_at` in year 0000 is "Invalid client_updated_at"; `changes` as a non-empty JSON object with keys "0", "1", ... is refused (PHP reads it as a list); one outbox event per change (PHP has none). The others are in the slice headers, `domain/CalendarEventInput.cs` and `domain/WallClock.cs`.

## Events

Outbox, in the transaction of the change; no consumer yet; never a device token, title or body. Consumed: none.

| Event | Payload | Written by |
|---|---|---|
| `notifications.device_registered` | token, reassignedFrom (count) | POST /devices |
| `notifications.device_removed` | token | DELETE /devices |
| `notifications.sent` | notificationId, recipientCount, source (`announcement`, `class`), sentBy | POST /notifications/send, POST /classes/{id}/notifications |
| `notifications.invalid_devices_removed` | count | POST /notifications/cleanup-invalid-tokens |
| `notifications.class_schedule_created` | id, classId, kind, createdBy | POST .../notifications/scheduled |
| `notifications.class_schedule_deleted` | id, classId, deletedBy | DELETE .../notifications/scheduled/{id} |
| `notifications.class_event_created` | id, classId, createdBy | POST /classes/{id}/scheduled-events |
| `notifications.class_event_updated` | id, classId, updatedBy | PATCH .../scheduled-events/{id} |
| `notifications.class_event_deleted` | id, classId, deletedBy | DELETE .../scheduled-events/{id} |
| `notifications.event_settings_synced` | token, written (count; only when above zero) | PUT /me/calendar/settings |

## Where things are

| Need | File |
|---|---|
| The HTTP contract | `spec/api.yaml`; Hurl in `spec/tests/` (`notify-*.hurl`, `calendar-*.hurl`) |
| Module, dependencies, worker registration | `api/NotificationsModule.cs` |
| A slice (its header states order, limits, deviations) | `api/features/<slice>/` |
| A notification and its inbox fan-out (one transaction, the `notifications.sent` event) | `api/domain/NotificationWriter.cs` |
| Audiences, the synchronous push batch | `api/domain/Audience.cs`, `PushBatch.cs` |
| A scheduled notification's input, next run, due decision | `api/domain/ScheduleInput.cs`, `ScheduleNextRun.cs`, `ScheduleDue.cs` |
| Calendar: guard, who may edit, wire forms; an event's fields; the sync rules | `api/domain/ClassEvents.cs`, `CalendarEventInput.cs`, `CalendarSettings.cs` |
| The link rule, the zone check | `ClassMessage.Link`, `WallClock.Zone` (`api/domain/`) |
| The notifier boundary (WhatsApp) | `api/domain/INotifier.cs`, `Notifier.cs` |
| Background notes | `docs/specs/initial-build/lane-notify-core-notes.md`, `lane-whatsapp-notes.md`, `lane-sheets-notes.md`, `test-notify-notes.md`, `schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`; catalog `operations.csv` |

## Checks

```
dotnet test domains/notifications/api/tests   # the model: the 10 tables in schema "notifications", and the pure rules
dotnet test db/tests                          # the migrated database: TestNotifyTests, TestPushDrainTests, TestClassScheduleWorkerTests, TestCalendarTests
tools/contract-notify.sh test|parity          # spec/tests/notify-*.hurl
tools/contract-calendar.sh test|parity        # spec/tests/calendar-*.hurl
```

Other tests: `api/domain/FcmPushSender*.Tests.cs`, `ScheduleDue.Tests.cs` (DST, a zone that does not exist).
