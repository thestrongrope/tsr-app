# domains/identity/

AuthN: who is calling. Verifies the Firebase ID token, finds or creates the member's `users` row, refuses
sign-ins exactly as PHP's `api_authenticate()` does, and records each sign-in. It decides nothing about
what the member may do (that is `access`). Parity first: PHP's behaviour is copied, quirks included
(facts: `docs/specs/initial-build/phase-2-identity-recon.md`; notes and gaps: `phase-2b-notes.md`).

## Status

Every operation of this domain is built (no `api/Planned.cs`). Routes and shapes: `spec/api.yaml`.

| Part | State |
|---|---|
| Token verification (Google keys, or the Auth emulator in Development) | built; `api/FirebaseVerifier.cs` |
| Member middleware, failure table, per-request sign-in write | built; `api/CallerMiddleware.cs` |
| `POST /auth/link` (create route) | the sign-in is this domain's middleware and its contract is `spec/tests/link-account.hurl`; the route itself is membership's slice `link-account`, because `me` is the member's profile (the sixteen fields of `GET /me`, which the app reads right after sign-in) |
| `/me/deletion-request` (3), the six `/admin/deletion-requests` routes (list, raise, hold, confirmation-sent, complete), `/auth/debug-token` | built; `api/features/` |
| Claim sync | not started |

## Owns

