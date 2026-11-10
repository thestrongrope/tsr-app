# Phase 2 identity recon: how the PHP mobile API authenticates

Read-only facts from `tsr-account` branch `develop` (`git show develop:<path>`). Paths below are relative to `tsr-account`. No secrets, env values or personal data were read or printed; env vars are named only.

## 1. Request flow (what the caller must send and what the server does)

| Step | What happens | Where |
|---|---|---|
| a | Token is read from `Authorization: Bearer <token>`. Checks `HTTP_AUTHORIZATION`, `REDIRECT_HTTP_AUTHORIZATION`, then `apache_request_headers()`. Regex is case-insensitive | `web/api/mobile/lib/auth.php:74-95` (regex :91) |
| b | Token verified by `verify_firebase_id_token($token, getenv('FIREBASE_PROJECT_ID'))`. Library is `firebase/php-jwt`; keys are Google's JWKS, cached on disk for 1 h, refetched once on unknown `kid` | `web/firebase-id-token-verifier.php:33-36, :86, :179-191, :262-289`; `auth.php:115` |
| c | Checks: `iss` = `https://securetoken.google.com/<project id>`; `aud` = project id; `sub` non-empty. `exp`/`nbf` enforced by the library | verifier `:120-122, :131-151` |
| d | Email must be non-empty in the token | `auth.php:126-128` |
| e | Claims read: `sub` (returned as `firebase_uid`), `email`, `name`, `picture`, `email_verified` (strict `=== true` where used, `subscribers.php:76-79`). `user_token`/`role_id` are read only for claim sync | verifier `:164-172`; `auth.php:132-138` |
| f | Emulator mode: unsigned tokens accepted only when all gate conditions pass (section 8) | verifier `:54-73, :153-162` |

## 2. Finding the user row

- Order: `users.firebase_uid = sub` first, then `users.email = email` (`subscribers.php:87-97` for create, `:150-163` for lookup).
- Email comparison is exact SQL `=` with no PHP lowercasing. Case behaviour depends on the DB collation, not read (unknown 1). Deletion lookups use `lower(contact_email) = lower(:email)` (`models/accountdeletion.php:~396`), so case handling differs between the two.
- **Create path** (`api_authenticate(true)`, used by `/auth/link`, many routes; list in `auth.php` callers): no row by uid or email, and a new `users` row is inserted with `provider='firebase'` and a generated `token` (`subscribers.php:120-135`).
- **Lookup-only path** (`api_authenticate()`, e.g. `feedback.php:12`, and most routes): never creates (`subscribers.php:165-166, :182`).
- **Link by email**: a match is claimed only if `email_verified === true`; the uid is then stamped and `name`/`picture` overwritten on the create path (`subscribers.php:99-116`; lookup path stamps uid only when empty, `:171-178`).
- Per-request writes (after the gate, `auth.php:177`): `UPDATE users SET lastlogin = NOW(), lastloginip, lastdevice (User-Agent), device (X-Device-Info), platform (X-Platform-Info), version (X-App-Version) WHERE email = :email`. Null/empty values skipped; errors swallowed (`auth.php:270-300`). IP comes from `getRealIpAddr()`, which trusts `HTTP_CLIENT_IP` and `X-Forwarded-For` unconditionally (`web/functions.php:321-333`).
- Claim sync (`auth.php:178`, `:324-351`): writes Firebase custom claims only when emulator is off and claims differ. Uses Admin SDK (`firebase-admin-config.php`).

## 3. Failures (status, `detail`, source)

| Condition | Status | `detail` | Source |
|---|---|---|---|
| No header, or not `Bearer <x>` | 401 | `Not authenticated` | `auth.php:109-111` |
| Bad signature, expired, not-yet-valid, wrong iss/aud/sub, JWKS unavailable, or emulator gate refused | 401 | `Invalid auth token` | `auth.php:116-124`; verifier `:104-112, :120-151` |
| Token valid but no `email` claim | 401 | `Email not present in token` | `auth.php:126-128` |
| Lookup-only route: no row, or email matches but unverified | 404 | `User not found` | `auth.php:148-150`; `subscribers.php:108, :126` |
| Create route (`/auth/link`): unverified email matches an existing row | 404 | `User not found` (plus log `auth.unverified_email_refused`) | `subscribers.php:99-104` returns null; `auth.php:148-150` |
| Row has `token` 0 or missing (unfinished registration) | 403 | `Registration incomplete` | `auth.php:158-160` |
| Completed deletion, same email (case-insensitive), within 7200 s; create routes only | 403 | `This account has been deleted. Please sign out and sign in again to start afresh.` + `deletion_status: "completed"` | `auth.php:202-223`; `accountdeletion.php:373, :389-400` |
| Live deletion (`pending`, `awaiting_prize_delivery`) and route not on allowlist | 403 | `Account deletion pending` + `deletion_status: <status>` | `auth.php:41-48, :235-257`; `accountdeletion.php:20` |
| Unknown path / wrong verb | 404 / 405 | `Not Found` / `Method Not Allowed` | `index.php:171` |
| Blocked or suspended account | no code path found | n/a | `auth.php` (comment :29 says sign-in is never blocked) |

