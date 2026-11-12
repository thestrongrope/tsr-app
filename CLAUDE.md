# CLAUDE.md

`tsr-app`: The Strong Rope's monorepo, **domain-first**. One product, two delivery paths (a
Flutter app, a static public site), one API. This copy is a **working sample**: one real slice
(`platform/submit-feedback`) runs end to end; the rest is structure. The full design is
`docs/specs/repo-structure.md` (Part 1 is the one-page summary).

## North star (Asif, 11 Nov 2026): everything else is secondary

The repo is built and changed by AI agents, checked by a person. Every choice of architecture, language,
framework or pattern serves the five points below. The tech stack is not fixed: if another one serves them
better, we switch.

1. **Clean, simple code for agentic development.** Domains exist to keep one change in one place.
2. **Light context.** An agent reads one slice and its domain's `CLAUDE.md`, not the whole repo.
3. **A short development and verification loop**, including diagnosing a failure and the next change.
4. **Verifiable, testable output**, because agents are not deterministic. A change that cannot be checked is not done.
5. **Use the broader stack** where it lowers cost or improves performance.

**The test for any design choice:** cost per verified change = understanding + implementation + verification
+ rework (tokens, wall-clock time, tool calls and human review). An abstraction, layer, interface or second
representation of the same data stays only if it lowers that cost. "It is the proper pattern" is not a reason.
When a rule below works against the north star, say so and propose the change; do not follow it silently.

## Find your way

Folders exist only once they hold real files; the planned layout is in `repo-structure.md`.
Where an area has a `CLAUDE.md`, Claude Code loads it when you open files there; other agents:
read it before editing.

| You are working on | Go to | Read first |
|---|---|---|
| A business rule, an endpoint, a screen for one domain | `domains/<context>/` | `domains/CLAUDE.md`, then `domains/<context>/CLAUDE.md` |
| What a capability does today (requirements, rules, decisions) | `domains/<context>/capabilities/` | the capability's `.md` |
| What a domain is called, its actions and events | `domains/<context>/spec/` | `glossary.md`, `api.yaml`; events in the domain's `CLAUDE.md` |
| A new feature or change: spec, plan, verification | GitHub issue (spec), draft PR description (plan) | `spec-driven-development` skill; templates in `.github/` and `docs/templates/` |
| API startup, module list, middleware | `hosts/api/` | `Program.cs`, `Modules.cs` |
| The gateway (per path: PHP or the new API) | `hosts/gateway/` | `default.conf` |
| The Flutter shell | `hosts/app/` | `lib/main.dart` |
| The static site generator | `hosts/site/` | `SiteModules.cs`, `Program.cs`; a domain's pages are in `domains/<context>/site/` |
| Plumbing every domain uses (DB, outbox, HTTP client, site API reader) | `shared/api/`, `shared/app/`, `shared/site/` | the file you need; no rules live here |
| A table or migration | the domain's `api/<Context>Context.cs` and `api/Migrations/` (add: `dotnet ef migrations add <Name> --context <Domain>Context --project domains/<d>/api --startup-project hosts/api --output-dir Migrations -- --TSR_DB=Host=unused --TSR_FIREBASE_PROJECT_ID=demo-design --environment=Development`; the generated files need no edit) | `docs/specs/initial-build/phase-0-design.md` |
| Synthetic data | `db/synthetic/seed.sql` | |