Schema `identity`: `users` (identity columns only; the profile columns, `gender` included, moved to
`membership.member_profiles`, the role to `access.user_roles`) and `account_deletion_requests` (all of PHP's columns;
`source` has a CHECK, and one live request per member is a partial unique index in place of PHP's generated `active_token`).

## Dependencies

`access`, `platform`, `notifications` (`IdentityModule.Dependencies`: permissions, and the erasure commands
`PlatformCommands.EraseFeedbackAsync` / `RedactRecipientsAsync`, `NotificationsErasure.EraseDevicesAsync` and
`EraseEventSettingsAsync`). `membership` is not listed: it references identity, so identity reads its published view
`membership.v_members` (name, mobile, zip) and declares the second port `IMemberErasure`, which membership implements
(`MembershipCommands.EraseMemberAsync`). Other domains read the caller from `HttpContext.GetCaller()` (shared plumbing).

## Public interface

- `UserDirectory` with `UserRef`: `ByTokenAsync` (every user of a token, because a token is not unique, at most 50), `ByIdsAsync` (at most 500 ids, more throws), `ByTokensAsync` (at most 500 tokens, every holder in id order, at most 2000 rows).
- The port `IProfileSink`: name and picture from the token, handed on in the same request when a create route makes a member or a verified email claims one; default no-op, `membership` supplies the real one. The token claims `name` and `picture` are read in both verifier modes, as PHP does.

## Data access and JSON (rules 6 and 7 of `domains/CLAUDE.md`)

- No Entity Framework at run time. Every read and write runs on the `NpgsqlDataSource` or a `DbTx`. `IdentityContext` and the migrations stay for the schema: `IdentityModule.AddIdentityTables` registers the context for the migrate job only, and the API starts with `AddIdentity`, which does not register it.
- One connection at a time. A request never holds two connections of the data source, and no connection is held across a call to the account service (`IFirebaseAccounts`): the completion reads on short transactions, checks and deletes in Firebase with none open, then opens the write transaction. The sign-in judgement uses the same rule (`db/tests/IdentityPoolTests.cs` runs every route and sign-in path on a pool of one).
- `api/domain/IdentityJson.cs` is the one source-generated JSON context: the answers (`IdentityJson.Answers`), the events (`IdentityJson.Default`) and the account-service wire records of `GoogleFirebaseAccounts`. A type behind an `object` value of an answer must be listed there; `IdentityJson.Tests.cs` writes each with reflection off.
- A claim whose write fails is not caught: the host answers 500, nothing of the claim is stored and the profile sink is not called (`IdentityFailureTests`).
- Every read returns a row in some test: `docs/specs/aot-migration/issue-102-reads.md`.

## Account deletion

Order of checks, every refusal and the events: the header and comments of
`api/features/admin-deletion-complete/AdminDeletionComplete.cs`. What an agent must not get wrong:

- Completing a deletion deletes the Firebase account of EVERY `users` row of the token (PHP deletes only one): each row's stored `firebase_uid`, and for a row with none the uid Firebase returns for that row's email (`IFirebaseAccounts.FindUidByEmailAsync`, then delete by uid).
- All of it happens before the transaction and cannot be rolled back. Every lookup and check runs before the first delete. The first failure is 409 with nothing written (accounts already deleted stay deleted, and a retry succeeds because an account Firebase no longer knows counts as done).
- The completion is 409 (nothing deleted or written, no email named) when a no-uid row's email (citext, case-blind) is also held by a `users` row of another token, or the uid returned for it is the `firebase_uid` of another token's row. A token with more than 20 rows is 409 before any Firebase call.
- Feedback of every row is erased; the queued messages of every row's mobile (distinct) are redacted.
- Firebase deletion goes through `IFirebaseAccounts` (real client with `TSR_GOOGLE_SERVICE_ACCOUNT_B64`; none without it, every completion then refused 409; emulator mode no-op).
- Events: completing writes `identity.member_erased` and `identity.deletion_completed`; the other state changes write `identity.deletion_requested`, `_cancelled`, `_held`.

## How a request is judged

An endpoint opts in with `.RequireMember()` (`.RequireMember(createsMember: true)` for PHP's `api_authenticate(true)`). A `precheck:` given to the marker runs before the sign-in and may only refuse (the report downloads use it for PHP's `format must be xlsx or pdf` 422, which PHP answers unsigned). Then, in PHP's order (the texts are in `api/CallerMiddleware.cs`): header 401; token 401; no email 401; create routes only: deleted within 2 h 403 (+`deletion_status: completed`); no row 404 (an unverified email never claims a row); token 0 403; live deletion off the allow list 403 (+status); then the sign-in is recorded. Endpoints without the marker are never authenticated (health, public reads).

## Configuration (fails closed)

`TSR_FIREBASE_PROJECT_ID` is required everywhere. `TSR_AUTH_EMULATOR_HOST` (unsigned tokens) is accepted only in Development, with a `demo-` project and a host in the allow list; otherwise the API does not start.

## Published commands (`api/IdentityCommands.cs`; each takes the caller's `DbTx` and runs on its transaction)

- `ChangeEmailAsync(tx, token, email, clock, ct)`: only a placeholder (blank or `<token>@thestrongrope.com`) with no Firebase link may be given another address; an address another member already has is refused (PHP has no such check; `EmailTakenAsync` lets the caller ask first for its own message; no unique index backs it). Returns false and writes nothing otherwise. Validates its inputs (throws). Event `identity.member_email_changed` (token). Used by `classes` (edit a student); proved by `db/tests/StudentEditTests.cs`.
- `CreateMemberAsync(tx, clock, ct)` returns the token of a new `users` row for a member who is not an app member yet (bulk add): address `<token>@thestrongrope.com`, no Firebase link, no role. The token comes from `domain/TokenAllocation.cs`, the one allocator (sign-in uses it too): highest + 1 under advisory lock 7100001, waiting at most 10 seconds, inside the caller's transaction. Event `identity.member_created` (token). Used by `classes` (bulk add); proved by `db/tests/BulkAddTests.cs`.

## Where things are

| Need | File |
|---|---|
| The HTTP contract | `spec/api.yaml`; Hurl `spec/tests/deletion-*.hurl`, `admin-deletion-*.hurl`, `debug-token.hurl`, `link-account.hurl` |
| The refusals in order; the marker | `api/CallerMiddleware.cs`; `shared/api/MemberRoute.cs` |
| What a member with a live deletion may still reach | `api/domain/DeletionGate.cs` |
| The sign-in's reads and writes; the deletion reads | `api/domain/MemberDirectory.cs`; `api/domain/DeletionRequests.cs` |
| Answers, events and account-service wire, without reflection | `api/domain/IdentityJson.cs` |
| Background notes | `docs/specs/initial-build/test-deletion-notes.md`, `lane-identity-notes.md` |

## Checks

```
dotnet test domains/identity/api/tests     # token verification, settings, deletion allow list
dotnet test db/tests                       # every refusal and success over HTTP, the sign-in write as the limited role (Docker); TestDeletion*Tests.cs, TestDebugTokenTests.cs; IdentityFailureTests, IdentityPoolTests
tools/identity-contract.sh test            # Hurl contract on the test stack (emulator sign-in; never dev: it may hold real data)
tools/identity-contract.sh parity          # the same file on PHP (parity stack up, tools/parity-php/README.md)
tools/contract-deletion.sh test|parity     # the deletion and debug-token Hurl files
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_users` | id, token, email, created_on, has_firebase_link | membership (`v_members`); email filters and token to id in classes reports, platform (access log: email) |