Note: 401 covers expiry, revocation and skew together (`auth.php:117-123`). No `Token expired` text exists.

## 4. Guests

- No unauthenticated caller reaches a protected route; `api_authenticate` requires a token (`auth.php:108-111`).
- Token 0 is the shared guest sentinel (`admin_deletion_requests.php:176-179`, `member_enrol.php:50`, `children.php:155`). Any row with token 0 is refused with 403 (`auth.php:158`).
- Conflict: `routes/geo.php:9-11, :32` says guests may call `/geo/*` ("a guest finishing sign-up included"), but `geo.php:30` uses `api_authenticate(true)`, which rejects token 0. Unresolved (unknown 5).
- Public routes with no auth: `/health`, `/app-version`, `/release-notes` (`index.php:22-28`), `/join/{code}` (`index.php:75`), and `/auth/debug-token`, which is 404 unless `APP_ENV` is non-production (`routes/auth.php:46-49`, `:56` verifies the token itself).

## 5. What the caller object contains

- `api_authenticate()` returns the full `users` row (`SELECT *`, `subscribers.php:88-92`, `:150-152`), with `firebase_uid` and `provider` set.
- The same row is put in `$_SESSION['user']` (`auth.php:172, :361-364`), read by model code via `token` (47 uses), `roleid` (20), `id` (6) (`auth.php:355-357`).
- Fields the task named: `id`, `token`, `roleid`, `email`, `firebase_uid`, `name`, `picture`, `lastlogin` etc. Gender is a varchar (`response.php:14-15`). City and level: not verified in the row (unknown 3).
- Authorisation uses the DB role only, never claims (`docs/dev/identity.md:56-62`; `models/permissions.php:344-398`).

## 6. Other gates before the route

| Gate | Finding | Source |
|---|---|---|
| Minimum app build | none enforced server-side; `/app-version` only reports `minimumBuild` (default 1). Fails open | `routes/app_version.php:28-34, :43-50`; `docs/dev/mobile.md:137` |
| Rate limiting | per-route only (`rate_limit_allows`, file-backed). Not in `api_authenticate`. Examples: join preview 30/60 s, geo 60/60 s, parent invite 60/h | `web/functions.php:1160-1200`; `routes/classes.php:103`; `routes/geo.php:32`; `routes/children.php:293` |
| Client IP for limits | `client_ip()` honours `X-Forwarded-For` only from trusted proxies; `getRealIpAddr()` (used for login IP and access log) does not | `functions.php:1130-1150` vs `:321-333` |
| CORS | allowlist from `MOBILE_API_CORS_ORIGINS`; `OPTIONS` returns 204; native apps send no Origin | `bootstrap.php:39-56`; `docker-compose.yml:86` |
| Maintenance mode | none found in `web/api/mobile` | grep |
| Stateless | `TSR_STATELESS_API` set; no session file; `$_SESSION` is request-scoped | `bootstrap.php:14-34` |
| Request logging | `api.slow` logs route pattern, method, ms, status, bytes, build; no token/ip/path. `log_event()` lines carry `member` token and path. Refusals log `firebase_uid` | `lib/slow_log.php`; `docs/dev/infra.md:160`; `functions.php:876-887`; `subscribers.php:68-74` |
| Response envelope | errors are `{"detail": ...}` | `lib/response.php:167-173` |

## 7. Hosts and headers the mobile app sends (names only)

