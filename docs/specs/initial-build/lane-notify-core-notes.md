# Lane notify-core: notes for the test phase

Mode: build-out (port first, prove later). 14 routes of the notifications domain built, none tested beyond unit tests; nothing was run against a database, a stack or FCM.
PHP paths are under `build/parity-php/src/web/`. Slices are `domains/notifications/api/features/<slice>/<Slice>.cs`; each file's header comment lists its rules, order and deviations.

## Routes

| # | Route | PHP | Slice | Reads | Writes |
|---|---|---|---|---|---|
| 1 | POST /devices | api/mobile/routes/devices.php:22, models/devices.php Save | device-register | user_devices | user_devices (update or insert, delete other members' rows of the token), outbox |
| 2 | DELETE /devices | devices.php:40, remove | device-remove | | user_devices (own row), outbox |
| 3 | GET /user/notifications | routes/notifications.php:318, models/mobilenotifications.php forUser, reminderClasses | user-notifications | user_notifications, notifications, classes.v_classes | |
| 4 | GET /user/notifications/unread-count | notifications.php:406 | user-notifications-unread-count | user_notifications | |
| 5 | POST /user/notifications/read-all | :394 | user-notifications-read-all | | user_notifications |
| 6 | POST /user/notifications/{id}/read | :382 | user-notification-read | | user_notifications (own row only) |
| 7 | POST /notifications/send | :73, lib/fcm.php, functions.php api_fcm_send | notifications-send | user_devices, v_users, v_members, v_enrolments, v_classes | FCM, notifications, user_notifications, outbox, admin_access_log (platform command) |
| 8 | GET /notifications/history | :188, mobilenotifications.php history, describe | notifications-history | notifications, user_notifications, v_users, v_members, v_class_levels, v_classes | admin_access_log |
| 9 | POST /notifications/cleanup-invalid-tokens | :242 | notifications-cleanup | user_devices | FCM, user_devices (delete), outbox, admin_access_log |
| 10 | GET /notifications/stats | :292 | notifications-stats | notifications | admin_access_log |
| 11 | POST /classes/{id}/notifications | routes/classes.php:510, models/classnotifications.php | class-notification-send | v_classes, v_genders, v_members, v_enrolments, user_devices | FCM, notifications, user_notifications, outbox |
| 12 | POST /classes/{id}/notifications/scheduled | classes.php:664, models/classschedulednotifications.php | class-scheduled-create | v_class_schedules, class_scheduled_notifications | class_scheduled_notifications, outbox |
| 13 | GET /classes/{id}/notifications/scheduled | :781 | class-scheduled-list | class_scheduled_notifications(+runs), v_class_schedules, v_members | |
| 14 | DELETE /classes/{id}/notifications/scheduled/{sid} | :806 | class-scheduled-delete | | class_scheduled_notifications, outbox |

All 14 are `create` in `operations.csv` (PHP `api_authenticate(true)`); rows 207 to 210 said `member` and were corrected. Counts were not touched.
New published views (classes migration `20261112120000_ClassScheduleAndLevelViews`, views only): `v_class_schedules` (id, class_id, day, hour, minute, timezone, deleted_at; deleted slots included) and `v_class_levels` (id, name).

## The sender and the writer

- `IPushSender` (`domain/IPushSender.cs`, internal): `bool IsConfigured`; `Task<PushResult> SendAsync(PushMessage message, string deviceToken, CancellationToken ct)`; `PushResult` = Sent, TokenInvalid, Failed; `PushMessage(Title, Body, Data)`.
- `FcmPushSender` (singleton): FCM HTTP v1, a JWT (RS256, built-in `RSA`) exchanged at `https://oauth2.googleapis.com/token`, cached until 5 minutes before expiry (singleton, one semaphore). Setting `TSR_GOOGLE_SERVICE_ACCOUNT_B64` (base64 of the service-account JSON: `project_id`, `client_email`, `private_key`). The file's own `token_uri` is ignored on purpose (fixed Google URL). Absent or unusable setting: the API starts, `IsConfigured` is false. HTTP client "fcm" has a 10 s timeout. Never logs the credential, an access token or a device token.
- `PushBatch.SendAsync(sender, title, body, data, deviceTokens, ct)` -> `PushReport(Success, Failure, Invalid)`: trims and de-duplicates, adds `click_action`, 16 requests in flight, 120 s for the whole batch (devices not reached count as failures). `PushBatch.CutBody` (500 code points), `SentAt` (PHP's `.000000`).
- `NotificationWriter.WriteAsync(db, clock, NewNotification(Title, Body, CriteriaJson, DeviceCount, SuccessCount, FailureCount, ActionLink, CreatedBy), memberTokens, source, reuseSameCriteria, ct)` -> `NotificationWritten(NotificationId, InboxRows)`. One transaction: the notification, the inbox rows (`insert ... select from unnest(...) on conflict do nothing`, the PHP INSERT IGNORE), the event `notifications.sent`. `reuseSameCriteria` is PHP `recordScheduledInbox`'s lookup (for the scheduled-send worker). Internal; meant to be exposed later as a published command.

## Missing workers (not part of this task)

1. The cron that fires scheduled class notifications (PHP `models/classschedulednotificationworker.php`, `cli/`): finds due rows (`dueFor`, `lapsedFor`, grace 2 h), claims a slot (`last_run_key`), sends, writes `class_scheduled_notification_runs`, enforces 10 sends an hour and 3 a day per class, finishes ONCE rows. Until it exists, nothing scheduled ever fires.
2. The push queue drain (`cli/drain_push.php`, `outbound_messages`).
3. The notifier (WhatsApp) stays Node (the other lane).

## Assumptions

1. A: "FCM not configured" behaves like PHP's uncaught exception: 500 `{"detail": "Push notifications are not configured"}` before anything is sent or written. PHP's own 500 body was not found (no exception handler located); the wording is ours.
2. A: a per-device failure (including FCM unreachable) is counted as a failure and the notification and inbox rows ARE written (PHP: a failing batch counts as failures, rows written).
3. A: the cap of 20000 devices or members per request is ours; over it is a 422 before anything is sent, never a silent cut. Today's audience is about 445 devices.
4. A: inbox and history `limit` is cut to 200 (PHP none); the scheduled list to 500; the echoed `limit` stays what was asked.
5. A: `api_find_class` is ported on views: active class (`v_classes`), gender row (`platform.v_genders`), teacher row (`membership.v_members`), level present (`level_name` not null).
6. A: one transaction for notification + fan-out + event (PHP could keep the notification when the fan-out failed). On a failed record the response still succeeds with `notification_id: null`.
7. A: the member list of an announcement is read BEFORE the push (so the cap cannot fail after sending). PHP reads it after.
8. A: demo exclusion is `identity.v_users.email ilike '%@demo.invalid'` (PHP `DEMO_EMAIL_PATTERN`); devices of a demo member are excluded by device id, as PHP.
9. A: PHP's `GENDER` device query compares `users.gender = 1 or 2` as a number in MariaDB; here it compares the text `'1'` or `'2'` (a gender stored as `'1.0'` or `' 1'` matched in PHP, not here).
10. A: `listIdentifiers()` refuses legacy zone aliases that .NET accepts (e.g. `US/Eastern`); the zone name must match `^[A-Za-z][A-Za-z0-9_+-]*(/...){0,2}$` and exist on the host. The API image (`mcr.microsoft.com/dotnet/aspnet:11.0`, Debian) is assumed to ship tzdata; not checked (no Docker). Without it every scheduled create is a 422.
11. A: dates on the wire: `created_at`, `last_run.run_at` as `Y-m-d H:i:s` (raw, as PHP); `sentAt`, `sent_at`, `readAt`, `last_sent_at` with a `T`; `next_run` ISO 8601 with the zone's offset; all UTC for instants.
12. A: `target_audience_criteria` is re-serialised by System.Text.Json (PHP's `json_encode` escapes `/` and non-ASCII differently); the history decodes it so no client sees a difference, but a scheduled-slot dedupe by exact criteria text must use one serializer.
13. A: a text with a NUL character, or a link over 500 characters, is a 422 (PHP stores NUL; the column holds 500).
14. A: `push.action_link_refused`, `push.rate_limited`, `device.reassigned` log events of PHP are not ported (the events and the 4xx carry the facts); the device registration event carries a count of moved rows.

## Unverified parts of the FCM client (verify with a real project, ideally `validate_only`)

- Request body: `{"message": {"token", "notification": {"title","body"}, "data": {string: string}, "android": {"priority":"HIGH","notification":{"sound":"default","channel_id":"high_importance_channel"}}, "apns": {"payload":{"aps":{"sound":"default","badge":1}}}}}`.
- Token exchange: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=<jwt>`, claims iss, scope `https://www.googleapis.com/auth/firebase.messaging`, aud, iat, exp; response `access_token`, `expires_in`.
- Error classification (`FcmPushSender.Classify`): a dead token is `UNREGISTERED` (in `error.details[].errorCode`) or status `NOT_FOUND`, or an `INVALID_ARGUMENT`/400 whose message contains "registration token". `INVALID_ARGUMENT` for a bad payload must NOT delete devices; the message match is a guess at Google's wording. Everything else (401, 403 SENDER_ID_MISMATCH, 429, 5xx) is a plain failure. PHP (Kreait) deleted `unknown` and `invalid` tokens.
- PHP reported that every token in production failed with `SenderId mismatch` at one time: expect that case to show as failures, not deletions.
- No retry and no backoff on 429 or 5xx (bounded work); a 401 clears the cached token for the next call.
- `PEM` import (`ImportFromPem`) of the service account's PKCS#8 key.

## Looks like a security or privacy hole in PHP (copied, flagged)

1. `POST /devices` lets any member register any FCM token, which moves the device from its current owner (only knowing the token is needed). A stolen or guessed token redirects someone's pushes. Rows are keyed by member and device id; a second member registering the same token deletes the first member's row.
2. `POST /notifications/cleanup-invalid-tokens` pushes a visible "System Check" to every device of every member to probe tokens, and one `INVALID_ARGUMENT` payload bug could delete them all (guarded here by the message match, see above).
3. `GENDER` audiences: the device query reads the number 1 or 2; the member query maps the WORDS male and female to 1 and 2 and any other value (a numeric 1 from the app too) to 0, and MariaDB reads 0 as every gender text that does not start with a non-zero digit (`'Male'`, empty). So a numeric GENDER send pushes to gender 1 or 2 but writes inbox rows for members with a non-numeric gender, who got no push. Ported as is (`Audience.GenderMembersAsync`); decide before launch.
4. `TEACHERS` with values that are all non-numeric means every active class's teacher.
5. `CLASS_LEVEL`: the device query matches the LEVEL id and ignores `removed_at` and the class status; the member query matches the CLASS id. The same value selects different people for the push and the inbox.
6. A class send includes demo members in the inbox fan-out (only devices are filtered).
7. The history joins senders through `users.token`, which is not unique: a shared token repeats the row and shows another account's name and email to the super admin.
8. The inbox `read` of another member's row is a silent ok (no 404), so it cannot be used to probe ids; kept.
9. `api_action_link_allowed` accepts any `https://` link: a super admin or a class teacher can push a phishing link. The in-app path list is restricted; `\z` replaces `$` here (a trailing newline is refused).
10. Rate limits are in memory per process (`MemberRateLimit`): a second API instance allows 10 and 20 each.
11. The class send reaches every student's devices with only `notifications:send` on that class (a class teacher); the 10 an hour limit is the only brake.

## Checklist for the test phase

- Contract (Hurl, both PHP and the new API, on the TEST stack only): every route's 401, 403 wording, 404, 422 wording and order (title, body, target, type, value, link; kind before the active cap before the zone before the kind fields; the rate limit AFTER the validations), the success shapes and key order, `201` on POST /devices and POST scheduled.
- A member reads and marks only their own inbox rows (`read` of another member's row changes nothing); `read-all` changes only theirs; device register/remove touch only their own row; a second member registering the same token takes it over and the first loses it.
- Devices: the same token twice by one member is one row (`last_accessed_at` moves); concurrent registration by two members leaves one owner (advisory lock); a 501-character token and a NUL are 422.
- Inbox: limit and offset parsing (`-1`, `abc`, empty, huge), ties on `sent_at`, `classes` for a CC_NUDGE row and an empty list for others, a removed class is left out.
- Announcement with a fake `IPushSender` (the seam exists for this): empty audience 200 and nothing written; not configured 500 and nothing written; counts; dead tokens NOT deleted on send; the body cut at 500 code points with a surrogate pair at the boundary; the criteria stored; fan-out of the MEMBER query (and its difference from the device query for CLASS_LEVEL and GENDER, test both and decide); demo devices and demo members excluded; `notifications.sent` event with a count and no text; 20001 devices is a 422.
- Cleanup: tokens FCM calls dead are deleted for every member; other failures leave them; `tokens_after` recount; empty case omits `tokens_after`; the event.
- Class send: 404, 403 (a member of another class, a teacher of another class, the class teacher, a coordinator), 429 on the 11th in an hour, no devices 200, the link default `/classes/N/dashboard`, an inbox row per active student only (removed and inactive enrolments excluded, token 0 excluded).
- Scheduled: each kind's valid and invalid fields; DST gap and fold (`WallClock`), a zone alias, `Asia/Calcutta` mapped; the 21st active is a 422; the 21st create in an hour is a 429 and invalid attempts do not count; REMINDER with another class's slot, a deleted slot, a slot whose zone is bad; `next_run` for the three kinds against PHP's value for the same instant; list ordering newest first, `last_run`, `schedule` of a deleted slot; delete of another class's row is a 404.
- History/stats: shared token repeats the row; the audience words for every type (unit tests exist in `AudienceWords.Tests.cs`); an empty criteria encodes as `[]`; stats on an empty table are nulls and `total_notifications` 0; the admin audit row is written for a privileged role only.
- Database tests (`db/tests`): the new views (`PublishedViewsTests` lists them), the unique `(notification_id, user_token)` index makes the fan-out idempotent, the `unnest` insert and `any(...)` queries run, `user_devices.device_id` is citext (case-insensitive equality: two tokens differing only by case would collide), `class_scheduled_notifications` check constraints, `send_time` as `time` round-trips as `HH:mm`.
- Security review: SSRF (the token endpoint is fixed; FCM URL uses only the project id from the credential), log scan for a token/title/body, JWT signing key handling, the 120 s deadline and 16-way parallelism under a slow FCM, the 10 s HTTP timeout.
- Unit tests that exist: `ActionLinks`, `ScheduleNextRun` (+ `WallClock` DST), `ScheduleInput`, `AnnouncementRequest` (+ body cut), `AudienceWords`.
