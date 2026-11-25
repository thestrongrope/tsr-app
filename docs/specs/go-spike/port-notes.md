# Go port of `access`: notes

Branch `spike/go-access` (local, uncommitted). Everything is in `spikes/go-access/`; nothing under `domains/`, `shared/`, `hosts/` or `db/` was touched.

## Result

All 19 non-PHP-only Hurl files pass against the Go service on lane 6, no Hurl file changed (433 requests, 0 failures). `go vet` clean, `go test` passes (50 tests, 713 lines of tests).
The planted bug was caught by two Hurl files. A separate byte comparison against the C# API (248 requests, status, five headers and body) shows 0 differences.

| Time | Wall clock (IST, 25 Nov 2026) |
|---|---|
| Start | 07:22:15 |
| First green Hurl run, both scripts, on the Go service | 07:36:54 to 07:37 (the Go container logged its start at 07:36:54; the first green run came in the next call) |
| Final gate after the planted bug was reverted, both scripts, tests, byte comparison | 07:40:37 |

Start to first green: about 14 min 40 s (the headline; the rework count refers to it). Start to final gate: 18 min 22 s.

Rework rounds: **0 Hurl gate failures before green** (the first run of `access-contract.sh test` and `contract-grants.sh test` against the Go service was green).
Other checks that failed once and were fixed: `sqlc generate` 3 times (the pg_dump `\restrict` lines, two ambiguous column names, then nullable columns that came out as `interface{}`), `oapi-codegen` once (api.yaml is invalid YAML), my own contract test once (a wrong assertion), the byte comparison once for a real difference (`ETag` header name came out as `Etag`) and twice for bugs in the comparison script itself.
The unit tests were written first and failed to compile (undefined symbols) before the code existed; `jsonio_test.go`, `auth_test.go` and `contract_test.go` were written after their code (spike, noted below).

## What was built (`spikes/go-access/`)

| File | Holds |
|---|---|
| `main.go` | config from the environment, the 13 routes on `net/http` `ServeMux`, 404 `{"detail":"Not Found"}`, Npgsql connection string to pgx pool |
| `server.go` | `member()` wrapper: method check (405 JSON), sign-in in PHP's order, `X-Permissions-Revision`, error mapping (503 / 500); `inTx` |
| `auth.go` | Firebase token verification: shape, claims (no skew), emulator mode (unsigned token plus `accounts:lookup`, 2 s timeout, email and verified flag from the emulator account), Google RS256 keys with a 1 h cache and 5 s timeout, the emulator gate |
| `permissions.go` | per-request permission resolution with `forget`, the classes port (published views) |
| `engine.go`, `rules.go`, `snapshot.go`, `legacy.go` | the pure rules: engine, rule matcher, grant rules, class access rules, navigation and revision, `/user/permissions` |
| `me.go`, `grants.go`, `classaccess.go`, `outbox.go` | the 13 handlers, outbox events |
| `jsonio.go` | JSON writer (no HTML escaping), `JsonBody` semantics (empty body, root list, lone surrogate, last repeated key), PHP `(int)` of a path segment, `Cast.Text` |
| `db/queries/queries.sql`, `db/schema.sql`, `sqlc.yaml`, `dbq/` | sqlc input and generated code (`dbq/` generated) |
| `oapi.yaml`, `api.fixed.yaml`, `gen/` | oapi-codegen config, the api.yaml copy with line 239 quoted, generated types (`gen/` generated) |
| `Dockerfile`, `.dockerignore`, `compose.go-access.yml`, `gateway.conf`, `lane.sh` | scratch image of a static linux/arm64 binary, compose overlay for lane 6, the gateway conf copy with the 13 locations pointed at the Go container |
| `generate.sh`, `diff-check.sh` | regenerate the generated code; byte comparison with the C# API |
| `*_test.go` | engine, rules, snapshot (the two revision values PHP computed), legacy, JSON, auth, contract drift |

Size: 3,800 lines of Go by hand (largest: `classaccess.go` 1,039, `rules.go` 574, `grants.go` 444), 713 lines of tests, 183 lines of SQL; generated: `dbq` and `gen` about 1,800 lines together.

## Differences from the C# service, and what was skipped