| Item | Value / source |
|---|---|
| Base URL | `TSR_API_BASE_URL` dart-define; default `mobile-api.` host on `thestrongrope.com` (`mobile/lib/core/constants/app_constants.dart:17-29`) |
| Local TLS relaxation | `127.0.0.1`, `localhost` accepted in non-release (`api_client.dart:164-171`) |
| Other account hosts | `account.` host on `thestrongrope.com`: Grand Quiz `api/quiz_info.php` with Bearer (`app_constants.dart:506`; `grand_quiz_repository.dart:26, :66`); join links (`join_link_screen.dart:59`); parent invite (`parent_invite_link.dart:19-20`) |
| `Authorization` | `Bearer <Firebase ID token>` (`api_client.dart:186`) |
| `X-App-Version` | `<version>+<build>` (`api_client.dart:192-195`) |
| `X-Device-Info` | device model, per platform (`api_client.dart:198-224`) |
| `X-Platform-Info` | OS string, per platform (`api_client.dart:200-225`) |
| `Content-Type` | `application/json` (`api_client.dart:155`) |
| Token refresh | on 401, `getIdToken(true)` and replay once (`api_client.dart:38-56, :233-262`) |

## 8. Auth emulator

- `tools/auth-emulator/firebase.json`: auth on port 9099, `singleProjectMode: true`, UI disabled.
- PHP switch, all four required (`firebase-id-token-verifier.php:54-73`): `FIREBASE_AUTH_EMULATOR_HOST` set; `APP_ENV` exactly `local`; `FIREBASE_PROJECT_ID` starts with `demo-`; host in the allowlist (`:39`: `firebase-emulator:9099`, `127.0.0.1:9099`, `localhost:9099`).
- Set in dev only: `docker-compose.dev.yml:81, :96, :104, :185, :191, :194, :228, :235`. `docker-compose.yml` (production) sets no `APP_ENV` (`docs/specs/local-auth-emulator/plan.md:30`).
- If the host is set but a condition fails, the mode is `refused` and every token is rejected (`verifier:104-112`).
- Token shape in `on` mode: unsigned JWT, header `alg: none`, empty third segment, `exp` in the future, `iat` present (`verifier:199-220`). `email`/`email_verified` come from an HTTP call to the emulator's `accounts:lookup` with a 2 s timeout, and `localId` must equal `sub` (`verifier:227-255`).
- Client side: `TSR_AUTH_EMULATOR_HOST` dart-define, `host:port` (`mobile/lib/core/config/auth_emulator.dart:7-24`).

## 9. Tests covering authentication

| Area | File (under `tests/`) | Test count (grep) |
|---|---|---|
| Emulator verifier | `mobile-api/AuthEmulatorVerifierTest.php` | 9 |
| Firebase linking | `mobile-api/FirebaseLinkingTest.php` | 4 |
| Claim sync | `mobile-api/CustomClaimsSyncTest.php` | 13 |
| Deletion dependencies | `account-deletion/AuthDependenciesTest.php` | 3 |
| Deletion gate allowlist | `account-deletion/DeletionGateTest.php` | 8 |
| Prod emulator guard | `web/ProductionAuthEmulatorGuardTest.php` | 6 |
| Seed emulator guard | `web/SeedAuthEmulatorGuardTest.php` | 5 |
| Web emulator URL | `web/FirebaseWebEmulatorUrlTest.php` | 3 |
| Route tests using auth | about 51 files in `mobile-api/`, plus `account-deletion/CompletionTest.php` and `e2e/*.py` | not counted |

No test for the 403 `Registration incomplete` path was checked. Not verified: whether any test covers expiry or the JWKS-unavailable path.

## 10. Unknowns

1. Column collation of `users.email` (case-insensitive or not), and so whether `Foo@x` and `foo@x` match.
2. Whether `handleFirebaseServerError()` logs the token or claims (not read).
3. Whether the `users` row has `city` and `level` columns (only the whole-row shape was checked).
4. Whether a blocked or suspended status exists anywhere in `users` (none found on the auth path).
5. Guest access to `/geo/*` (section 4 conflict).
6. Full list of routes that skip `api_authenticate` (only the public list was verified).
7. Whether php-jwt leeway is set (clock skew); verifier code sets none.
8. Whether `log_admin_page_access` (`functions.php:392`) runs on any mobile path (admin pages only seen).
9. Contents of `.github/workflows/auth-emulator-guard.yml` and the production-guard tests (not read).
10. Whether `FIREBASE_PROJECT_ID` is set in the production compose as an env list (`docker-compose.yml:38, :80, :132`), and its effect on `aud` checks (not verified).