Today's PHP API stays in tsr-account until routes move here. Domains planned: `identity` (AuthN)
· `access` (AuthZ) · `membership` · `classes` · `assessment` · `content` · `notifications` ·
`platform` · `search` (read model). All nine exist and route the whole API surface: the **route catalog**
`docs/specs/initial-build/operations.csv` lists PHP's 213 operations (method, path, domain, auth kind, state). A `built`
one has its slice; a `planned` one is a placeholder in its domain's `api/Planned.cs` that signs the caller in as the real
route will (never creating a member), then answers 501 `{"detail": "Not implemented"}`. **Building a slice replaces its
placeholder:** delete its line in `Planned.cs`, flip its state in `operations.csv` to `built` (the tests in `hosts/api/tests`
fail until both match; a gateway block per path already exists). Built today (12 Nov 2026): identity 10, access 13, platform 9,
membership 24, classes 94, assessment 35, notifications 24, content 1, search 1 (211); 2 are planned (`/me/guides`, not in the PHP copy). **Of the 211, 136 are PROVEN against PHP (Hurl on both sides, database tests, review); the other 75 are PORTED only** (build-out mode, Asif, 12 Nov 2026: compiles with zero warnings and passes the structure tests; no contract tests yet). The lanes, their notes and the findings to settle in the test phase: `docs/specs/initial-build/build-out-lanes.md`, `lane-*-notes.md`, `build-out-findings.md`. The report downloads (xlsx or PDF) all go through platform's `ReportExport` (`domains/platform/CLAUDE.md`). Tables only, besides routes: `notifications`; `assessment` has 9 quiz routes (batch A1: a member takes a quiz and reads scores).
`search` has routes only. Which owns what: `domains/CLAUDE.md`.

## Rules (the ones that must load without opening another file)

1. **Rules live in a domain, never in a client or a host.** Apps and the site are presentation;
   hosts only wire. A rule enforced only in the app is not enforced: the repo is public and anyone
   can build a modified client.
2. **Permissions go through `access`** (`Permissions.CanAsync(caller, action, target)`), checked in the slice's handler.
   **Gender segregation** is a scope from `access`, applied by each domain to its own data.
3. **A slice never calls another slice. SQL may read another domain only through its published `v_*` views** (never its
   tables); **a cross-domain write is that domain's published command** (a static method on the caller's transaction). Other
   calls use the listed public interface or events. Dependencies are listed in
   `<Context>Module.Dependencies`; both are enforced by `hosts/api/tests` (`domains/CLAUDE.md` rules 2 and 7).
4. **Every table has one owner** (a domain, or platform for outbox/infra tables). Migrations are
   expand-then-contract; never edit an applied migration.
5. **Prepared statements only.** Never build SQL from strings.
6. **No real member data, ever**: not in code, tests, seeds, docs or logs. Synthetic members only
   (`db/synthetic/seed.sql`, tokens 900000+, emails on `.invalid`). No secrets in git.
7. **The API stays forward compatible.** A store-live app build keeps calling what it called:
   add fields and routes freely; never remove or change one without the release process.
   Error bodies are `{"detail": "..."}`.
8. **Follow `CODING-GUIDELINES.md`.** Zero warnings: the .NET build treats warnings as errors;
   `flutter analyze` must be clean.

## Commands (from the repo root, Windows or Mac)

