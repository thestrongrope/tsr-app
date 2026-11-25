# Go spike: `access` like for like (plan, approved by Asif 25 Nov 2026)

Question: is Go cheaper than C# (AOT-bound, no EF) per verified change, for an agent working on this repo?
Branch `spike/go-access` (local only, never merged), cut from `origin/develop` at `a1fb3af`.
Budget: 5.5M tokens (see "Three sides"), about one day; stop at the cap.

## Three sides (JIT C# with EF added by Asif, 25 Nov 2026)
| Side | Code | Gate loop |
|---|---|---|
| **A. C# JIT + EF** | `access` as it was before its conversion: `8966df3` (the first parent of PR 115's merge). 35 files, 2,911 non-blank lines; tests beside it 864 lines; 14 EF calls | `dotnet build` + access tests + Hurl on the JIT image |
| **B. C# AOT-bound, no EF** | `access` on `origin/develop` `a1fb3af` (figures below) | as A, plus the native publish time, measured once |
| **C. Go** | the port in `spikes/go-access/` | `go build` + `go test` + Hurl |

Side A's change runs start from `8966df3`, so the rest of the repo is older there; `access` itself depends on no domain.

## Decision rule (agreed before building)
Go wins only if it is clearly cheaper on the change tasks than B (about 30% or more in tokens and wall-clock together),
with every Hurl file passing unchanged. A tie or a small gap means finish epic 95 in C#.
If A is clearly cheaper than B by the same margin, the AOT trade is reopened: the cost per change is set against what
AOT buys (first request about 300 ms to 9-15 ms, memory, image size; throughput is about 85% of JIT).
Budget: 5.5M tokens (0.5M added for side A's three change runs).

## Scorecard
1. **End-state size**: handwritten non-blank lines and files of `access` in C# (`origin/develop`, `domains/access/api`
   without `Migrations/`, `tests/` and `*.Tests.cs`: 36 files, 3,075 non-blank lines; tests beside it 10 files, 1,011 lines;
   access-related `db/tests` 5,740 lines) against Go. Generated code (sqlc, oapi-codegen) counted on its own line.
2. **Verification loop time**: C# = `dotnet build` + access tests + Hurl (native publish time measured once and added);
   Go = `go build` + `go test` + Hurl.
3. **Cost per change**: the three tasks below, each on all three sides, fresh worktree from the same baseline, same model
   (Sonnet), same brief, same gates. Record tokens, wall-clock, tool calls, rework rounds (gate failures before green).

## Port rules
- Go `access` in `spikes/go-access/`: `net/http`, `pgx/v5`, `sqlc` (Docker image `sqlc/sqlc:1.30.0`; the cgo build of sqlc
  does not link on this Mac), `oapi-codegen` v2.9.0 from `domains/access/spec/api.yaml`. If `api.yaml` disagrees with
  the C# code, that is a finding: record it, follow the code.
- Schema: `pg_dump --schema-only` from a migrated synthetic lane stack. EF stays the owner.
- Same behaviour as C# for the 13 routes: `{"detail"}` errors, PHP's refusal order at sign-in, the
  `X-Permissions-Revision` header, ETag/304/503 on `/me/permissions`.
- Sign-in: verify the Firebase token (emulator mode on the test stack), read the member through `v_users`/`v_members`.
  **The sign-in tracking write is skipped** (out of scope, recorded).
- Class facts (`IClassScopes`): read through published `v_*` views, as C# does.
- Gate: the 22 Hurl files in `domains/access/spec/tests` pass on lane 6 with the gateway sending access paths to the
  Go container, no Hurl file changed; one planted bug must make Hurl fail.

## Change tasks (written before either side is built; do not edit)
**T1, add a field.** `GET /me/permissions` gains `"granted_count"`: the number of permissions in the answer that the
caller holds by a direct grant (not by role). Additive only. A test proves it, and one Hurl assertion is added.

**T2, add a refusal rule.** `POST /admin/permissions/members/{token}/grants` refuses with 409
`{"detail": "Member has a pending account deletion"}` when the target member has a live account deletion request
(identity's data, read only through a published `v_*` view; if no such view exists, the task adds it in identity's
migration as C# would). Checked after the permission check, before the write. A test and a Hurl file prove it.

**T3, add a read route.** `GET /admin/permissions/grants/{id}` answers one grant (id, token, permission, granted_by,
granted_at, revoked_at; names as the grants table has them) to a caller who may manage permissions; 403 otherwise; 404 `{"detail": "Grant not found"}` when
absent. Added to `api.yaml` and the route catalog where the side has one. A test and a Hurl file prove it.

## Fairness notes for the results
Both ports had a reference to copy from (C# from PHP, Go from C#). The Go builder is briefed with the code and the
Hurl files, not with the hypothesis.
