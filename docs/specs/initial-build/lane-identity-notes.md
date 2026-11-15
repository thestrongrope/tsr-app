# Lane "identity": notes for the test phase

Build-out mode (12 Nov 2026): ported from PHP, gate = build + `hosts/api/tests` + `domains/identity/api/tests` only. Nothing ran against a database, stack or Google.
PHP paths are under `build/parity-php/src/web/`. All nine routes are `built` in `operations.csv`; the admin routes are `create` (PHP `api_authenticate(true)`).

## Routes

| # | Route | PHP | Slice (`domains/identity/api/features/`) | Reads | Writes |
|---|---|---|---|---|---|
| 1 | POST /auth/debug-token | auth.php:43 | `debug-token` | the bearer token only | nothing |
| 2 | POST /me/deletion-request | account_deletion.php:89 | `deletion-request-create` | `identity.users`, `membership.v_members` (name), the live request | `account_deletion_requests` insert (`on conflict do nothing`), outbox `identity.deletion_requested` |
| 3 | GET /me/deletion-request | :129 | `deletion-request-get` | the live request | nothing |
| 4 | DELETE /me/deletion-request | :148 | `deletion-request-cancel` | the live request, completed check | guarded update to cancelled, outbox `identity.deletion_cancelled` |
| 5 | GET /admin/deletion-requests | admin_deletion_requests.php:135 | `admin-deletion-list` | requests joined to `users`, `v_members`; counts; demo tokens | nothing |
| 6 | POST /admin/deletion-requests | :164 | `admin-deletion-raise` | `users` by email, `v_members` | as 2 with source `web` |
| 7 | POST .../{id}/hold | :203 | `admin-deletion-hold` | the request | guarded update to awaiting_prize_delivery (note, handled_by), outbox `identity.deletion_held` (only from pending) |
| 8 | POST .../{id}/confirmation-sent | :229 | `admin-deletion-confirmation-sent` | the request | stamps `confirmation_sent_at`, `handled_by` (once); no event; sends nothing |
| 9 | POST .../{id}/complete | :250, model accountdeletion.php:557 | `admin-deletion-complete` | request, `users`, `v_members` (mobile), demo tokens | see below |

Shared: `domain/DeletionRequests.cs` (reads, the insert, the permission gate, text validation), `domain/DeletionViews.cs` (wire shapes, wording; unit tests in `DeletionViews.Tests.cs`).

## Completion (route 9), in order

1. 404 unknown or non-positive id; 409 token <= 0; rate limit `MemberRateLimit.Allow("deletion_complete", requestId, 1, 60)` (in memory, so per process; held even when a refusal follows).
2. Refusals, each 409 with PHP's text: not live; no confirmation recorded; demo member (`users.email like '%@demo.invalid'`); token with no user row.
3. `IFirebaseAccounts.DeleteAsync(firebase_uid or null, email)` OUTSIDE the transaction (uid first, else lookup by email; "not found" is done). Failure: 409 with its message, database untouched.
4. ONE transaction: claim the request (`update ... set status='completed' where status live`; 0 rows = refused, nothing else written), then `NotificationsErasure.EraseDevicesAsync`, `PlatformCommands.RedactRecipientsAsync` (mobile + device ids), `IMemberErasure.EraseAsync` (membership), identity's own `users` update, `PlatformCommands.EraseFeedbackAsync`, outbox `identity.member_erased` {token, userId}, outbox `identity.deletion_completed` {requestId, token, handledBy}.
5. After commit: purge `contact_name`, `contact_email`, `reason` of completed requests older than 2 hours (PHP `purgeExpiredContactDetails`).

## Published commands added (what each erases)

- `NotificationsErasure.EraseDevicesAsync(db, token, ct)` (`domains/notifications/api/NotificationsErasure.cs`): reads (max 1000) then deletes every `notifications.user_devices` row of the token; returns the device ids.
- `PlatformCommands.EraseFeedbackAsync(db, userId, ct)`: `delete from platform.feedback where user_id`. PHP deletes for one user id only (the first row of the token); copied.
- `PlatformCommands.RedactRecipientsAsync(db, recipients, ct)`: `platform.outbound_messages.recipient = '[deleted]'` where it equals one of the values (max 1000). The rows stay.
- `MembershipCommands.EraseMemberAsync(db, token, ct)` through the port `IMemberErasure` (see Assumptions): `member_profiles` of every user row of the token: name `Deleted member`; first_name, last_name, picture, gender, age_range, country, state, city, zip null; mobile `''`; language 0; sendupdates `N`; unsubscribe `Y`. `class_registrations` of the token: residence_location, work_location, preferred_location, birth_year, profession, islamic_study_years, interests, other_interests, education, field_of_study, field_of_study_other, professional_courses, professional_courses_other, occupation_type, field_of_work, years_experience, role_level, linkedin_url, status_reason null (status, class, dates kept).
- identity's own update (every `users` row of the token): email `deleted-<token>@deleted.invalid`; firebase_uid, lastdevice, device, platform, version, lastloginip null. Kept: id, token, provider, createdon, lastlogin. PHP's columns `provider_id, region, lat, lng, location_details, timezone, browser` do not exist in this schema.

