# Lane nudge: POST /reports/pending/nudge (build-out, 12 Nov 2026)

Slice: `domains/classes/api/features/report-pending-nudge/ReportPendingNudge.cs` (+ `.Tests.cs`: the message text). Catalog row now `classes`, `built`.

## PHP to C#

| Step | PHP | Here |
|---|---|---|
| sign-in, gender, `reports:read` (403) | reports.php:911-914 | `ReportScope.OpenAsync` |
| teacher int > 0 (422) | :917-920 | `PhpValue.IsInt` |
| `send === true` | :921 | `ValueKind == True` |
| months (default last month .. this month) | :923-927 | `ReportMonths.Check` |
| teacher in caller's pending report, else 422 | :932-942, mis.php pendingReport | `PendingReport.LoadAsync` (new, split out of `OpenAsync`; level "") |
| message | pendingnudge.php:31-66 | `Message` (pure, unit tested) |
| last reminded (24 h) | pendingnudge.php:99-111 | `NotificationsCommands.LastNudgeAsync` |
| dry-run answer | :949-960 | `Answer` |
| 429 already reminded; 429 rate (30/h, bucket cc_nudge) | :962-970 | same texts; `MemberRateLimit` |
| devices, FCM, `record`, fanOut | :972-990, pendingnudge.php:70-97, 117-135 | one transaction: lock, re-check, `AnnounceAsync`, outbox |

## Added to notifications
- `NotificationsCommands.LastNudgeAsync(db, teacher, windowHours)` (published read, time only; reads `notifications.notifications` criteria JSON).
- `Announcement.ActionLink` now `string?`; new optional `Announcement.Extras` (`AnnouncementExtras`: criteria JSON, sender, extra push data, skip demo devices). With Extras: a new row is always created (no system-notification lookup), created_by is the sender, demo members' devices are left out (PHP `deviceIds`), the push data carries `sent_at` and `class_ids`. Existing callers unchanged. `AnnouncementExtras` added to `PublicSurfaceTests`.
- notifications' `Planned.cs` and its registration removed (list empty). No migration.

## Assumptions
1. The route lives in classes (main thread's decision); `notifications` added to `ClassesModule.Dependencies` and the csproj.
2. Queued, not sent: `sent:true` means "recorded and queued"; `deviceCount` is the devices queued for; the notification row's device/success counts are the queued count (as `AnnounceAsync` does).
3. Months span at most 12 (PHP's nudge has none): bounded query. A wider range is 422 "The range can cover at most 12 months".
4. Default months use UTC dates.
5. Push dedupe key `cc_nudge:{teacher}:{unix seconds}`; `lastReminded` is the current time in UTC, `Y-m-d H:i:s`.
6. Answer teacher token is a JSON number (PHP int); a teacher token beyond int range finds nothing (422).
7. Rate limit is consumed before the in-transaction 24-hour re-check (a refused race still counts).

## Looks like a hole in PHP (copied, flagged)
- The 24-hour check and the record are not atomic in PHP: two coordinators can both nudge. Fixed here (advisory lock 7300001).
- PHP's rate limit is per sender only, not per teacher.
- The 24 hours are read from notifications, so an admin deleting the row re-opens the window.
- `from`/`to` of any year 2000-2099 were accepted by PHP's nudge (the 12-month cap here is a deviation).

## Test phase must prove
- 401 without sign-in; 403 without `reports:read`; gender lock honoured.
- 422: teacher missing, 0, negative, "5", 5.0, array, NUL text; bad months; from after to; range over 12 months; teacher with nothing pending; teacher outside the caller's reach / gender / assigned classes (same text).
- Dry run: figures and text, `alreadyReminded` and `lastReminded` after a send; no row written; `send:"true"` / 1 is a dry run.
- Send: 200 `sent:true`; notification row (created_by sender, criteria `{"type":"CC_NUDGE","teacher","classes"}`), one inbox row for the teacher, one queued push per device, push data (`type cc_reminder`, `class_ids`, `sent_at`), outbox `classes.teacher_nudged`.
- Demo teacher: row and inbox, 0 devices. Teacher with no device: 0.
- Second send within 24 h: 429; after 24 h: allowed. Two concurrent sends: one 200, one 429.
- 31st send in an hour by one sender: 429 "Too many reminders; try again later".
- Body over 500 characters cut with "and N more classes" (PHP parity with `mb_strlen`).
- Existing `AnnounceAsync` callers (assessment) unchanged.
- Parity against PHP: dry-run answers on the same fixtures.
