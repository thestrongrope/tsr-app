# Docs cleanup, pass 1: notifications, platform, identity

Trim of three domain `CLAUDE.md` files to what an agent needs in order to act. No meaning was changed. Every removed
item was either confirmed in the named file or is dated history. Safety text was kept word for word.

| File | Before (bytes) | After (bytes) |
|---|---|---|
| `domains/notifications/CLAUDE.md` | 16795 | 12358 |
| `domains/platform/CLAUDE.md` | 12949 | 12334 |
| `domains/identity/CLAUDE.md` | 7753 | 7774 |

The size targets were not reached. These files held little dated history: most of their text is rules, safety text,
events tables and facts found in no other file, and those had to stay. platform and identity also gained pointer tables
("Where things are", the commands list). Further cuts need a decision (see "Why not smaller").

## Removed

| File | What was removed (short) | Where the fact still lives (path), or "history only" |
|---|---|---|
| notifications | Dates "12 Nov 2026" on the status, lanes, workers, calendar, owner decisions | history only |
| notifications | "proven by the test lane", "pass on PHP and on the new API (12 Nov 2026)", "Lane notify-core" as a name, "added to PHP after the route catalog was made", "PHP's two 2026_11_10 migrations" | history only (the notes paths are kept as "Background notes") |
| notifications | The names of the 8 tables of migration `Initial` | `domains/notifications/api/NotificationsContext.cs` (DbSets), `NotificationsEntities.cs` |
| notifications | Foreign keys kept inside the schema; plain-integer references; exact types of the wall-clock columns | `domains/notifications/api/NotificationsContext.cs` (class summary); a short pointer line remains |
| notifications | The fields of `Announcement` and the meaning of each optional field; how the inbox copy is found again | `domains/notifications/api/NotificationsCommands.cs` (record and method doc comments) |
| notifications | The list of notify-core slice names | `domains/notifications/api/NotifyCoreRoutes.cs`, `api/features/` |
| notifications | Push drain: what ends a tick, 16 sends at a time, the sender's 10 s timeout, each outcome and its reason code (`past_deadline`, `token_invalid`, `send_failed`, sender mismatch, `Unavailable` releases), a sender that throws, results recorded one by one, `Unrecorded`, the 10 minute lease | `domains/notifications/api/workers/PushDrain.cs` (class summary and comments), `domain/PushBatch.cs`, `domain/FcmPushSender.cs` (what is `Unavailable`), `domains/platform/api/PlatformCommands.Queue.cs` (lease) |
| notifications | Class schedule worker: cursor (200 a page, 25 pages), grace 7200 s, dedupe key `class-sched-<id>-<slotkey>`, payload deadline, the one-transaction step, the list of run reasons, "recorded once, retried" | `domains/notifications/api/workers/ClassScheduleSend.cs` (class summary, reason literals), `ClassScheduleLedger.cs`, `domain/ScheduleDue.cs`, `domain/NotificationWriter.cs` (`reuseSameCriteria`, joins the caller's transaction) |
| notifications | Device limits: "deletes the least recently used rows, in the same transaction and advisory lock; re-registering a held id and the takeover are unchanged" | `domains/notifications/api/features/device-register/DeviceRegister.cs` (header) |
| notifications | GENDER audience: "first value 1 or 2, matched to the member's gender" | `domains/notifications/api/domain/Audience.cs` (comment above `GenderCode`) |
| notifications | Calendar: the six slice names; an event is weekly with `weekdays` (1 = Monday) at `send_time`; at most 500 active a class under an advisory lock; soft delete; items deleted for oneself left out, all settings answered | headers of `api/features/calendar-get/CalendarGet.cs`, `class-event-create/ClassEventCreate.cs`, `class-event-delete/ClassEventDelete.cs`, `class-event-update/ClassEventUpdate.cs`; `domain/CalendarEventInput.cs`, `ClassEvents.cs` |
| notifications | Settings sync: last writer wins in whole milliseconds, tie to the greater `device_key`, 5 minute clock skew, tombstone never clears, `rejected`, one invalid change refuses the batch (at most 200), advisory lock on the user id | header of `api/features/calendar-settings-sync/CalendarSettingsSync.cs`; `domain/CalendarSettings.cs` |
| notifications | Calendar differences from PHP: advisory locks, zones of this host's tzdata, NUL is a 422, a racing second delete is a 404 | `ClassEventCreate.cs` and `CalendarSettingsSync.cs` headers, `domain/WallClock.cs`, `domain/CalendarEventInput.cs`, `ClassEventDelete.cs` header |
| notifications | `EraseEventSettingsAsync` "PHP `AccountDeletionModel::complete`" | `domains/notifications/api/NotificationsErasure.cs` |
| notifications | Tests named per paragraph | moved to the Checks section of the same file |
| platform | The stray table row above the title | moved into the Status table of the same file |
| platform | "contract tests pass", "Hurl on both", "batch B5d", "schema phase", "12 Nov 2026" on the lease decision | history only |
| platform | Event `platform.feedback_submitted` listed under "What it owns" | the Events section of the same file |
| platform | `RecordAdminAccessAsync`: the columns written (path, method, client address, user agent, referer cut to the column lengths, no session id), "on the caller's connection" | `domains/platform/api/PlatformCommands.cs` (doc comment) |
| platform | Queue: `ClaimedMessage(Id, Recipient, Payload, Attempts)`, "queued and due", oldest id first, `for update skip locked`, `attempts + 1`, `claimed_at = now`, the signature of each result command, what `MarkFailedAsync` returns | `domains/platform/api/PlatformCommands.Queue.cs` (doc comments) |
| platform | xlsx layout: bold title at 14, heading, header row, blank row, null and "" leave no cell, the sheet name rule (31 characters, forbidden characters) | `domains/platform/api/domain/ReportXlsx.cs` (class summary and comments) |
| platform | PDF: the Gotenberg route `POST /forms/chromium/convert/html` | `domains/platform/api/domain/GotenbergRenderer.cs` (class summary) |
| platform | "Feedback uses it for ..." sentence order in Dependencies; "so they call nothing in `access`" | reworded in place, the facts remain in the same section |
| platform | The "Placeholders" section | one line in Status of the same file |
| platform | `lane-small-notes.md` in the Status row | moved to "Where things are" |
| identity | "proved in the test phase", "(Hurl on PHP and the new API ...)", "since the schema phase", "decided 11 Nov 2026" on the email rule | history only (the Hurl files, the script and the db tests are named under "Where things are" and "Checks") |
| identity | The column list of `users` | `domains/identity/api/IdentityContext.cs` (the `User` entity) |
| identity | `ChangeEmailAsync`: "an address the member already has is left alone" | `domains/identity/api/IdentityCommands.cs` (doc comment) |
| identity | The PHP source names of the two commands (`canChangeEmail`, `updateStudentInClass`, `createClassStudent`) | `domains/identity/api/IdentityCommands.cs` (doc comments) |
| identity | The refusal texts of the sign-in (`Not authenticated`, `Invalid auth token`, `Email not present in token`, `User not found`, `Registration incomplete`, `Account deletion pending`); "without one nothing changes" | `domains/identity/api/CallerMiddleware.cs` (the literals); the order and statuses remain in the file |
| identity | The account deletion paragraph was split into bullets | same file, same words; nothing dropped |
| platform | Public routes: "build numbers, public store URLs, release notes and one announcement" | `domains/platform/capabilities/app-version.md` (APPVER-R1, R2), `spec/api.yaml` |
| identity | The "Placeholders" section | one line in Status of the same file |

Counts by kind: confirmed elsewhere 23 (notifications 12, platform 6, identity 5); history only 4 (notifications 2,
platform 1, identity 1); moved or reworded inside the same file 7.

## Added (pointers only, read from the code; no new rule)

| File | Added | Source |
|---|---|---|
| notifications | The route counts by group (14, 6, 10) and the WhatsApp row; `TSR_NOTIFIER_URL`; the "Where things are" table | `api/NotifyCoreRoutes.cs`, `api/WhatsAppRoutes.cs`, `api/domain/NotifierSettings.cs` |
| platform | `QueueMessagesAsync`, `EraseFeedbackAsync`, `RedactRecipientsAsync` in the commands table; `notifications` as a user of `RecordAdminAccessAsync`; the `capabilities/` row | `api/PlatformCommands.cs`; the old `domains/notifications/CLAUDE.md` and `domains/identity/CLAUDE.md` named them |
| identity | The "Where things are" table; `tools/contract-deletion.sh` under Checks | file names in `api/`; the old Status row |

## Kept, unsure

These were kept as written. Each looks stale or in conflict with another file, and a trim must not correct it.

| File | Text kept | Why unsure |
|---|---|---|
| notifications | "**No compose or Dokploy service runs it yet**: the dev database holds real device tokens, so wiring a worker container is a separate decision." | The root `CLAUDE.md` says `docker-compose.dev.yml` now has a `workers` service behind the profile `workers`. Safety text, kept word for word |
| notifications | "The push is queued first because PHP sends (queues) before it records" | The doc comment of `AnnounceAsync` in `api/NotificationsCommands.cs` says "the inbox copy first ... then one queued push". One of the two is stale |
| notifications | "nothing is sent here: the push drain worker below sends what is queued" | The class summary of `NotificationsCommands` still says "no worker reads the queue yet"; the summary of `NotificationsModule` still says "placeholder routes (Planned.cs) so far; no public interface yet". The code comments look stale, not this file |
| notifications | Dependencies: `access` "only because platform needs it to start" and also `access` (`Permissions`) | The old file gave both reasons in two bullets. Both are kept in one list |
| notifications | "The Node notifier keeps its own MariaDB connection until this domain is filled (design decision 6)" | The domain's routes are all built; whether "until filled" still describes the plan is not stated anywhere |
| notifications | "`PushResult` has `Unavailable` and `SenderMismatch`; the three synchronous routes treat both as a failure" | The enum is confirmed; the routes' handling was not checked in each slice |
| notifications | Year 0000, the JSON object with keys "0", "1", one outbox event per change, "a super administrator included", "not pinned by a test here" | Found in no slice header, so kept |
| notifications | The citext guard does not list `target_audience_criteria` "yet" | No match in `hosts/api/tests`; still true, but a to-do in a rules file |
| platform | "`spec/tests/*.hurl` (needs the dev stack up)", `tools/platform-contract.sh dev|parity`, and the Hurl check against `:8088` with `build/dev/token.vars` | The root `CLAUDE.md` says Hurl runs only on the TEST stack (:8089), never dev, because dev holds real data. These lines should probably say `test` |
| identity | `tools/identity-contract.sh dev` "Hurl contract on the dev stack" | The same conflict with the root `CLAUDE.md` |
| platform | "review feedback (issue 891) not designed" | An issue number that may belong to tsr-account |
| platform | "used by 9 classes and 3 membership download routes" | A count that may have moved; the access log download also uses it |
| platform | "Nothing relays or reads them yet (the relay comes with the foundation step)" | Plan wording that may be dated |
| identity | The account deletion bullets | The date "decided 12 Nov 2026" was dropped (history; also in the slice header as a decision). Every other clause was kept word for word although the slice header states most of them |
| identity | "Claim sync: not started" | No other file says what claim sync is |
| identity | Rule 11 of `domains/CLAUDE.md` says erasure is "Not built or tested yet"; this file says completion is built | Not my file; noted only |

## Why not smaller

- notifications: the events table (1.4 KB), the worker safety text and the PHP differences found only here are about half of the file.
- platform: the `ReportExport` section, the geo collation exception, the public-route reasons (rule 4 asks for them here) and the four feedback rules were kept in full. Rules 1 and 2 are also in `capabilities/submit-feedback.md` (FEEDBACK-D1, FEEDBACK-R2) and could become pointers.
- identity: the account deletion paragraph (1.3 KB) and "How a request is judged" (0.9 KB) are both stated in code (`AdminDeletionComplete.cs` header, `CallerMiddleware.cs`). They were kept because they are safety and sign-in rules. Turning them into pointers would bring the file to the target.
