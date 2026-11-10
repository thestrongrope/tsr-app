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
| `POST /auth/link` (create route; `me` has identity fields only) | built; `api/features/link-account/` |
| Account deletion command, `/me/deletion-request`, claim sync, `/auth/debug-token` | not started; PHP serves them |

## Owns

- Schema `identity`: `users` (id, token, email, provider, firebase_uid, created/last sign-in, IP, device, platform, version; `gender` stays only until membership's profile exists; the role moved to `access.user_roles`) and `account_deletion_requests` (the part sign-in reads).
- Dependencies: none (`IdentityModule.Dependencies`). Other domains read the caller from `HttpContext.GetCaller()` (shared plumbing).

## How a request is judged

An endpoint opts in with `.RequireMember()` (`.RequireMember(createsMember: true)` for PHP's `api_authenticate(true)`). Then, in PHP's order: no/odd header 401 `Not authenticated`; bad token 401 `Invalid auth token`; no email 401 `Email not present in token`; create routes only: deleted within 2 h 403 (+`deletion_status: completed`); no row 404 `User not found` (an unverified email never claims a row); token 0 403 `Registration incomplete`; live deletion off the allow list 403 `Account deletion pending` (+status); then the sign-in is recorded. Endpoints without the marker are never authenticated (health, public reads).

## Configuration (fails closed)

`TSR_FIREBASE_PROJECT_ID` is required everywhere. `TSR_AUTH_EMULATOR_HOST` (unsigned tokens) is accepted only in Development, with a `demo-` project and a host in the allow list; otherwise the API does not start.

## Checks

```
dotnet test domains/identity/api/tests     # token verification, settings, deletion allow list
dotnet test db/tests                       # every refusal and success over HTTP, the sign-in write as the limited role (Docker)
tools/identity-contract.sh dev             # Hurl contract on the dev stack (emulator sign-in)
tools/identity-contract.sh parity          # the same file on PHP (parity stack up, tools/parity-php/README.md)
```