| Task | Command |
|---|---|
| Start the local stack (the dev database may hold REAL data: no contract script, seed or reset on it; PostgreSQL, migrate, seed, API, gateway on :8088) | `docker compose -f docker-compose.dev.yml up -d --build` |
| Reset the local database | `docker compose -f docker-compose.dev.yml down -v` |
| Start, stop, remove the synthetic TEST stack (own project `tsr-app-test`, gateway :8089, db :5434, emulator :19100, plus the internal-only `gotenberg` PDF renderer, no host port; the only stack Hurl may run against, because dev holds real data) | `tools/test-stack.sh up`, `down` (keeps its volume), `remove` (deletes it), `status` |
| Build all .NET | `dotnet build TsrApp.slnx` |
| Unit + boundary tests (no DB needed, NUnit) | `dotnet test domains/platform/api/tests` (likewise `domains/identity`, `domains/access`, `domains/membership`, `shared/api`), `dotnet test hosts/api/tests`, `dotnet test hosts/site/tests` |
| Database-backed tests (needs Docker: Testcontainers starts a throwaway postgres:18) | `dotnet test db/tests` |
| Contract tests, every Hurl file (on the TEST stack, never dev; `tools/test-stack.sh up` first; `tools/identity-contract.sh test` first mints the token into `build/test/token.vars` and refreshes the 2 hour fixture; `tools/membership-contract.sh test --prepare` resets the membership fixtures, loads the geo rows and mints one token per fixture member into `build/test/membership.vars`; `tools/classes-contract.sh test --prepare` loads the classes fixtures (it first deletes the members a bulk add created) and mints `build/test/classes.vars`; `tools/assessment-contract.sh test --prepare` loads the assessment fixtures (A1 and A2: the submit and edit files write rows, so every run resets them; run it LAST, after the classes one, and never alone between two Hurl runs: its members sit above the classes tokens, a bulk add hands out the next token, and a reset that renames them hides them from the bulk cleanup) and mints `build/test/assessment.vars`; Hurl runs the files in parallel, so no two files change the same member) | `hurl --test --glob "domains/*/spec/tests/*.hurl" --glob "hosts/api/spec/*.hurl" --variable base_url=http://localhost:8089 --variables-file build/test/token.vars --variables-file domains/identity/spec/tests/fixtures.vars --variables-file domains/access/spec/tests/fixtures.vars --variables-file build/test/membership.vars --variables-file build/test/classes.vars --variables-file build/test/assessment.vars` (162 files, 1945 requests; `hosts/api/spec/planned-surface.hurl` is the cross-domain spot check of the 501 placeholders, new API only; the PDF cases of the registrations and donors downloads are in `*-new-api.hurl` files because PHP's Dompdf runs out of memory on the parity database) |
| One implementation's contract (any base URL) | `tools/identity-contract.sh test` or `... parity` runs the sign-in contract on either side. For another file, same command with another `base_url` and `--variables-file` (PHP: `build/parity-php/token.vars`, written by `tools/parity-php/mint-token.sh <.invalid email>`); `--glob` is expanded by Hurl itself, so it works in any shell on Mac and Windows when the pattern is quoted. Hurl must be installed. |
| Access contract on PHP or the new API (stack up; PHP: parity stack) | `tools/access-contract.sh test` or `parity` (also `tools/identity-contract.sh`) |
| Membership contract on PHP or the new API (resets its fixture rows first, loads the geo rows, loads the B4b fixtures (tokens 9011xx, classes 9561 to 9563) and signs 35 fixture members in; the files accept invites and change profiles, so it must reset before each run; invite inspection allows 60 an hour per member, so the files make few calls) | `tools/membership-contract.sh test` or `parity` (`--prepare` stops after the preparation) |
| Classes contract on PHP or the new API (loads its fixtures into that side, signs 9 fixture members in; the slices only read, so no reset and files may run in parallel; `--prepare` stops after the preparation) | `tools/classes-contract.sh test` or `parity` |
| Assessment contract on PHP or the new API (loads the A1 fixtures into that side on every run, signs the fixture members in; the submit files write answers, the reset deletes them; no two files answer the same quiz as the same member; `--prepare` stops after the preparation) | `tools/assessment-contract.sh test` or `parity` |
| Platform contract on PHP or the new API (loads the geo rows from `db/synthetic/geo-fixtures.sql` into that side first; the three geo files spend about 35 of a member's 60 calls a minute, so do not run one side twice within a minute) | `tools/platform-contract.sh test` or `parity` |
| Compare a report download from PHP and from the new API (xlsx: the same sheet names and every cell's kind and text; run after the membership and the classes `--prepare` of BOTH sides, membership first because its reset clears the classes fixtures; cases in `tools/export-parity.cases`, standard library only) | `tools/export-parity.sh` (or `tools/export-parity.sh <alias> "<path>?format=xlsx" [--unordered] [--filter COL:PREFIX] [--ignore COLS]`) |
| Build the static site (stack must be up) | `dotnet run --project hosts/site` (writes `build/site/`; `TSR_BASE_URL` picks the API) |
| Flutter: resolve the workspace | `flutter pub get` (once, at the root) |
| Flutter: analyze, test | `flutter analyze hosts/app shared/app domains/platform/app`, then `flutter test` inside each |

Never run `docker-compose.yml` (production) locally; this sample has only the dev file.

Required settings (the API does not start without them): `TSR_DB`, `TSR_FIREBASE_PROJECT_ID`, and `TSR_GOTENBERG_URL` (the Gotenberg container that renders PDF report downloads; the compose file sets it; production must too).

## Done means

The build has zero warnings, the tests you touched pass (and a new rule has a test that failed
first), the slice's Hurl contract files pass against the stack, and `flutter analyze` is clean.
