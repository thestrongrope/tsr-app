# Handover 2026-11-10

The spike at `~/Projects/tsr-app` is a sample built from the plan in `docs/specs/repo-structure.md`
(its review, with all 22 findings applied, is `docs/specs/repo-structure-review.md`). Asif chose
C#/ASP.NET Core and "navigation + one slice". Still planning and spiking: **local git only** since
2026-11-10 (branch `main`, no remote, no GitHub repo). The public repo will start from one baseline
commit, so this history is never published. Do not add a remote or push without asking.

## Done
- **Sample, re-verified 2026-11-10 after the structure cut.** `dotnet build TsrApp.slnx` 0 warnings;
  15 unit + 10 boundary + 7 contract tests pass (contract tests against a rebuilt dev stack).
  `flutter analyze` clean; 9 Flutter tests pass (hosts/app 1, shared/app 2, platform/app 6).
  Domains with code: `platform` (health, submit-feedback, screen, site page), `content` (stub: articles), `identity` (verify-caller
  middleware), `access` (`Permissions`).
- **Structure cut (2026-11-10, spike-learnings D1, D4, D5, D11).** Removed 78 `.gitkeep` files and
  108 empty folders; folders now appear with their first real file. `access`/`identity` public
  interfaces moved from `features/` to the module root (namespaces `Tsr.Access.Api`,
  `Tsr.Identity.Api`). Send/submit naming unified on submit-feedback in code (the screen label stays
  "Send feedback"). `spec/events.yaml` and `spec/schemas/` dropped: field shapes inlined into
  `api.yaml`, the event shape is a table in `domains/platform/CLAUDE.md`. Navigation files point only
  at files that exist. `repo-structure.md` section 1 shows "Today" and "Target" trees.
  Snapshot of the repo before the cut: the session scratchpad `tsr-app-before-cut.tgz` (temporary).
- **Spikes moved out of the repo** to `~/Projects/tsr-spikes/` (aot-e2e, aot-e2e-net11, go-wasm,
  profile-bench); their hard-coded paths were updated. Dated records in `docs/specs/` still say
  `spikes/...`: read that as `~/Projects/tsr-spikes/...`.
- **Spike learnings (2026-11-09):** `docs/specs/repo-structure/spike-learnings.md`.
- **Stack decided (2026-11-09):** `docs/specs/dotnet-stack.md`, "complete, not yet built". Why the
  alternatives lost: `docs/specs/stack-research.md`. Evidence: `docs/specs/profile-bench/`,
  `~/Projects/tsr-spikes/aot-e2e/RESULTS.md`, `docs/specs/repo-structure/go-wasm-spike-results.md`,
  `docs/specs/db-portability/mysql-to-postgres.md`.
- `docs/specs/repo-structure.md`: the layout applies only after the deploy source moves to tsr-app
  (task L1); the 2026-11-28 flip publishes today's layout unchanged.

## Next action
Spike-learnings recommendation 1: run the 7 contract tests against tsr-account's PHP `POST /feedback`.
The "same contract tests pass on PHP and on the new API" claim has never been tested; the gateway's
PHP fallback is a hard-coded 404 (`hosts/gateway/default.conf`). Section 2 of spike-learnings lists
the divergences the code already suggests. Matters only while routes move off PHP one at a time.

## Site spike (2026-11-10)
Domains compose into all three deliverables. The static site: `docs/specs/site-spike/results.md`.
C# Razor + `HtmlRenderer`; each domain may add `site/` next to `api/` and `app/`; `hosts/site`
builds `build/site/` from the API. Added a stub `content` domain (articles, `GET /articles`,
public). **Adopted by Asif (2026-11-10):** rule 4 of `domains/CLAUDE.md` now covers public reads,
new rules 7 (site boundary) and 9 (no rules in `site/` or `app/`), `site/` is in the domain anatomy,
and `repo-structure.md` (trees, 2.2 "The site side", 3.1 `hosts/site`, open points), root
`CLAUDE.md` and `README.md` describe it. The dev DB got the articles migration and seed by hand
(`docker exec`), not by a volume reset; a fresh `down -v` loads them through `load.sh`.

