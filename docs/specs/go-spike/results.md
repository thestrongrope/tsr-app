# Go spike: results (25 Nov 2026, stopped by Asif after round 1)

Plan: `plan.md` (same folder). Port details: `port-notes.md`. The spike branches and Go code were removed after the write-up.

## Verdict
**Go is not adopted.** It gives more handwritten code than C#, not less, and round 1 showed no clear saving per change
once correctness and gate size are counted. Asif stopped the spike after round 1 (25 Nov 2026): "I don't see the point
of continuing if we aren't getting fewer lines of code." Epic 95 continues in C#.

## 1. End-state size of `access` (measured)
| Side | Files | Handwritten non-blank lines | Generated |
|---|---|---|---|
| A. C# JIT + EF (`8966df3`) | 35 | 2,911 | - |
| B. C# no EF (`a1fb3af`) | 36 | 3,075 | - |
| C. Go (`spikes/go-access/`) | 14 Go + 1 SQL | 3,448 Go + 146 SQL = 3,594 | 1,612 (sqlc, oapi-codegen) |

Go is about 17% more than B and 23% more than A. The extra is mostly explicit error handling (112 `if err != nil`).
sqlc earned its place: 31 queries checked at build time, one database call outside it.
Leaving EF added only 164 lines (about 6%) to `access`; PR 115's +5,290 was mostly tests and documents.

## 2. The port (agent's figures; gates re-run by me)
- Sonnet `developer`: 336k tokens, 93 tool calls, about 23 min, 0 failed Hurl gate runs before green.
- Re-run by me: `go vet` clean, `go test` passes, Hurl on lane 6 against the Go service: 3 + 16 files, 0 failures,
  no Hurl file changed (3 `*-php-only` files skipped). My own planted bug (gender check in `classaccess.go`) failed 2 of
  16 files; reverted, 16 of 16 again.
- Deviations from C# (from `port-notes.md`): members found by email, not Firebase uid (`v_users` has no uid column);
  member creation, uid stamp, profile sink and sign-in tracking not ported; `identity.account_deletion_requests` and the
  `classes.tags` tables read directly (no `v_*` view exists).
- Side finding, true on `develop` whatever the spike decides: `domains/access/spec/api.yaml` line 239 is invalid YAML.
- sqlc's cgo build does not link on this Mac; it ran from the Docker image `sqlc/sqlc:1.30.0`.

## 3. Change task T1, all three sides (agents' figures; NOT re-run by me)
T1: `GET /me/permissions` gains `granted_count`. Same Sonnet brief (`change-brief.md`), run side by side.

| Side | Tokens | Tool calls | Wall-clock | Failed gate runs | Correct |
|---|---|---|---|---|---|
| A. C# JIT + EF | 55k | 22 | 3.8 min | 0 | yes |
| B. C# no EF | 84k | 22 | 6.9 min | 2 | yes |
| C. Go | 50k | 14 | 2.3 min | 0 | **no** |

- C counted a permission also given by the role, against the task's "not by role". No test caught it: on the fixture
  member no direct grant overlaps the role, so every side answers 2. Green gates did not prove the change.
- C's gate was lighter: Go has no database tests; A and B also passed `db/tests` (about 142-145 access tests).
- B's two failed runs came from guardrails added during the AOT conversion: a test pinning the public signature, and
  17 golden files to re-record.
- One task, one run each: a hint, not evidence. T2 and T3 were not run.

## 4. Open signal, not pursued
A (EF) took about 34% fewer tokens and 45% less time than B for the same change. If the AOT trade is reopened, run T2
and T3 (`plan.md`) on A and B only first (estimate 0.4M tokens). What AOT buys, for that comparison: first request after
a restart about 300 ms to 9-15 ms, lower memory, smaller image; throughput about 85% of JIT.

## What was not done
- T2 and T3 on any side; round 1's gates were not re-run by me; no Opus `qa` review of this write-up.
- The native publish time for side B was never measured.
- Spend: about 0.53M of the 5.5M cap.

## Cleanup (25 Nov 2026, on Asif's word)
The four worktrees, their local branches and lane stacks 2, 5 and 6 (with volumes) were removed; the Go code is gone.
Only these four documents were kept. Still installed: the image `sqlc/sqlc:1.30.0` and `~/go/bin/oapi-codegen`.
