# Phase 2b notes: identity to parity (2026-11-10)

## Step zero: JWT bearer under NativeAOT
- The brief's premise is off: `hosts/api` is **not** NativeAOT. No project sets `PublishAot` or `IsAotCompatible`, and `hosts/api/Dockerfile`
  is a plain JIT publish (`docs/specs/dotnet-stack.md`: JIT, written AOT-ready). Nothing to break; I proved the library anyway.
- Probe (scratch project, `Microsoft.AspNetCore.Authentication.JwtBearer` 10.0.14, `CreateSlimBuilder`, the same option set as shipped incl. the
  unsigned-token `SignatureValidator`), published NativeAOT in `mcr.microsoft.com/dotnet/sdk:10.0` (linux-arm64, clang + zlib1g-dev): zero warnings
  (`TreatWarningsAsErrors` on), 17 MB binary; it ran, accepted a live emulator token (`yes <email>`), refused garbage with the IdentityModel
  base64 error, and returned none without a header. Positive and negative validation both work under AOT.
- Mac-native `dotnet publish -p:PublishAot=true` fails at the linker with this Command Line Tools install (tbd "unknown architecture"): environment, not code.
- Seen once on the Mac restore: NU1903 on `Microsoft.DotNet.ILCompiler` 10.0.12 (known high advisory). Not seen in the Linux image. No suppression added to the repo.
- Whole-host AOT result: see "Host AOT" below.

## What was built
Verifier (`FirebaseVerifier`, `FirebaseSettings`), member middleware (`CallerMiddleware`, `MemberDirectory`, `DeletionGate`, `LoginTracking`),
`POST /auth/link`, migration `IdentityUsersAndDeletion`, dev Auth emulator, `X-Dev-Token` removed, mint scripts, Hurl contract.
Shared: `MemberRoute` marker (`.RequireMember()`), `Problem.Detail(status, detail, deletionStatus)`. Platform: `POST /feedback` marked `.RequireMember()` (one line).

## Decisions and assumptions (correct me)
1. **Opt-in marker**, not a default: only endpoints marked `.RequireMember()` are authenticated; `/health` and `/articles` are untouched. An unmarked member route
   would reach its handler with no caller, and handlers already answer 401 then (domains rule 4). Opt-out (everything private unless `AllowAnonymous`) is safer; it touches platform and content too.
2. **Deletion shape:** a separate `identity.account_deletion_requests` (token, status, contact_email, requested_at, completed_at), the smallest shape that gives both 403s: completion clears `users.email`, so the "deleted a moment ago" check must match `contact_email`.
3. `gender` **stays** on `identity.users` until membership's profile exists. `roleid` is gone: the role is `access.user_roles` (see phase-2a-notes).
4. citext everywhere, no case-sensitive column: PHP's table is `utf8mb4_unicode_520_ci`, so email and `firebase_uid` already match case-insensitively there. This resolves recon unknown 1 (email: case-insensitive). Unique index on `firebase_uid` as in PHP.
5. Emulator gate = PHP's four conditions: host set, environment Development (PHP: `APP_ENV=local`), project starts `demo-`, host in the allow list; else start-up fails (PHP rejects every token; failing at start is stricter). Config keys `TSR_FIREBASE_PROJECT_ID`, `TSR_AUTH_EMULATOR_HOST`. EF design-time command needs `--TSR_FIREBASE_PROJECT_ID=demo-design` (root CLAUDE.md updated).
6. `ClockSkew` zero (php-jwt sets no leeway). Key fetch timeout 5 s, emulator lookup 2 s.
7. `getRealIpAddr` copied: `Client-IP` then `X-Forwarded-For`, trusted as sent, so a caller can spoof the stored IP (security note for later, kept for parity).
8. Deferred: name/picture overwrite on link (profile), claim sync to Firebase, `/auth/debug-token`, account deletion command, token-race retry beyond the lock.
9. Flutter `hosts/app/lib/main.dart` still sends `X-Dev-Token`; outside the brief, so it no longer signs in against the new API. Needs Firebase sign-in wiring.
10. TDD: tests were written first and failed to compile (types missing); the first run of the DB tests failed on a harness fault (citext read) and seven then passed after the fix. All behaviour tests failed or did not compile before the implementation existed.
11. The Content-Length: 0 header on `/auth/link` Hurl requests: see php-parity-feedback.md, difference 3.

## Commands
Sign in (dev): `tools/dev-auth/mint-token.sh [email]` writes `build/dev/token.vars` (auth_header, auth_value, emulator vars). PHP: `tools/parity-php/mint-token.sh <email>` writes `build/parity-php/token.vars`.
Identity contract: `tools/identity-contract.sh dev` and `tools/identity-contract.sh parity` (refresh fixtures, mint, run Hurl).
Any file on dev: `hurl --test --variable base_url=http://localhost:8088 --variables-file build/dev/token.vars --variables-file domains/identity/spec/tests/fixtures.vars <file>`;
on PHP: `--variable base_url=http://127.0.0.1:18091 --variables-file build/parity-php/token.vars` (add fixtures.vars for the identity file).

## Host AOT (measured, not a requirement)
`hosts/api` published with `-p:PublishAot=true -p:TreatWarningsAsErrors=false` in the Linux sdk container: it links (exit 0) with 37 IL2xxx/IL3xxx
warnings, **none from JwtBearer or IdentityModel** (0 matches). All are existing EF Core model building, `Outbox`/`Problem` JSON serialisation
and `DomainContexts` plumbing, plus one in the emulator lookup, which I removed (it now builds its two-field body without reflection). The host is JIT today, so these are the AOT-readiness backlog, not new debt.
