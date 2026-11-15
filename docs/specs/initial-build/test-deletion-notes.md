# Test phase, lane "deletion" (identity: account deletion and debug-token): notes (12 Nov 2026)

Stack 4 (gateway :8104), id block: tokens 924000 to 924999, other rows 9740000 to 9749999. Branch `worktree-agent-a731aeace656996c2`. Brief: `test-phase-brief.md`; lane notes: `lane-identity-notes.md`.

## What was run

| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `domains/identity/api/tests` | 87 passed (new: the Firebase client against a stub handler, one gate row) |
| `hosts/api/tests` | 74 passed |
| `db/tests` | 490 of 491 pass; 71 are this lane's (`TestDeletionTests` 29, `TestDeletionRoutesTests` 32, `TestDebugTokenTests` 10). The one failure, `AccessTests.CanAsync_for_an_unknown_action_throws_because_it_is_a_bug_in_the_caller`, is not this lane's and fails alone too: it calls `Assert.ThrowsAsync` without awaiting it (`_ =`), so the scope is disposed while the connection is still opening ("Can't close, connection is in state Connecting"). Not touched. |
| `tools/contract-deletion.sh test` (TSR_STACK=4) | 9 files, 99 requests, all pass (also run twice in a row: the fixtures reload and the request ids change every 2 seconds) |
| `tools/contract-deletion.sh parity` (PHP) | 9 files, 97 requests, all pass (`-new-api` files excluded, `-php-only` included) |

## Per route

All nine are proven, by Hurl on both sides where PHP can run the case and by database tests as the limited role `tsr_app`.

