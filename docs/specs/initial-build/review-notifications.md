# Review: notifications (devices, inbox, broadcast, class notifications, WhatsApp, the nudge)

Independent, read-only review (Opus, `security` agent) of `dotnet-11` at `8e04e3b`, against `build/parity-php/src/web`, by the brief in `review-brief.md`. Received 12 Nov 2026. The reviewer ran no build, test, database or network call. Saved as received; see "Follow-up" at the end.

**Verdict:** one irreversible-action hole (S1): a broadcast or class push is tied to the request's lifetime, so a cancelled request stops the push partway and records nothing, which is looser than PHP. No authorization, row-scope, injection or data-exposure hole.

## Should-fix

**S1. A push cut off by a cancelled request leaves no record.**
- Where: `domains/notifications/api/features/notifications-send/NotificationsSend.cs:97-98`, `features/class-notification-send/ClassNotificationSend.cs:96-97`, `features/notifications-cleanup/NotificationsCleanup.cs:84-85`, `domain/PushBatch.cs:68`, `domain/FcmPushSender.cs:98`.
- Mechanism: the handler's `ct` is `RequestAborted`. The gateway has `proxy_read_timeout 30s` (`hosts/gateway/default.conf:15`), but `PushBatch.Deadline` is 120 s, and `hosts/api` has no request-timeout middleware. When the push to all devices takes more than 30 s (about 445 devices, 16 at a time, with FCM slow), nginx gives up and `ct` is cancelled. `PushBatch` catches the cancellation only when `!ct.IsCancellationRequested`, and `RecordAsync` lets `OperationCanceledException` through on purpose.
- Result: some devices get the push; there is no notification row, no inbox rows and no `notifications.sent` event, and the admin sees a 504, which invites a retry that sends twice to the devices already reached. A client that drops off (app to the background, network falls) has the same effect. For cleanup, a partial "System Check" push goes out and no dead tokens are deleted.
- PHP (`routes/notifications.php:135-168`, `models/classnotifications.php:97-123`): under php-fpm the script keeps running after the client leaves, so PHP pushes and then records.
- Fix direction: after the first push starts, finish it and record it with `CancellationToken.None`, or decouple both from `RequestAborted`. Also bring the deadline under the gateway timeout.
- Reviewer: high on the mechanism, medium on how often it happens.

## Notes

- N1. Rate limits are in memory (`shared/api/MemberRateLimit`: `class_push`, `class_scheduled_create`, the WhatsApp link routes, `cc_nudge`). A restart resets them and each replica has its own. PHP keeps them in files (`functions.php:1168`), which survive restarts and are shared by all workers. The class push limit (10 an hour) is the only cap on a teacher pushing to every student.
- N2. Case comparison without a cast, in code nothing reaches today: `domain/NotificationWriter.cs:61` compares `target_audience_criteria = {criteria}` without `::citext`. Both callers pass `reuseSameCriteria: false`. Fix before the scheduled-notification worker uses it.
- N3. The WhatsApp link limit is keyed on `caller.Token`; PHP uses `'user'.$user['id']`. Accounts sharing a token share one bucket (stricter, not looser).
- N4. `TSR_NOTIFIER_URL` is set in neither compose file. Unset, `Notifier.cs:59-63` fails closed (502 or 503, nothing sent); PHP falls back to `http://notifier:3000`, so a production deploy that leaves the setting out would silently lose WhatsApp. The outbound URL cannot be steered by a caller: the path is a literal or an integer id, the query carries digits only, the setting may not carry a query or user info, redirects are not followed, answers are capped at 1 MB and 30 s, and no retry handler is registered, so a POST is never re-sent.
- N5. `NotificationsModule.Dependencies` (`NotificationsModule.cs:16`) leaves out `classes` and `membership`, although the domain's SQL reads `classes.v_*` and `membership.v_members`. `domains/notifications/CLAUDE.md` also gives two different Dependencies lines.
- N6. The 20-active-schedules check in `ClassScheduledCreate.cs:76` has no lock, so two creates at once can make 21. PHP has the same race.

## Checked and ruled out

- Devices: a member can only remove their own row (`DeviceRemove.cs:56`); registering is serialised per token by an advisory lock.
- Inbox: reads, counts and marks are scoped to `user_token = caller` (`UserNotifications.cs:59`, `UserNotificationRead.cs:38`).
- Scheduled delete: scoped by class id; the hard delete is PHP's (`classschedulednotifications.php:156`).
- Device tokens land in `platform.outbound_messages`, not the outbox. No event payload or log line holds a token, title, body, QR code or mobile number. The QR routes send `no-store` before sign-in.
- No NULL trap in `NOT IN` (`identity.users.token` is NOT NULL); no invalid JSON reaching the nudge's `::jsonb` cast (a CHECK requires `target_audience_criteria is json`).
- The nudge (`domains/classes/.../ReportPendingNudge.cs`) is tighter than PHP: a transaction with an advisory lock, the 24-hour window re-checked, and the teacher must be in the caller's own pending report.

## PHP looseness that was copied

- Device takeover: anyone who knows a device token takes the device over, case-insensitively.
- `POST /admin/whatsapp/test` messages any number, with no rate limit.
- Reminder run and broadcast: no rate limit, lock or idempotency key.
- Cleanup pushes a visible message to every device.
- The notifier's error status and text are forwarded as they are.
- Run messages return teacher mobile numbers to `whatsapp:manage` without `no-store`.
- For GENDER and CLASS_LEVEL, the device query and the inbox (member) query select different people.

## Guards no test would catch if deleted

- The 20000-recipient cap (`Audience.MaxRecipients` and the `TooLarge` refusals).
- The page cap of 200 (`NotifyGuards.MaxPage`).
- `AllowAutoRedirect = false` on the notifier client.
- The one-minute backoff after a refused FCM token exchange.
- The 500-token delete chunks in cleanup.

Covered: `NotifierSettings.IsValid` (`Notifier.Tests.cs`), the FCM dead-token rule (`FcmPushSender.Tests.cs`), the 18-digit cap on run query values (`whatsapp-new-api.hurl`).

## Not checked by the reviewer

How `access` resolves the scope of `notifications:send` for a class (the tests show another class's teacher and a gender administrator are refused); `PendingReport.LoadAsync` reach rules; FCM and the notifier against real services; the build and unit tests.

## Follow-up

- S1: confirmed by a second reviewer (Opus, read-only, told to disprove it), then fixed 12 Nov 2026: in the three routes the push and what follows it (the record, the dead-token delete) no longer use the request's token; `PushBatch` keeps its own 120 s deadline. Test `TestNotifyTests...REVIEW_S1` (the caller cancels during the push) failed first. Only the announcement route has that test; the class and cleanup routes got the same one-line change untested. Still open: the gateway gives up at 30 s, so a long push now completes and is recorded while the admin sees a 504 (a decision: raise the gateway timeout for these routes or cut the deadline).
- N1 to N6: open. N5 (the dependency list) and N2 (the uncast comparison) are small fixes not yet made.
