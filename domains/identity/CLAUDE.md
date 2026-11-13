# domains/identity/

AuthN: who is calling. Verifies the Firebase ID token, finds or creates the member's `users` row, refuses
sign-ins exactly as PHP's `api_authenticate()` does, and records each sign-in. It decides nothing about
what the member may do (that is `access`). Parity first: PHP's behaviour is copied, quirks included
(facts: `docs/specs/initial-build/phase-2-identity-recon.md`; notes and gaps: `phase-2b-notes.md`).

## Status

| Part | State |
|---|---|
| Token verification (Google keys, or the Auth emulator in Development) | built; `api/FirebaseVerifier.cs` |
| Member middleware, failure table, per-request sign-in write | built; `api/CallerMiddleware.cs` |
| `POST /auth/link` (create route) | the sign-in is this domain's middleware and its contract is `spec/tests/link-account.hurl`; the route itself is membership's slice `link-account`, because `me` is the member's profile (the sixteen fields of `GET /me`, which the app reads right after sign-in) |
| `/me/deletion-request` (3), the six `/admin/deletion-requests` routes (list, raise, hold, confirmation-sent, complete), `/auth/debug-token` | built; proved in the test phase (Hurl on PHP and the new API: `spec/tests/deletion-*.hurl`, `admin-deletion-*.hurl`, `debug-token.hurl`, run by `tools/contract-deletion.sh`; `db/tests/TestDeletion*Tests.cs`, `TestDebugTokenTests.cs`); notes `docs/specs/initial-build/test-deletion-notes.md`, `lane-identity-notes.md` |
| Claim sync | not started |

## Owns

- Schema `identity`: `users` (id, token, email, provider, firebase_uid, created/last sign-in, IP, device, platform, version; the profile columns, `gender` included, moved to `membership.member_profiles`, the role to `access.user_roles`) and `account_deletion_requests` (all of PHP's columns since the schema phase; `source` has a CHECK, and one live request per member is a partial unique index in place of PHP's generated `active_token`).
- Dependencies: `access`, `platform`, `notifications` (`IdentityModule.Dependencies`: permissions, and the erasure commands `PlatformCommands.EraseFeedbackAsync` / `RedactRecipientsAsync`, `NotificationsErasure.EraseDevicesAsync` and `EraseEventSettingsAsync`). `membership` is not listed: it references identity, so identity reads its published view `membership.v_members` (name, mobile, zip) and declares the second port `IMemberErasure`, which membership implements (`MembershipCommands.EraseMemberAsync`). Completing a deletion writes `identity.member_erased` and `identity.deletion_completed`; the other state changes write `identity.deletion_requested`, `_cancelled`, `_held`. Completing a deletion deletes the Firebase account of EVERY `users` row of the token (decided 12 Nov 2026; PHP deletes only one): each row's stored `firebase_uid`, and for a row with none the uid Firebase returns for that row's email (`IFirebaseAccounts.FindUidByEmailAsync`, then delete by uid); all before the transaction; every lookup and check runs before the first delete, and the completion is 409 (nothing deleted or written, no email named) when a no-uid row's email (citext, case-blind) is also held by a `users` row of another token, or the uid returned for it is the `firebase_uid` of another token's row; the first failure is 409 with nothing written (accounts already deleted stay deleted, and a retry succeeds because an account Firebase no longer knows counts as done); a token with more than 20 rows is 409 before any Firebase call; feedback of every row is erased; the queued messages of every row's mobile (distinct) are redacted. Firebase deletion goes through `IFirebaseAccounts` (real client with `TSR_GOOGLE_SERVICE_ACCOUNT_B64`; none without it, every completion then refused 409; emulator mode no-op). Other domains read the caller from `HttpContext.GetCaller()` (shared plumbing).
- Public: `UserDirectory` (`ByTokenAsync`: every user of a token, because a token is not unique, at most 50; `ByIdsAsync`: at most 500 ids, more throws; `ByTokensAsync`: at most 500 tokens, every holder in id order, at most 2000 rows) with `UserRef`, and the port `IProfileSink` (name and picture from the token, handed on in the same request when a create route makes a member or a verified email claims one; default no-op, `membership` supplies the real one). The token claims `name` and `picture` are read in both verifier modes, as PHP does.

## How a request is judged

An endpoint opts in with `.RequireMember()` (`.RequireMember(createsMember: true)` for PHP's `api_authenticate(true)`). A `precheck:` given to the marker runs before the sign-in and may only refuse (the report downloads use it for PHP's `format must be xlsx or pdf` 422, which PHP answers unsigned); without one nothing changes. Then, in PHP's order: no/odd header 401 `Not authenticated`; bad token 401 `Invalid auth token`; no email 401 `Email not present in token`; create routes only: deleted within 2 h 403 (+`deletion_status: completed`); no row 404 `User not found` (an unverified email never claims a row); token 0 403 `Registration incomplete`; live deletion off the allow list 403 `Account deletion pending` (+status); then the sign-in is recorded. Endpoints without the marker are never authenticated (health, public reads).

## Configuration (fails closed)

`TSR_FIREBASE_PROJECT_ID` is required everywhere. `TSR_AUTH_EMULATOR_HOST` (unsigned tokens) is accepted only in Development, with a `demo-` project and a host in the allow list; otherwise the API does not start.

## Checks

```
dotnet test domains/identity/api/tests     # token verification, settings, deletion allow list
dotnet test db/tests                       # every refusal and success over HTTP, the sign-in write as the limited role (Docker)
tools/identity-contract.sh dev             # Hurl contract on the dev stack (emulator sign-in)
tools/identity-contract.sh parity          # the same file on PHP (parity stack up, tools/parity-php/README.md)
```

## Published commands

`IdentityCommands.ChangeEmailAsync(db, token, email, clock, ct)` (`api/IdentityCommands.cs`): PHP `canChangeEmail` and the email write of `updateStudentInClass`. Only a placeholder (blank or `<token>@thestrongrope.com`) with no Firebase link may be given another address; an address the member already has is left alone; an address another member already has is refused (decided 11 Nov 2026; PHP has no such check; `EmailTakenAsync` lets the caller ask first for its own message; no unique index backs it). Returns false and writes nothing otherwise. Validates its inputs (throws), runs on the caller's transaction, writes the event `identity.member_email_changed` (token) when it changes the address. Used by `classes` (edit a student); proved by `db/tests/StudentEditTests.cs`.

`IdentityCommands.CreateMemberAsync(db, clock, ct)` returns the token (`api/IdentityCommands.cs`): PHP `createClassStudent`'s `users` insert for a member who is not an app member yet (bulk add). The token is allocated by `domain/TokenAllocation.cs`, the one allocator (sign-in uses it too): highest + 1 under advisory lock 7100001, waiting at most 10 seconds, inside the caller's transaction. The row has the address `<token>@thestrongrope.com`, no Firebase link and no role. Throws without a transaction. Writes the event `identity.member_created` (token). Used by `classes` (bulk add); proved by `db/tests/BulkAddTests.cs`.

## Placeholders

Every operation of this domain is built, so there is no `api/Planned.cs` any more.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_users` | id, token, email, created_on, has_firebase_link | membership (`v_members`); email filters and token to id in classes reports, platform (access log: email) |