| # | Route | Hurl (file) | Database tests | Not provable here |
|---|---|---|---|---|
| 1 | POST /auth/debug-token | `debug-token.hurl` (401 texts, success body) on both | Production host answers 404 before looking at the token (built with `UseEnvironment("Production")`), success body, nulls, no database read or write, wrong project 401 | the "environment not set" case (WebApplicationFactory defaults to Development); it is the same `IsProduction()` check |
| 2 | POST /me/deletion-request | `deletion-request.hurl` (202, 200 duplicate, 422s, trimming) | one row and one event under 8 simultaneous requests, reason limits (500 ok, 501, NUL, non-text, blank), contact copied, no PII in the event | |
| 3 | GET /me/deletion-request | same | none shape, held note or prize sentence | |
| 4 | DELETE /me/deletion-request | same (200, 404, 409 after completion) | one event, 6 simultaneous cancels cancel once | |
| 5 | GET /admin/deletion-requests | `admin-deletion-list.hurl` (19 keys, 4 counts, filter, demo, held zip and mobile, confirmation text) | order, zip and mobile hidden from a caller without the permission | |
| 6 | POST /admin/deletion-requests | `admin-deletion-raise.hurl` (201, 200, 404, 422, NUL byte, guest user) | one event with source web, nothing written on a refusal | |
| 7 | .../hold | `admin-deletion-hold.hurl` | one event on the first hold only, nothing changes on a refusal | |
| 8 | .../confirmation-sent | `admin-deletion-confirmation-sent.hurl` | stamp kept, no event | |
| 9 | .../complete | `admin-deletion-complete.hurl` (every refusal, the rate limit, a request naming no member completes), `-php-only.hurl` (409 "Firebase service account not configured", request still live), `-new-api.hurl` (a member's completion over HTTP, emulator mode) | see below | the real Google calls |

### Route 9, what the database tests prove (as `tsr_app`, Firebase faked)

- Every column PHP erases is erased and every kept column kept (`users`: email `deleted-<token>@deleted.invalid`, uid, lastdevice, device, platform, version, lastloginip null; profile: name `Deleted member`, mobile `''`, language 0, sendupdates `N`, unsubscribe `Y`, the rest null; class registrations: the 19 columns null, class, status and dates kept). A test lists the columns of `identity.users`, `member_profiles` and `class_registrations` and fails when a new one is neither erased nor on the kept list.
- Devices and feedback deleted, queued messages kept with recipient `[deleted]` (mobile and both device ids).
- A second member (same device id, own feedback, own registrations, own queued messages, two user rows) has every row unchanged; their device row survives although it has the same device id.
- One transaction: an injected failure in the membership port, after the devices were deleted and the queue redacted, leaves the whole database (and the outbox) as before. It answers 500; PHP answers 409 with the exception text (decision 4 below).
- Firebase order: the fake looks at the database from inside `DeleteAsync` and sees the request still `pending`, the devices present, the email unchanged. **The task text said PHP calls Firebase after the commit. It does not:** `AccountDeletionModel::complete()` calls the deleter before `beginTransaction` ("a failure leaves the database clean"), and the port does the same. A Firebase failure is 409 with its message and changes nothing (whole-database snapshot equal); not configured is 409 with the port's message.
- A cancellation that lands while Firebase is being called wins (the guarded update claims 0 rows, nothing else is written, no events).
- Events: exactly `identity.member_erased` {token, userId} and `identity.deletion_completed` {requestId, token, handledBy}, no names, emails or numbers; none on any refusal; a request naming no member writes only the second and calls no Firebase.
- Refusals, each with PHP's status and text, database and outbox untouched, Firebase never called: 404 (0, negative, text, 20 digits, `1e3`, unknown), 409 token 0 and negative token, no confirmation, completed, cancelled, demo member, no user row. Rate limit: 6 simultaneous completions reach Firebase once. 403 before any lookup (same answer for a real id and an unknown one, so no id enumeration) for a plain member and a coordinator; a stranger who signs in on this create route becomes a member without the permission (403); an administrator with a live request of their own is refused by the gate.
- Purge: a completion older than 2 hours loses name, address and reason when another completion runs; a recent one keeps them.
- Rights (finding 7): as `tsr_app` the four cross-schema writes (delete devices, delete feedback, update queued messages, update profiles, update class registrations, update users) and the reads of `v_members` and `v_users` succeed. The grants are schema wide (`DomainContexts`), nothing to fix.

## Guards proved by removal (removed, test failed, restored, rebuilt)

| Guard | Failed |
|---|---|
| completion claim `where ... status in (live)` | `A_cancellation_that_lands_while_Firebase_is_being_called_wins...` |
| `users` update `where token = {token}` (widened) | the bystander test and the rate-limit test |
| completion's "no confirmation recorded" check | the refusals test and the rate-limit test |
| permission check in `DeletionRequests.RefuseAsync` (all routes) | 6 tests (403 on hold, confirmation, raise, list, complete, coordinator) |
| `DELETE /me/deletion-request` in the gate allow list | 3 tests (read and cancel while pending) |
| `IsProduction()` in debug-token | the Production test |

Not removed (covered by tests that would show it, not proved by removal): the `on conflict do nothing` unique-live-request rule (8 simultaneous requests test), the Firebase-before-transaction order, the purge.

## Bugs found and fixed

1. `POST /auth/debug-token` answered `provider` from the token's `firebase.sign_in_provider` claim; PHP always answers `null` (its verifier hands on no `firebase` claim). Test first (`Outside_Production_it_echoes_..._a_null_provider_as_PHP_does` failed with a string, then passed); `DebugToken.cs` now answers `null`. Decision 6 below.

No other difference from PHP was found: the nine routes answered every case of the nine Hurl files like PHP.

## Findings from `build-out-findings.md`

- **Security 1 (completion deletes the Firebase account of ONE row, then anonymises every row of the token): PHP does the same** (`member()` is `select * from users where token = :token limit 1`; `applyMap` updates `where token`). Copied and pinned by `A_token_held_by_two_user_rows_..._FINDING_1` (the second row's uid is never passed to Firebase). The port also takes the lowest id row where PHP takes an arbitrary one. **Decision for the owner:** delete every distinct `firebase_uid` of the token (stop on the first failure, before the database), or refuse with a message when a token has more than one linked row. The pinned test then changes.
- **Security 2 (no stored uid: the account is found by email and deleted): PHP does the same** (`getUserByEmail`). Pinned by `A_row_with_no_stored_uid_is_passed_to_Firebase_by_email_alone_..._FINDING_2` (uid null, email given). Only 5,856 of 26,046 PHP rows carry a uid, so refusing would block most completions. **Decision for the owner:** require the operator to confirm the address Firebase found (a dry-run lookup shown first), or delete by uid only and send the rest to a manual step. One difference where the port is SAFER than PHP and was kept: PHP treats ANY failure of the lookup as "no account" and goes on to anonymise (the account may then survive and still sign in); the port refuses unless Google says "not found". Decision for the owner: keep it.
- **Security 7 (role grants): proved**, see Rights above. Nothing to fix.
- **Design 1 (`IMemberErasure` port):** works, one transaction, proved. **Design 2 (erasure through published commands in one transaction plus `identity.member_erased`):** proved by the rollback and event tests. `domains/CLAUDE.md` rule 11 still says erasure is event-only and "not built or tested yet": the owner should rewrite it (a shared file, not edited here). The event has no consumer.

## Decisions needed (one line each)

1. Findings 1 and 2 above (more than one Firebase account per token; delete by email).
2. Queued messages are redacted by value, so a device id or mobile that two members share loses both members' queued rows (PHP does the same; pinned by `A_queued_push_message_of_another_member_..._DECISION`). Proposal: key the queue by member.
3. **Gateway:** a POST with no body and no `Content-Length` (curl, Hurl) gets a 400 with an empty body from the new stack (nginx forwards it without a length, Kestrel refuses it) where PHP answers normally. The Flutter client sends `Content-Length: 0`, so no app is hit; the Hurl files send `Content-Length: 0` explicitly. Proposal: let the gateway add the header (`proxy_set_header Content-Length ...`) or accept it as is. Affects every lane's POST routes.
4. A bug or database failure in completion is a 500 with no text; PHP answers 409 carrying `$e->getMessage()` (a leak). Kept (already decided in the lane notes).
5. PHP's queue lists a request once per `users` row of its token (a left join on token); the port lists it once. Not tested against PHP (PHP's fixtures have one row per token); kept.
6. `debug-token`: `provider` is now always null, PHP's. The useful provider could be returned instead (proposal). Also in Development with the emulator the port echoes the token's own `email` claim; PHP takes the email from the emulator account (a hand-made token cannot name another address). Development only, the caller's own claims only; proposal: route it through the verifier as PHP does.
7. The deletion pages in PHP's route comments say the queue also purges contact details when an administrator opens it; the route does not call `purgeExpiredContactDetails` (only a completion does), and neither does the port. A quiet system keeps name and address longer than 2 hours.

## Unverified against the real service

Everything behind `GoogleFirebaseAccounts`: the unit tests (`GoogleFirebaseAccounts.Tests.cs`, a stub `HttpMessageHandler`, a key generated in the test) prove the request URLs, the form fields, the signed assertion (RS256 verified with the public key), the bodies, the bearer header, the "not found" handling, the token cache, that failures carry no key, token, or address, and the project mismatch. They do not prove that Google accepts the `identitytoolkit` scope (or needs `cloud-platform`), the lookup and delete shapes, or the "not found" texts. One call against a throwaway Firebase project is still needed. The Production start-up without `TSR_GOOGLE_SERVICE_ACCOUNT_B64` is covered by `UnconfiguredFirebaseAccounts` (every completion 409); a malformed setting stopping start-up is covered by the existing unit tests, not re-run.

## Process slips

- I ran `python3 --version` once (a bare python3, against the brief) before switching to `uv run python -I`; nothing else used it.
- The commits end `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (the attribution this session was given); the brief names `Claude Fable 5.2`.
- Hurl's `$.*` count on a one-key object and a single-match filter behave differently from a list (a one-element result is not a list); the files were adjusted, the cases are unchanged.
- No bug was found in the nine routes beyond decision 6; the tests passed on their first run apart from seed and assertion mistakes of my own, so most of the value is the proof and the guards, not fixes.
