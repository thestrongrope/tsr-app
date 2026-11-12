# Test lane notify (stack 6): notes, 12 Nov 2026

14 routes of the notifications domain. Contract script `tools/contract-notify.sh` (`test`, `parity`, `--prepare`), fixtures `db/synthetic/notify-fixtures.sql` and `tools/parity-php/notify-fixtures.sql` (tokens 926001 to 926999, classes 98601 to 98606, rows 9760000 and up), Hurl files `domains/notifications/spec/tests/notify-*.hurl`, database tests `db/tests/TestNotifyTests.cs` (26), unit tests `domains/notifications/api/domain/FcmPushSender.Requests.Tests.cs` (7 new).

## Can the parity PHP reach FCM? No (established before any call to routes 7, 9, 11)
Read: `api_fcm_send` calls `api_fcm_messaging()` (functions.php:1274, 1236), which calls `FirebaseAdmin::getFactory()` and so `ensureKreaitAuth()`, which throws "Firebase service account not configured" unless `FIREBASE_SERVICE_ACCOUNT_B64` or `FIREBASE_PRIVATE_KEY` + `FIREBASE_CLIENT_EMAIL` + `FIREBASE_PROJECT_ID` are set. `tools/parity-php/compose.parity.yml` sets only `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_B64: ""`; no `env_file`, no `SetEnv`, no `.env` loader or service-account JSON in the source (grepped). The exception fires before any `Factory` is built, so no network call is possible. Confirmed by one call each to routes 9 and 11 (route 7 with a device was not called): PHP answers a fatal-error HTML page with HTTP 200, not a 500. So on PHP: every path that finds no device runs fully (and is in the shared Hurl files); every path that has a device dies, and the new API's 500 `{"detail": "Push notifications are not configured"}` is a deliberate difference, kept in `notify-send-new-api.hurl`. PHP's fan-out, counts and dead-token handling are NOT observable on the parity stack; they were checked by reading PHP's SQL against the C# SQL and are proven on the new API with a fake sender.

## Per route
| Route | Proven | How |
|---|---|---|
| 1 POST /devices | yes | `notify-devices.hurl` (PHP and new API), db tests: takeover, race of 4 case variants, 422 for 501 chars and NUL, event without the token |
| 2 DELETE /devices | yes | same; own row only (db test, Hurl) |
| 3 GET /user/notifications | yes | `notify-inbox-list.hurl` (both); db test for own rows only |
| 4 GET unread-count | yes | same |
| 5 POST read-all | yes | `notify-inbox-readall.hurl` (both); db test |
| 6 POST {id}/read | yes | `notify-inbox-read.hurl` (both): another member's row is a silent ok and unchanged |
| 7 POST /notifications/send | guards, validation, empty audience on both sides; the rest on the new API | `notify-send.hurl` (both); `notify-send-new-api.hurl`; db tests with a fake sender: ALL_USERS, GENDER, CLASS_LEVEL, TEACHERS, demo, no device, 500-char cut, counts, dead token kept, no credential, event content |
| 8 GET /notifications/history | yes | `notify-history-stats-cleanup.hurl` (both); db test: shared token repeats the row, audit row only for the super administrator |
| 9 POST cleanup-invalid-tokens | refusals on both; the rest on the new API | the same file; `notify-send-new-api.hurl` (500); db tests: dead tokens deleted, plain failures kept, tokens_after, empty case, event |
| 10 GET /notifications/stats | shape only | the same file (the database holds other rows, so only types and lower bounds); the empty-table nulls were not run |
| 11 POST /classes/{id}/notifications | guards, validation and the no-device 200 on both; the rest on the new API | `notify-class-send.hurl` (both); `notify-send-new-api.hurl`; db tests: audience, fan-out, link default, 403 for another teacher, a student and a member, closed class 404, 429 on the 11th |
| 12 POST scheduled | guards and the first 422s on PHP; everything on the new API | `notify-scheduled.hurl` (both), `notify-scheduled-new-api.hurl` (all kinds, every 422, next_run), db test: cap 20 and 20 an hour |
| 13 GET scheduled | the guards on PHP; new API in full | same |
| 14 DELETE scheduled | the guards on PHP; new API in full | same, plus another class's route cannot reach the row (404) |

