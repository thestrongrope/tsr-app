# domains/notifications/

Push, WhatsApp reminders, devices, scheduled class notifications and the notifier.

## Status

**Tables and placeholder routes (2026-11-10).** No slices; the one public interface is `NotificationsCommands` (below): every operation of this domain is a 501 placeholder in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
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
- Published command (`NotificationsCommands.AnnounceAsync(db, Announcement, ct)`, on the caller's open transaction; nothing is sent, no worker exists): the inbox copy (found again by title, body and link among system notifications, else created with created_by 0 and fanned out) and one queued push per device, deduped by the caller's key. `Announcement(Title, Body, ActionLink, DataType, DedupeKey, Tokens)`: `Tokens` null is every registered member, else exactly those member tokens (a class lane passes the class's students). First caller: assessment's quiz settings refresh.
- Events: none published, none consumed.

## Checks

```
dotnet test domains/notifications/api/tests   # the model: the 8 tables in schema "notifications"
dotnet test db/tests                          # the migrated database
```