All new public types are in `PublicSurfaceTests` (`IMemberErasure`, `NotificationsErasure`); `PlatformCommands`/`MembershipCommands` were already listed.

## Assumptions

1. **Dependency cycle avoided with a port.** Identity cannot reference membership (membership references identity: an MSBuild cycle). So identity declares `IMemberErasure` (public, like `IProfileSink`); membership registers `MemberErasure` calling `MembershipCommands.EraseMemberAsync`. Without membership registered the default `NoMemberErasure` erases nothing: the host registers both. `IdentityModule.Dependencies` is `access, platform, notifications` (membership's `v_members` is read through SQL only, a published view). Please review: the alternative is an event handler (rule 11), which would not be in one transaction.
2. `IFirebaseAccounts.DeleteAsync(uid, email, ct)` takes the email as well as the uid, because PHP falls back to a lookup by email (most members have no stored uid).
3. Without `TSR_GOOGLE_SERVICE_ACCOUNT_B64` (and not in emulator mode) every completion is refused 409 "Firebase service account not configured ..." before the database is touched (PHP's behaviour with no service account). In emulator mode deleting is a no-op and completion proceeds. A malformed setting stops start-up (message never echoes the value).
4. PHP's `FIREBASE_PRIVATE_KEY`-style per-field credentials are not ported; only the base64 JSON. The token URI is fixed to Google's, not read from the JSON.
5. Only a `FirebaseAccountException` and the model's refusals are 409; a bug or database failure is a 500 (PHP answered 409 with `$e->getMessage()`, which can leak internals).
6. `/auth/debug-token` is blocked only when `IHostEnvironment.IsProduction()` (the default environment when none is set is Production). Staging serves it, as PHP serves any non-"production" APP_ENV. It decodes via the JWT bearer handler already used for sign-in (so the emulator's unsigned tokens work in Development) and reads email, name, provider from the claims, not from the emulator's account.
7. Admin routes use `RequireMember(createsMember: true)` as PHP's `api_authenticate(true)`.
8. The queue is limited to 1000 rows (PHP none); demo tokens to 1000. The member join takes the lowest user id of a token (PHP: arbitrary row of `limit 1`).
9. `reason`/`note` containing a NUL byte are 422 "... must be text" (PostgreSQL cannot store one; PHP stored it). An admin email with a NUL byte is "No account matches".
10. Contact name/email are cut to 200 characters when copied onto a request (the column limit; `users.email` allows 255).
11. Hold on an already held request replaces the note, answers 200, writes no event (not a state change). A confirmation stamp writes no event (not one of the four requested events).
12. The completion guard `update ... where status live` inside the transaction is an addition (PHP's update is unguarded): a concurrent cancel/complete wins instead of being overwritten.
13. `requested_at` is set by the API clock on insert (no column default is assumed).
14. Event payloads: ids only (`requestId`, `token`, `source`, `handledBy`, `userId`).
15. Refusal text for permission is `You do not have permission to do that` (as membership's `Refusals.NotPermitted`).

## Unverified: the Firebase client (`GoogleFirebaseAccounts.cs`, never run against Google)

- Token exchange: `POST https://oauth2.googleapis.com/token`, form `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`, `assertion` = RS256 JWT {iss=client_email, scope=`https://www.googleapis.com/auth/identitytoolkit`, aud=token endpoint, iat, exp=iat+3600}. Is that scope enough, or is `cloud-platform` needed?
- Lookup: `POST https://identitytoolkit.googleapis.com/v1/projects/{project}/accounts:lookup` body `{"email":["..."]}`, answer `users[0].localId`. Delete: `.../accounts:delete` body `{"localId":"..."}`. "Not found" is detected by the text `USER_NOT_FOUND` / `EMAIL_NOT_FOUND` anywhere in the answer body.
- Private key read with `RSA.ImportFromPem` (PKCS#8 as Google issues it). Access token cached until 60 s before `expires_in`. 10 s timeout, 64 KB response cap.
- Project check: the account's `project_id` must equal `TSR_FIREBASE_PROJECT_ID` or every delete is refused (PHP does the same).
- Test with a throwaway Firebase project, or an HTTP stub for the shapes plus one real call.

## Looks like a security or privacy hole in PHP (copied, flagged)

- Feedback is erased for ONE user id (the first user row of the token) while `users` is anonymised for every row of the token.
- Not erased by PHP, so not here: `user_notifications` (the member's inbox), `student_interests`, `class_registrations_languages`, guardian links, `user_roles`, `admin_access_log` (user id, token, IP, user agent of admins), `platform.outbox` event payloads, attendance and quiz rows (kept on purpose, keyed by token). Confirm against the privacy policy.
- Queued-message redaction matches by value (mobile, device id): a recipient stored in another format (spaces, `+`) is missed.
- `contact_name`, `contact_email` and `reason` live up to 2 hours after completion, and are purged only when another completion runs (no scheduler): a quiet system keeps them longer.
- The 409 on a failed completion showed `$e->getMessage()` in PHP (leak); here only our own refusal texts.
- `POST /admin/deletion-requests` 404 echoes the submitted email back (admin only, JSON).
- The rate limit is in memory: two API instances each allow one call a minute, so a double tap can reach Firebase twice (the in-transaction claim still completes once).
- Demo members are recognised only by an address ending `@demo.invalid`; anyone who can set their own email to that (an unverified Firebase email) could not be completed. Check that sign-in refuses unverified claims (it does for claiming a row).
- `debug-token` reveals email, name and uid of the caller's own token only; its safety rests on the environment name (a Production host must not set an environment other than Production).

## Checklist for the test phase

- [ ] Database role rights: the API role must be allowed to delete `notifications.user_devices` and `platform.feedback`, update `platform.outbound_messages`, `membership.member_profiles`, `membership.class_registrations`, and read `membership.v_members` (nothing checked here; see `db/tests` role-rights tests).
- [ ] Hurl: each route's 401 / 403 / 404 / 409 / 422 and success bodies (every key present, null not absent); 202 vs 200 duplicate; 201 vs 200 raise; counts object always has the four keys.
- [ ] A live deletion blocks other routes but `GET/POST/DELETE /me/deletion-request` still work (existing gate) and a cancelled request unblocks.
- [ ] `ON CONFLICT DO NOTHING` really yields one live request under two simultaneous POSTs (db test with concurrency); the event is written once.
- [ ] `SqlQuery` mapping of `DeletionRow` (positional record, citext cast to text, nullable params `{id}::int is null`) works on PostgreSQL 18; `= any({string[]})` in `RedactRecipientsAsync` binds.
- [ ] Complete: every erased column above is null/blank afterwards for a synthetic member with devices, feedback, queued messages (mobile and device recipient), two user rows of one token; kept columns kept; the second `users` row too.
- [ ] Complete rollback: a failure after the claim (inject one) leaves the request live and nothing erased; Firebase failure leaves the database untouched; completed twice within a minute is 409 (rate limit), after a minute 409 (not live).
- [ ] The completed member can no longer sign in with the old Firebase token inside the window (existing gate) and a new sign-up with the same email creates a new member after 2 hours.
- [ ] Demo member and token-0 requests are refused with the right text; `can_complete` false for them.
- [ ] Zip and mobile appear only for held requests; confirmation text only while unstamped; stamp is idempotent and keeps the first time.
- [ ] Events: one outbox row per state change with the listed payloads and no names/emails.
- [ ] `debug-token`: 404 under `ASPNETCORE_ENVIRONMENT=Production` and when unset, even with a valid token; 401 texts; 200 body under Development with the emulator.
- [ ] Startup: API starts without `TSR_GOOGLE_SERVICE_ACCOUNT_B64`; a malformed value stops start-up without printing it; in emulator mode the no-op deleter is used.
- [ ] Firebase client against a real or stubbed Google (see above); the key never appears in logs.
- [ ] Security review: authorisation of all admin routes (a member without `deletion-requests:manage` gets 403 before any lookup, so no id enumeration), SQL boundary, and the PHP holes listed above.
