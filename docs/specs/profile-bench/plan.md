# Profile benchmark: PHP vs C# vs Go (spike, 2026-11-09)

Goal: compare performance of a real read across three stacks, like for like. Asif's priority is perf.
Throwaway spike quality: correct, measured, not polished.

## Decisions (Asif, 2026-11-09)
- Endpoints: copy the existing PHP `GET /me` and `GET /me/permissions` exactly (tsr-account,
  `web/api/mobile/index.php:31` and `:43`; handlers `routes/users.php:34`, `routes/permissions.php:148`;
  model `web/models/permissions.php` resolve() :329-415; shape `api_user_spec()` users.php:12-31).
- Auth parity, **without Firebase** (Asif: Firebase is external, not part of what we benchmark).
  All three stacks replace the Firebase token verification with the same stub: `Authorization:
  Bearer <firebase_uid>` of a synthetic user, then the users lookup by firebase_uid. Everything
  after verification stays as PHP does it (`web/api/mobile/lib/auth.php:106-181`): the email/token
  checks, the accountdeletion check and the per-request `UPDATE users` login write. PHP gets the
  stub through a bench-only patched copy of the verifier in the bench build context; tsr-account
  itself is not edited. No emulator, no Firebase calls.
- Go shape: plain Go microservices, no wazero: `identity` (auth, /me), `access` (/me/permissions),
  `classes` (taught/enrolled/assigned data), calling each other over HTTP. A gateway or the access
  service fronts the route; no shared DB tables across services is the ideal, but all read the same
  physical dev DB (note any table a service reads that it would not own).
- C# shape: slices in the tsr-app modular monolith (`domains/identity`, `domains/access`), in-process.
- PHP: tsr-account as it runs locally (Apache mod_php 8.5, opcache on, JIT off).

## Bench stack (Asif, 2026-11-09)
The usual local tsr-account DB (`tsr_mysql`/`tsr_account`) holds real member data and the running
`tsr_mobileapi` has real Firebase credentials: **never read, use or touch either.** Instead, a
separate throwaway compose project `tsr-bench`, in `tsr-app/spikes/profile-bench/stack/`:
its own MariaDB (same version as tsr-account dev, own volume) loaded by tsr-account's synthetic
generator at about prod scale (about 26k users, classes and enrolments in proportion); its own
PHP mobileapi built from tsr-account's Dockerfile, with `APP_ENV=local`, a `demo-*` project id and
the emulator; and the existing `tsr_firebase_emulator` (or its own emulator). No real secrets in
its env. Remove with `docker compose -p tsr-bench down -v`.

## Fairness rules
- One database: the `tsr-bench` MariaDB with synthetic data only.
- Same CPU/memory limits on each stack's app containers (e.g. 2 CPUs, 512 MB per stack total;
  Go's three services share that budget). Same protocol path where possible; note TLS differences.
- Load from k6 (`grafana/k6` image, reuse `tsr-account/tools/perf/k6`) inside the Docker network.
  Warm-up, then 1, 10, 50 VUs; p50/p95/p99, req/s, errors; idle and under-load RSS; image size; LOC.
- Responses from all three must be identical JSON for the same synthetic user (contract tests).

## Scope update (Asif, 2026-11-09, late morning)
- The real candidates are **Python, C# and Go**. PHP is only the baseline (moving off it is decided).
- Most tsr-app APIs are lightly or rarely used, so also measure what matters for them, for Python,
  C# and Go: first-request latency after a cold container start (and after about 10 min idle),
  idle RSS of the whole stack, and LOC per slice. Throughput at 50 VUs is secondary.
- Story 2c: Python (FastAPI, async, uv), modular monolith, port 4108, project `tsr-bench-py`.

## Fix round (Asif approved, 2026-11-09 afternoon; budget about 300k more tokens)
From `review.md` and its verification table:
- F1: C# logging at Warning (env vars in a compose override, no code change); Python B gets TCP_NODELAY.
- F2: Go **monolith** control: one process, the identity/access/classes packages in-process, the same SQL,
  port 4110, project `tsr-bench-gomono`, 2 CPU / 512 MB.
- F3: (a) a real long-idle test: warm every stack (200 requests per route), all idle together, probe at
  10 and 30 min (requests 1, 2, 10), 3 reps; then (b) load at 10 and 50 VUs, both routes, 3 reps,
  in **interleaved/rotated stack order**. Stacks: PHP (ref), C# (Warning), Go micro (a), Go monolith,
  Python A, Python B (fixed). Go (b) is dropped.

## C# follow-up (Asif, 2026-11-09 evening; time-boxed: about 1 h machine time, about 200k tokens, 1 rep only)
C# is the likely pick. Two questions:
- E1, EF Core as the mapper: hand-written SQL stays, but goes through EF Core (`Database.SqlQuery<T>` /
  `FromSql`, AsNoTracking, a DbContext per module if natural). Same SQL as the raw C# stack. Port 4111,
  project `tsr-bench-csef`. Check which MySQL EF provider supports EF Core 10 (Pomelo or Oracle's) before choosing.
- E2, a file-based app (`dotnet run app.cs`, .NET 10 `#:` directives): the same two routes in one file with raw
  MySqlConnector, run then published to a container (NativeAOT if that is the default; confirm). Port 4112,
  project `tsr-bench-csfile`.
- E3, measure raw C# (4106), E1 and E2: contract 20/20, 1 load rep at 10 and 50 VUs for both routes, cold-start first
  request (3 tries), idle RSS, image size, LOC.
Only the .NET 10 SDK (10.0.401) is installed; re-check on the next .NET release, which is not installed yet.

## Stories
1. Contract: capture PHP responses for a few synthetic users, write HTTP contract tests that any
   stack must pass, and a k6 script parameterised by base URL. Output: `spikes/profile-bench/contract/`.
2a. C# slices (depends on 1). 2b. Go services (depends on 1). Run in parallel.
3. Benchmark run and report: `docs/specs/profile-bench/results.md`.
4. Opus fairness review of the results.

## Limits
- Do not edit tsr-account files. Starting services defined in its `docker-compose.dev.yml` is fine.
- Do not touch prod, other projects' containers, Docker settings, or install system packages.
- Budget: about 1M subagent tokens for stories 1-4, including 2c (raised from 800k by Asif, 2026-11-09). The fairness review stays in.