## Plan review (2026-11-10)
`repo-structure.md` was brought in line with `dotnet-stack.md`: PostgreSQL and EF migrations as the
target, the sample named as predating the stack (MariaDB, MySqlConnector, xUnit, C# contract tests),
"types are generated" dropped, settled open points closed, new open points listed in its section 6
(`can()` shape, erasure test, PHP parity, when the sample moves to the stack, where EF migrations live).
Confirmed by Asif the same day: tsr-migrate stays in tsr-account, and Hurl replaces the C# contract
tests (this answers spike-learnings open question 3).

## Plan split (2026-11-10)
`repo-structure.md` is now the lasting design only (602 → 322 lines, 5,900 → 2,900 words). The move from
tsr-account went to `docs/specs/repo-structure/migration-from-tsr-account.md`; the rules live only in
`domains/CLAUDE.md` (rules 10-12 added). The pre-split plan is kept as
`docs/specs/repo-structure/full-2026-11-10.md`; delete it once Asif has read the short one.

## Order of work (2026-11-10)
Agreed with Asif, in `docs/specs/repo-structure/migration-from-tsr-account.md` ("Order of work", replacing
Stages 0-3): 1 Postgres in tsr-account (3-5 weeks, one cutover, the prerequisite); 2 foundation once
(Firebase verifier, `can()` scope shape, gateway in production, outbox relay); 3 slices one domain at a
time, a route with its queries; 4 the Flutter app and the static site last. Not decided: a Postgres
baseline schema or port the 67 MariaDB migrations; whether the outbox is still built in PHP first.
Rule from Asif: text stays case-insensitive on Postgres (`citext`); a case-sensitive column needs a
distinct written reason. Two guards are specified there and not built: a MariaDB-vs-Postgres parity
run before cutover, and a CI schema check. The accent test on synthetic names is not done.
`target-architecture/plan.md` still has the old stages.

## Document database check (2026-11-10)
Asked: would Firestore or Cosmos DB cost less than Postgres? Answer: no. `docs/specs/document-db/`
(`workload-shape.md` by Haiku, `cost-and-fit.md` by Sonnet, `grok-review.md`). Self-hosted Postgres is
about $0 marginal; the app has about 145 joined queries and a 3,464-line report module. Prices in
those files are rough and several are marked unverified.

## Public surface tightened (2026-11-10)
In each domain `api/` library only the module class and the listed interface are public (access:
`Permissions`); the other 17 types are internal. New test `hosts/api/tests/PublicSurfaceTests.cs` (failed
first on identity, platform, content). Verified after the change: build 0 warnings; unit 15, API
boundary 16, site 12, platform contract 7, content contract 4 against a rebuilt dev API; site builds 4
pages. Flutter not rerun (untouched). `FeedbackSubmitted` is internal too: nothing consumes the C# type;
it moves to the module root when an in-process consumer exists. `site/` libraries were not tightened.

## Initial build plan (draft, 2026-11-10)
`docs/specs/initial-build/plan.md`: build the API and site locally to parity with tsr-account, then
publish once. Agreed the same day (see below). It would replace the order of work above (PHP never moves to Postgres;
one cutover). Three decisions wait on Asif: all-at-once cutover, local `git init`, no GitHub tracking
before the baseline.

## Initial build: phases 0 to 2 done (2026-11-10)
Plan agreed: `docs/specs/initial-build/plan.md` (all-at-once cutover, local git, no GitHub tracking
before the baseline). Its checklist and "Checkpoint 2" hold the current state and the open items.
`identity` verifies Firebase tokens (emulator in dev, `tools/dev-auth/mint-token.sh`); `access` has the
PHP permission engine (`CanAsync`, `ReachAsync`, `ForUserAsync`, port `IClassScopes`). The dev header
`X-Dev-Token` is gone. Contracts: `tools/identity-contract.sh dev|parity`, `tools/access-contract.sh
dev|parity`. PHP parity stack: `tools/parity-php/README.md` (synthetic data only; never use
tsr-account's own long-running containers, they hold real member data). Next: phase 3, `platform` first.

## Then
1. D2 (Asif decides): `api.yaml` generated from the C# endpoints with a CI diff, or hand-written with
   a route check.
2. Skills only after a task is done by hand twice (`add-slice` after slice 2).
3. `dotnet-stack.md` "To verify" list: MediatR/AutoMapper/FluentAssertions licences, MinIO status,
   Dokploy running Hurl and promoting the image, the OTel Collector file exporter.
4. Done: the sample's tests are NUnit and its contract tests are Hurl files (2026-11-10).
5. **.NET 11:** `~/Projects/tsr-spikes/aot-e2e-net11/RESULTS.md` (2026-11-10, RC3): drop-in, all
   tests pass, but idle memory 85 MiB vs 23 MiB (native, not GC heap; cause unknown). Asif chose to
   wait for GA: rerun on GA packages, then decide whether `dotnet-stack.md` moves to 11.
6. Small naming leftover: the Flutter feature still uses `send()`, `SendStatus`, `SendResult`, `Sent`
   for the network call; rename to submit only if it starts to confuse.

## Containers
Only `tsr-app-dev-{api,gateway,db}` run (migrate and seed exit after one run) (rebuilt 2026-11-10). All spike and benchmark containers
(`tsr-aot-*`, `tsr-aot11-*`, `tsr-bench-*`, 19 in all) are stopped, not removed. They were created
from the old `tsr-app/spikes/` path, so `docker start` breaks their bind mounts: use
`docker compose up -d` from the folder in `~/Projects/tsr-spikes/` to recreate one.

## Traps
- The dev gateway is reached by its OrbStack name, `https://gateway.tsr-app-dev.orb.local` (host port 8080 belongs to OrbStack).
- NuGet audit fails on old pins. Package versions live only in `Directory.Packages.props`.
- `FeedbackText` counts code points, to match PHP `mb_strlen`.
- Dev DB is PostgreSQL 18: compose runs `migrate` (API image `--migrate`) then `seed` (`db/synthetic/seed.sql`, psql). `postgres:18` data mounts at `/var/lib/postgresql`. EF migrations stay as generated (public): `PublicSurfaceTests` skips EF migration and snapshot classes by base type, so no hand edit is needed (command in root `CLAUDE.md`). The API connects as the limited `tsr_app` role (`db/init/01-app-role.sql`); `migrate` runs as the owner `tsr` in Production mode and grants `tsr_app` its rights. `dotnet test db/tests` needs Docker.
- The auto-mode classifier sometimes returns no verdict on Write: retry once.
- Out of scope on purpose: the private data repo and the other TSR tools.
- Claude's project memory for this folder used to hold an unrelated Patrol handover (the old
  tsr-app, archived into tsr-account). That work is not this repo's.