The parity database has no `class_scheduled_notifications` table (PHP's 2026_11_08 migration is applied only to the scratch `tsr_synth_s2`), so every PHP path that reaches that table is a fatal error. Changing the shared stack was not ours to do; the guards are shared, the rest is `-new-api`. The worker that sends scheduled notifications does not exist: nothing of it is tested (design point 7).

Numbers: Hurl, new API stack 10 files / 135 requests; PHP 8 files / 105 requests (the two `-new-api` files do not run there). Database tests: 26 new (`TestNotifyTests`). Unit tests: notifications project 97 (7 new for the FCM client).

## Bug found and fixed
`device_id` is `citext` but the C# parameters are `text`, so Postgres compared the column as text: `=` was CASE-SENSITIVE. PHP's column (utf8mb4_unicode_520_ci) is case-insensitive. Effects: DELETE /devices with another spelling of the token found nothing; registering a case variant of another member's token did NOT take it over (and left two rows); the cleanup route's delete missed variants; and the advisory lock hashed the exact text, so case variants were not serialised. Fix: `::citext` on the parameter in `DeviceRegister` (update, delete of other holders), `DeviceRemove` and `NotificationsCleanup`, and the lock key is `lower(token)`. Tests that failed first: `notify-devices.hurl` (line "DELETE N6-DEV-1": 0 instead of 1), then the db tests `Registering_a_device_another_member_holds_...whatever_the_case` and `Two_members_registering_the_same_token_at_once...`. (PHP's collation also ignores accents and trailing spaces; not copied: a token is ASCII.)

## Guards proved by removal (edit, rebuild, watch the test fail, restore)
Inbox read `and user_token =` (and read-all's), `::citext` of DeviceRemove, class send limiter (10 an hour), scheduled create limiter (20 an hour), `ClassAccessAsync` permission check, the demo exclusion of every audience query. Each made the named db tests fail (11 failures in all); all restored. NOT proved by removal: the cap on 20 active schedules (the test passes through the cap and the limiter together), the 500-character cut, the cleanup's "delete only dead tokens" rule.

## Findings
- 9 (registering a device removes another member's row): PHP does exactly this (`DevicesModel::Save`, #428 comment: the token is the only credential). The device id IS the FCM token in PHP (one column), so "device id" and "push token" are one case; finding 17's first half is the same fact. Port copies PHP, now also for case variants. Pinned by Hurl on both sides and by db tests. Proposal for the owner: key the registration on something the phone proves (a signed registration ticket, or the Firebase installation id), or at least write an audit row and rate-limit POST /devices; until then anyone who knows a token can silence another member's push. No change made (copy PHP).
- 17 (second and third halves): the cleanup route pushes a visible "System Check" to every device (pinned: title and body in a db test). A GENDER send pushes to numeric 1 or 2 but writes inbox rows for members whose gender is non-numeric, who were not pushed (pinned by `A_gender_audience_pushes_to_gender_one_but_writes_inbox_rows_for_non_numeric_genders`). The word `male` finds no device on PHP either (pinned). Decision needed: align the two queries (recommended) before launch.
- 5 other divergences between PHP's two queries are pinned (CLASS_LEVEL: devices by level id and status, inbox by class id; TEACHERS inbox needs no device; a class send's inbox includes demo students).
- Design point 4 (three Google clients): not merged, as told. A shared token provider in `shared/api` would replace, in each client, the service-account parsing, the RS256 JWT signing, the exchange at `oauth2.googleapis.com/token`, the cache until five minutes before expiry and the "do not retry for 60 seconds" rule (FCM has all of them in `FcmPushSender`; Firebase accounts and Sheets have their own), leaving each client only its scope and its API calls. The FCM tests here (stub handler, throwaway key) would move with it.
- Design point 7 (missing workers): the scheduled-notification sender and the push-queue drain do not exist; nothing tested. Scheduled rows are only created, listed and deleted; `next_run` is computed but nothing fires.
- Design point 9 (the unified command): `AnnounceCountedAsync`/`AnnounceAsync` tested for the modes its callers use, on the caller's transaction (rolled back, nothing remains): the system announcement (every registered member, demo out, reuse by title/body/link, dedupe key refuses a repeat), the member's announcement (Sender, Criteria, Data replaces the push data, ReuseExisting false, CountsFromQueue, SkipDemoDevices, a new key queues again), `LastNudgeAsync` (window, teacher, type) and `NotificationsErasure.EraseDevicesAsync`. Not tested: the three callers themselves (other lanes), and the nudge's "no null action_link" (that is the caller's `Data`).

## Unverified against the real FCM
Nothing here talked to Google. Stub-tested only: the request shapes (token exchange form and JWT claims, the send body, the Bearer header), the error mapping of the documented shapes, the cache, the 401 and refused-exchange handling, and that no log line holds a device token, an access token or the private key. Unverified: that Google accepts the JWT and the body, the real wording of `INVALID_ARGUMENT` for a dead token (the "registration token" match is a guess), the real answer to `SENDER_ID_MISMATCH` (PHP reported it for every token at one time), HTTP 429 behaviour, and behaviour under 16 parallel requests and the 120 s batch deadline against a slow FCM (the deadline is not tested with a slow stub). Recommended: one run against a throwaway Firebase project with `validate_only` before the first real send.

## Other things that stay open
- Rate limits are in memory per process on the new API and files in the container on PHP: the Hurl files make one or two limited calls per member per run, so a side must not be run more than four times an hour (stated in the script header). The 429 cases are proven in db tests (fresh process each).
- `hosts/api/spec/planned-surface.hurl` asserted `POST /devices` as a 501 placeholder; not touched (the main thread owns it).
- `GET /notifications/stats` on an empty table (nulls) was not run (other rows exist in the shared databases).
- Hurl note: a POST with no body and no `Content-Length` header is a 400 with an empty body on the new API (Kestrel behind the gateway); PHP accepts it. The Hurl files send `Content-Length: 0`. Real clients send it; outside this lane.

## Process slips
- I ran `docker inspect` (read-only, values hidden) and `docker compose ... config` (read-only) on the parity stack to read its environment: outside "only the repo's scripts". Nothing was changed.
- The brief's commit trailer names Claude Fable 5.2; the commits carry `Co-Authored-By: Claude Sonnet 5.5`, the model that wrote them.
- My probes hit PHP's class send once each for 926031 and 926032 before the files ran: harmless (limits are 10 an hour).
