# CLAUDE.md

`tsr-app`: The Strong Rope's monorepo, **domain-first**. One product, two delivery paths (a
Flutter app, a static public site), one API. This copy is a **working sample**: one real slice
(`platform/submit-feedback`) runs end to end; the rest is structure. The full design is
`docs/specs/repo-structure.md` (Part 1 is the one-page summary).

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
`platform` · `search` (read model); only `identity`, `access`, `platform` and `content` (a stub)
have code. Which owns
what: `domains/CLAUDE.md`.

## Rules (the ones that must load without opening another file)

1. **Rules live in a domain, never in a client or a host.** Apps and the site are presentation;
   hosts only wire. A rule enforced only in the app is not enforced: the repo is public and anyone
   can build a modified client.
2. **Permissions go through `access`** (`Permissions.CanAsync(caller, action, target)`), checked in the slice's handler.
   **Gender segregation** is a scope from `access`, applied by each domain to its own data.
3. **A slice never calls another slice; a domain never reads another domain's tables.** Use the
   domain's listed public interface or its events. Dependencies are listed in
   `<Context>Module.Dependencies` and enforced by `hosts/api/tests` (`domains/CLAUDE.md` rule 7).
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
| Start the local stack (PostgreSQL, migrate, seed, API, gateway on :8088) | `docker compose -f docker-compose.dev.yml up -d --build` |
| Reset the local database | `docker compose -f docker-compose.dev.yml down -v` |
| Build all .NET | `dotnet build TsrApp.slnx` |
| Unit + boundary tests (no DB needed, NUnit) | `dotnet test domains/platform/api/tests`, `dotnet test hosts/api/tests`, `dotnet test hosts/site/tests` |
| Database-backed tests (needs Docker: Testcontainers starts a throwaway postgres:18) | `dotnet test db/tests` |
| Contract tests, every Hurl file (stack must be up; `tools/identity-contract.sh dev` first mints the token into `build/dev/token.vars` and refreshes the 2 hour fixture) | `hurl --test --glob "domains/*/spec/tests/*.hurl" --variable base_url=http://localhost:8088 --variables-file build/dev/token.vars --variables-file domains/identity/spec/tests/fixtures.vars --variables-file domains/access/spec/tests/fixtures.vars` |
| One implementation's contract (any base URL) | `tools/identity-contract.sh dev` or `... parity` runs the sign-in contract on either side. For another file, same command with another `base_url` and `--variables-file` (PHP: `build/parity-php/token.vars`, written by `tools/parity-php/mint-token.sh <.invalid email>`); `--glob` is expanded by Hurl itself, so it works in any shell on Mac and Windows when the pattern is quoted. Hurl must be installed. |
| Access contract on PHP or the new API (stack up; PHP: parity stack) | `tools/access-contract.sh dev` or `parity` (also `tools/identity-contract.sh`) |
| Platform contract on PHP or the new API (loads the geo rows from `db/synthetic/geo-fixtures.sql` into that side first; the three geo files spend about 35 of a member's 60 calls a minute, so do not run one side twice within a minute) | `tools/platform-contract.sh dev` or `parity` |
| Build the static site (stack must be up) | `dotnet run --project hosts/site` (writes `build/site/`; `TSR_BASE_URL` picks the API) |
| Flutter: resolve the workspace | `flutter pub get` (once, at the root) |
| Flutter: analyze, test | `flutter analyze hosts/app shared/app domains/platform/app`, then `flutter test` inside each |

Never run `docker-compose.yml` (production) locally; this sample has only the dev file.

## Done means

The build has zero warnings, the tests you touched pass (and a new rule has a test that failed
first), the slice's Hurl contract files pass against the stack, and `flutter analyze` is clean.
