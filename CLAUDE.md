# CLAUDE.md

`tsr-app`: The Strong Rope's monorepo, **domain-first**. One product, two delivery paths (a
Flutter app, a static public site), one API. The API is a C# rebuild of the PHP API in tsr-account and is checked
against it; it is not deployed yet. The full design is `docs/specs/repo-structure.md` (Part 1 is the one-page summary).

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
| The gateway of the dev and test stacks (per path: PHP or the new API; production has none) | `hosts/gateway/` | `default.conf` |
| The Flutter shell | `hosts/app/` | `lib/main.dart` |
| The static site generator | `hosts/site/` | `SiteModules.cs`, `Program.cs`; a domain's pages are in `domains/<context>/site/` |
| Plumbing every domain uses (DB, outbox, HTTP client, site API reader) | `shared/api/`, `shared/app/`, `shared/site/` | the file you need; no rules live here |
| A table or migration | the domain's `api/<Context>Context.cs` and `api/Migrations/` (add: `dotnet ef migrations add <Name> --context <Domain>Context --project domains/<d>/api --startup-project hosts/api --output-dir Migrations -- --TSR_DB=Host=unused --TSR_FIREBASE_PROJECT_ID=demo-design --environment=Production --migrate`; a converted domain's context is registered in migrate mode only, so `--migrate` is needed; the generated files need no edit) | `docs/specs/initial-build/phase-0-design.md` |
| The production stack and its settings | `docker-compose.yml` | `docs/deployment.md` |
| Synthetic data | `db/synthetic/seed.sql` | |
| The published articles, categories, publications page and fixed pages (`content/pages/`, shown only by the site) | `content/` (published only; copied by `tools/content-import.sh`, checked by `dotnet test domains/content/api/tests`) | `content/README.md` |
| How a database gets its data | migrations create the schema and base data; then the synthetic seed, or a separate load of real data | `docs/specs/repo-structure.md` section 3.3 |

The whole API surface is listed in the **route catalog**, `docs/specs/initial-build/operations.csv` (method, path, domain, auth kind, state); the tests in
`hosts/api/tests` fail when it and the code disagree. Which domain owns what: `domains/CLAUDE.md`. What is built and last measured: `docs/status.md`.
What the product does today and what is still missing: `docs/specs/capability-map/README.md`.

## Rules (the ones that must load without opening another file)

1. **Rules live in a domain, never in a client or a host.** Apps and the site are presentation;
   hosts only wire. A rule enforced only in the app is not enforced: the repo is public and anyone
   can build a modified client. Public content that only the site shows (the fixed pages) is read from `content/` at build time; content the app also reads, and anything with a rule or member data, still comes from the API.
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
   Error bodies are `{"detail": "..."}`. **The named exception:** the six public Library routes under `/api/v1/`
   (`domains/content`) keep the website's answer shape, `{success, data, meta, pagination}`, and its error shape,
   `{"success": false, "error": {"code", "message"}, "meta"}` (`domains/content/api/domain/V1.cs`), because supported app builds read it.
8. **Follow `CODING-GUIDELINES.md`.** Zero warnings: the .NET build treats warnings as errors;
   `flutter analyze` must be clean.

## Stacks: the rules that must not be broken

- **The dev stack (:8088) may hold REAL member data and device tokens.** Never run a contract script, a seed or a reset on it. Never name a sending worker
  (`push-drain`, `class-schedules`) on it: with FCM credentials it would push to real phones. Update it only with `tools/dev-stack.sh up`.
- **Hurl runs only against a synthetic stack**: the test stack (:8089) or a lane (`TSR_STACK=n`, 1 to 8, gateway `8100+n`).
- **Never run `docker-compose.yml` (production) locally with real settings.** It holds no secret, no published port, no seed and no emulator
  (`hosts/api/tests/ProductionStackTests.cs`); its services and settings: `docs/deployment.md`.
- The API does not start without `TSR_DB`, `TSR_FIREBASE_PROJECT_ID` and `TSR_GOTENBERG_URL`.

## Commands (from the repo root, Windows or Mac)

Every other command, each script's fixtures and the order of a full run: `docs/testing.md`.

| Task | Command |
|---|---|
| Build all .NET | `dotnet build TsrApp.slnx` |
| Unit and boundary tests (no database) | `dotnet test domains/<context>/api/tests` (content's is the guard over `content/`; the reader's tests are in `db/tests`), `dotnet test shared/api/tests`, `dotnet test hosts/api/tests`, `dotnet test hosts/site/tests` |
| Database tests (needs Docker) | `dotnet test db/tests` |
| Start the synthetic test stack | `tools/test-stack.sh up` (also `down`, `remove`, `status`) |
| A lane stack for a parallel worktree | `TSR_STACK=n tools/test-stack.sh up` |
| One domain's contract on the new API or on PHP | `tools/<domain>-contract.sh test` or `parity`; the lanes: `tools/contract-<lane>.sh test` or `parity` |
| Every Hurl file | the steps in `docs/testing.md` |
| Add a migration | the row "A table or migration" above |
| Build the static site (stack up) | `dotnet run --project hosts/site` |
| Flutter | `flutter pub get` once at the root; `flutter analyze hosts/app shared/app domains/platform/app`; `flutter test` inside each |

## Branches (gitflow, 15 Nov 2026)

| Branch | Holds | Changes arrive by |
|---|---|---|
| `main` | production: only what is released | a release PR from `develop`, then a version tag on `main` |
| `develop` (the default) | all finished work | a PR from a feature branch |
| `feature/<issue>-<slug>` | one user story | commits; cut from `develop`, deleted after its PR merges |

Both `main` and `develop` are protected on GitHub: a PR only, no force push, no deletion. Never commit to either directly.
Hotfix and `release/*` branches are not used until there is a production deployment.

## Done means

The build has zero warnings, the tests you touched pass (and a new rule has a test that failed
first), the slice's Hurl contract files pass against the stack, and `flutter analyze` is clean.