Sign-in (`CallerMiddleware`, `MemberDirectory`). **The one that matters in production is the first.**
1. **Members are found by email only, not by Firebase uid first.** The reason is a finding about the view contract: `identity.v_users` has no `firebase_uid` column, and the plan says to read the member through `v_users`. What it does: a member whose stored uid matches but whose Firebase email is unverified gets 404 `User not found` from Go (Firebase password accounts are often unverified; C# finds them by uid and admits them), and a member who changed their email in Firebase gets 404 too (C# finds them by uid). One query on `identity.users` would close the gap, the same kind of direct read as item 4 below; I followed the views-only rule over fidelity.
2. Sign-in tracking write skipped (as briefed).
3. **No member creation on a first sign-in** (every access route is `createsMember: true` in C#): an unknown email answers 404 `User not found`. No Hurl file needs it (fixtures are seeded). **No uid stamp and no profile sink on an email claim** either (writes, skipped with the tracking write).
4. Recently deleted and live-deletion checks read `identity.account_deletion_requests` directly: no published view exists. Boundary deviation, read only.
5. Google RS256 verification (non-emulator) is written and unit tested only for "unsigned token refused"; it has never run against a real token.

Classes port:
6. Reads `classes.v_classes` and `classes.v_enrolments` (published). Tags have no view: `classes.class_tags` and `classes.tags` are read directly. Boundary deviation, read only.
7. The class access grant reads the active classes before the write transaction opens (C# reads them inside it, on a second connection). Same answer; a class created between the two reads is the only difference.

Engine:
8. Not ported because none of the 13 routes can reach it: a class target in `Check`, and the parts of `Reach` other than `All` and `Gender` (search reach, assigned-only ids, gender lock).

Wire details:
9. `html.UnescapeString` replaces `WebUtility.HtmlDecode` (Go decodes HTML5 names and entities without a closing semicolon; .NET does not). Closer to PHP, different from C#.
10. A POST with no Content-Length to a GET-only route: C# (through nginx) answered 400, Go answers 405. Found by the byte comparison; not looked into.
11. Go escapes U+2028 and U+2029 and turns invalid UTF-8 into U+FFFD; not compared with .NET.
12. A 500 answers `{"detail":"Internal Server Error"}`; the C# unhandled-error body was not checked.
13. `ServeMux` redirects paths with `//` or dot segments (301); ASP.NET does not. A query string with a bad percent escape loses that pair in Go. Neither tested.
14. Per-request resolution makes the same commands as C# (1 stored read, 1 memberships read, and 4 more for a member with rules).

Hurl files skipped (PHP only, they pin PHP's looser rules; the new API is stricter by the owner's decision and `tools/contract-grants.sh test` skips them too):
`admin-permission-self-php-only.hurl`, `class-access-peers-php-only.hurl`, `class-access-revoke-php-only.hurl`.

## api.yaml mismatches (found while porting; not an exhaustive audit)

1. **Not valid YAML** at line 239 (`description:` with an unquoted `: ` in "(super admin: both genders; ...)"). `oapi-codegen` refuses it. `generate.sh` quotes that line in a copy; the original is unchanged.
2. `name` and `description` fields are typed `string`, but C# sends the number `0` for an empty one (`Cast.Text`, PHP's api_cast). Affects member names, permission descriptions, level names, class names, a rule's note.
3. `ClassAccessSaved` is `allOf` with `ClassAccessView`, whose `member` and `version` are required and not null, but C# sends `member`, `version` and `fromRole` as null when the view cannot be read after the commit (the response text says so).
4. `oapi-codegen` v2.9.0 reads the 3.1 file after fix 1, but sorts struct fields alphabetically and leaves nested objects as anonymous structs. The response structs are hand written to keep C#'s field order; `contract_test.go` pins their top-level field names to the generated types. The generated request types are unused, because request bodies are read with `JsonBody` semantics (type checks per field, an empty body, a root list).

## Commands (from the worktree root; lane 6 is up)

```
# regenerate (schema only if lane 6 is up): dbq/ (sqlc in Docker) and gen/ (oapi-codegen v2.9.0)
spikes/go-access/generate.sh [schema]
# unit gate
cd spikes/go-access && go vet ./... && go test -count=1 ./...
# build the static linux/arm64 binary, build the scratch image, start the container on lane 6, point the gateway's 13 access locations at it
TSR_STACK=6 spikes/go-access/lane.sh up        # lane.sh down (removes the Go container, recreates the gateway on the old conf) is written but NOT RUN
# the Hurl gate (no Hurl file changed)
TSR_STACK=6 tools/access-contract.sh test
TSR_STACK=6 tools/contract-grants.sh test
# byte comparison with the C# API (starts and removes its own container goaccess-cs-proxy on 127.0.0.1:18606)
TSR_STACK=6 spikes/go-access/diff-check.sh
```

`lane.sh` runs `docker compose -p tsr-app-test-6 -f docker-compose.dev.yml -f build/test-6/compose.override.yml -f spikes/go-access/compose.go-access.yml` with `up -d --no-deps` so the C# API, database and seed are untouched. It refuses any lane but 6.
`tools/test-stack.sh up` rewrites the lane's gateway back to C#; run `lane.sh up` again after it.

## Hurl results (lane 6, Go service, 25 Nov 2026 07:40)

| Script | Files | Requests | Failures |
|---|---|---|---|
| `tools/access-contract.sh test` | 3 (`me-permission`, `me-permissions`, `user-permissions`) | 85 | 0 |
| `tools/contract-grants.sh test` | 16 | 348 | 0 |

The same two scripts on the C# API before any Go code: 3 files / 85 requests and 16 files / 348 requests, all green (the baseline).
Per file, grants script: `admin-permission-grant` 51, `admin-permission-member` 16, `admin-permission-members` 22, `admin-permission-revoke` 24, `admin-permission-nul-new-api` 4, `admin-permission-self-new-api` 4, `class-access-effect-new-api` 15, `class-access-grant` 56, `class-access-member` 20, `class-access-members` 19, `class-access-options` 7, `class-access-peers` 16, `class-access-peers-new-api` 3, `class-access-preview` 51, `class-access-revoke` 37, `class-access-revoke-new-api` 3.

## Planted bug

In `rules.go` the not-grantable list lost `class-access:manage:all`. `go test` failed. After rebuilding the container, `tools/contract-grants.sh test` had 14 of 16 files green and 2 red:
- `admin-permission-member.hurl:69`: `jsonpath "$.grantable[?(@.name=='class-access:manage:all')]" not exists` (actual: an object)
- `admin-permission-grant.hurl:172`: `HTTP 422` (actual 200)

Reverted; the full gate was green again at 07:37:36 and again at 07:40:37 after the last edits. This also proves the gateway sends the access paths to the Go container.

## Byte comparison with C#

`diff-check.sh` sends 248 requests (41 request shapes for 5 signed-in operators and a caller with no token, plus 2 bad-credential requests: reads, odd path segments such as `0`, `abc` and `9.25e5`, `q[]`, an encoded colon, bad bodies, wrong methods, unknown sub-paths, refusals) to the Go service and to the C# API and compares status, `Content-Type`, `ETag`, `Cache-Control`, `Vary`, `X-Permissions-Revision` and the body (`issued_at` blanked). Final run: 0 differ. It found the `ETag` name casing (fixed by writing the header map key directly).
Writes are covered by the Hurl files only; outbox rows written by Go were looked at (`access.permission_revoked`, `access.class_access_rule_created`, `access.class_access_rule_revoked`: camelCase payload, uuid v7 id).

## Observations on the stack choice

- sqlc: a `::text` cast makes a nullable column non-null in the generated type, and a nullable column read through a view or join came out as `interface{}`. Both were avoided with `coalesce(x::text, '')`, which is exact only because the C# code treats null and empty alike on those fields (`Cast.Text`, `Cast.TextOrNull`, `GenderOf`). Where null and empty differ, a column override would be needed.
- sqlc needed `citext`, `pg_catalog.timestamptz` and nullable `int4`/`text` overrides, and the schema dump needed its `\restrict` lines removed. `uuidv7()` (PostgreSQL 18) made the outbox id a one-liner.
- pgx handled `citext` as a plain string both ways; text compared with a citext column needs `::citext`, as in C# (all such parameters carry it).
- Nothing holds a transaction while another query uses the pool, except the guards, which read only the request's cached resolution or the same transaction.
- The service is a 11 MB static binary in a `scratch` image.

## Complexity flags (rule: cyclomatic complexity at most 10; measured with a 25-line `go/ast` counter of `if`, `for`, `range`, `case`, `&&`, `||`; `gocyclo` was not installed and was not fetched)

Over the limit: `hasLoneSurrogate` 20, `adminPermissionGrant` 17, `classAccessPreview` 16, `operator.guard` 13, `authenticate` 13, `noteFor` 12, `grantView` 12, `adminPermissionRevoke` 12, `writeRevoke` 11, `classAccessMembers` 11, `fromEmulator` 11, `checkClaims` 11.
Nothing was refactored (it would need another full gate run). The handlers mirror the C# slices step for step; splitting them is mechanical.

## Lane 6 at the end

Left up. The lane gateway sends the 13 access paths to `tsr-app-test-6-goaccess-1`; the C# API (`tsr-app-test-6-api-1`) is still running behind it for every other path. `lane.sh down` was not run.
