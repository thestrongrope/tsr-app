# tsr-app organization plan (2026-11-10)

How `tsr-app`, TSR's public monorepo, is designed and organized. This file is the lasting design.
Kept elsewhere, so each is read only when needed:

| For | Read |
|---|---|
| The rules for code in a domain | `domains/CLAUDE.md` (the one copy) |
| Language, database, libraries | `dotnet-stack.md` (wins on technology) |
| Getting from tsr-account to this layout: order of work, gateway rollout, migrations, folder moves | `repo-structure/migration-from-tsr-account.md` |
| What the spikes taught us (D1-D13) | `repo-structure/spike-learnings.md` |
| What exists today, and what is next | `docs/handover.md` |
| The plan before it was split | `repo-structure/full-2026-11-10.md` |

Out of scope: the other TSR tools (creative, hadith, translation, planner) and the private data repo.

**The sample in this repo began before the stack decision** on MariaDB, xUnit and C# contract tests; it now runs
on Postgres, EF Core, NUnit and Hurl contract files. It proves the layout, not the whole stack.

## Part 1: How we are designing the app

### What we are building

One product, three deliverables, one API. The Flutter app serves everything behind sign-in on every
device. The public site is static HTML, so it is indexable, shareable and searchable. Both read the
same data through the same API: the app at runtime, the site at build time.

```
 Flutter app                                         Public site
 (phone, tablet, desktop, web; XR as a window)       (static HTML, built from the API)
        │                                                   │
        └──────────────────► api. ── gateway ◄──────────────┘
                                       │
                     ┌─────────────────┴──────────────────┐
              new API: one module per domain          legacy PHP
              (vertical slices inside)                (shrinks slice by slice)
                     │
       PostgreSQL (system of record; MariaDB until the move) · Elasticsearch (search)
       Redis Streams (events, via outbox) · scheduler and workers consume the stream
```

### How it is designed

1. **Domain-first.** Each bounded context is one folder holding its whole stack: a
   language-neutral spec, one API implementation, the app screens and the site pages. A typical
   change touches one domain folder.
2. **One API, one database.** All domain modules run in one API process (a modular monolith). One
   PostgreSQL database, one schema per domain; each table is owned by one domain, except a few
   named platform tables (section 3.3).
3. **Vertical slices inside a domain.** One folder per use case (a command or a query), holding
   everything it needs. CQRS-lite falls out of this.
4. **Dependencies point inward, to the domain.** The domain knows nothing about the database, the
   API or Firebase. Infrastructure implements ports at external boundaries.
5. **Clients are presentation.** The Flutter app and the site hold no business rules.
6. **Hosts compose, they do not decide.** What ships (the API process, the app, the site) wires
   domains together and holds no rules.
7. **Shared stays small.** Only technical plumbing every domain needs, never a rule. Who is
   calling is `identity` (AuthN); what they may do is `access` (AuthZ), the one domain every
   other domain may depend on.
8. **Deployable per domain when needed.** Any domain's API can run in its own host and scale on
   its own, without moving code (section 3.2). Start with one host for all domains.

Lightweight DDD per `CODING-GUIDELINES.md`: ubiquitous language, module boundaries, value objects;
full tactical DDD only where a domain's complexity earns it.

### What it is not

- Not microservices now: one API process, one database, until a domain earns its own host.
- Not an API-management product: a plain reverse proxy is enough while the only clients are TSR's.
- No business rules in the app or the site, and no domain layer on the device.
- Not Unity: Flutter reaches every device, XR included as a flat window; an immersive XR
  experience would be a separate host on the same API.

## Part 2: The mid-level view

### 1. The repository

A folder is created with its first real file; nothing below exists until then. What exists today:
`docs/handover.md`. Where each folder comes from: the migration file.

```
tsr-app/
├── domains/<context>/            THE HEART: one folder per bounded context (list: section 4)
│   ├── CLAUDE.md                 what it owns, dependencies, events, status
│   ├── capabilities/             living docs: what each capability does today
│   ├── spec/                     defined once, language-neutral (section 2.3)
│   │   ├── glossary.md           ubiquitous language
│   │   ├── api.yaml              actions and field shapes (OpenAPI)
│   │   └── tests/                contract tests: HTTP only, any base URL
│   ├── api/                      the one implementation (C#, one project per domain)
│   │   ├── <Context>Module.cs    registration, routes, listed dependencies
│   │   ├── <Interface>.cs        what other domains may call (e.g. access's Permissions)
│   │   ├── features/<slice>/     one folder per use case, usually one file
│   │   ├── domain/               value objects and rules shared by its slices
│   │   └── tests/                the unit-test project (tests sit next to the code)
│   ├── app/                      Flutter package: its screens (lib/features/<screen>/)
│   ├── site/                     its public pages: Razor components + <Context>Site.PagesAsync
│   └── worker/ pipelines/ ...    only where a domain owns one (notifications: worker,
│                                 push-worker; content: pipelines; search: indexer, embeddings)
│
├── hosts/                        COMPOSE: what runs or ships (section 3.1)
│   ├── api/  gateway/  app/  site/
│   └── scheduler/  calendar/  media/     later
│
├── shared/                       PLUMBING only, never a rule
│   ├── api/                      db access, clock, outbox writer, request context
│   ├── app/                      design system, HTTP client, auth session plumbing
│   └── site/                     page description, build-time API reader
│
├── db/                           ONE DATABASE (section 3.3): migrations/, synthetic/
├── legacy/php/                   today's PHP, shrinking slice by slice (stays in tsr-account
│                                 until routes move)
├── docs/                         specs/ (research and spikes), templates/, dev/ (how-tos)
├── tools/  .claude/              dev tooling; agent skills (section 3.4)
└── root files                    pubspec.yaml (Dart workspace root), docker-compose.dev.yml,
                                  codemagic.yaml (must stay at the root), CLAUDE.md, AGENTS.md,
                                  README.md, CODING-GUIDELINES.md, licence and community files
```

Every domain leaves out the parts it does not need.

### 2. Inside a domain

#### 2.1 Layers

DDD's layers exist thinly, inside each slice, not as folders across the codebase.

```
Flutter app ──HTTP──► endpoint ──► handler ──► domain ◄── infrastructure
(presentation         (presentation (application) (rules)   (DB, FCM, WhatsApp, Firebase)
 for people)           for programs)
                      └──────── domains/<context>/api/ ────────┘   composed by hosts/api
```

| Layer | What it does | Where |
|---|---|---|
| Domain | Rules and invariants, value objects, domain events. Depends on nothing | `api/domain/` |
| Application | One use case: load, call the domain, save, publish through the outbox; owns the transaction; calls access's `can()` | the slice's handler, `api/features/<slice>/` |
| Presentation (API) | HTTP endpoint: parse the request, call the handler, shape the response per the contract | the slice's endpoint, same folder |
| Infrastructure | Implements the ports at external boundaries: the database, FCM, WhatsApp, Firebase, clock | data access in the slice; plumbing in `shared/api/`; the Firebase verifier in `domains/identity/api/` |
| Composition | Wires the layers together (startup, DI, middleware order) | `hosts/api/` |

A slice does its own data access, without a repository interface. How it reaches the database is
chosen per domain (`dotnet-stack.md`): EF Core in the main JIT host, or Npgsql with hand-written
mapping for a domain that must run in an AOT host. At most those two patterns.

**AuthN, AuthZ and domain rules are three different places.**

| Concern | Owner |
|---|---|
| Who is calling: token verification, uid → member, sign-in, the account and its deletion | `identity` (AuthN), wired as middleware by `hosts/api`. Owns the `users` table |
| What they may do and in which scope: roles, permissions, grants, scopes (gender, city, level), class-coordinator rules, `can()`, `GET /me/permissions` | `access` (AuthZ): a real domain with its own use cases and tables |
| Rules about a domain's own things: the teacher gender rule (gents may teach ladies' classes, not the reverse), "a class must be active" | the owning domain (`classes`), applied after `access` gives the scope |

- **`can()` is `access`'s public interface** (`domains/access/api/Permissions.cs`), not a slice
  and not a guard in `shared/`. Every member handler calls it, so `access` is the one dependency
  every domain lists. The database, not a token claim, decides authority.
- **Gender segregation splits cleanly:** which gender a member may see is a scope in `access`;
  each domain applies that scope to its own data.

#### 2.2 The app side and the site side

**App.** Flutter is presentation. Inside it, follow Flutter's official architecture guide:

| Flutter layer | Holds | In `domains/<context>/app/` |
|---|---|---|
| UI | Views and one view model per view: screen logic only (loading, form state, what is enabled) | yes |
| Data | Repositories: calls to that domain's API through `shared/app`'s HTTP client | yes |
| Domain (optional) | Use cases for complex logic on the device | **no: skipped** |

The domain lives on the server: permissions, gender segregation and class lifecycle are never
re-implemented on the device. Form checks may run on the device for a quick response; the API
always checks again. The repo root is the pub workspace root; `hosts/app`, `domains/*/app` and
`shared/app` are members, and `hosts/app` keeps the platform folders.

**Site.** Presentation too, built once per deploy. A domain with public pages adds `site/`: Razor
components that render what its public API returns, and one `<Context>Site.PagesAsync` that asks
the API and says which pages exist. What is public is decided by the domain's query (a public
read, rule 4 in `domains/CLAUDE.md`), so the site cannot show a draft by mistake.

#### 2.3 The spec: a domain defined once, implemented once at a time

| Defined once in `spec/` | Format | Used for |
|---|---|---|
| Ubiquitous language | `glossary.md` | names in code, tests and screens |
| Actions and field shapes | `api.yaml` (OpenAPI) | the published HTTP contract |
| Behaviour and invariants | `tests/`: contract tests against any base URL (Hurl, one file per slice) | proving any implementation obeys the rules |
| Events | a table in the domain's `CLAUDE.md`; `events.yaml` (AsyncAPI) once a relay and a consumer exist | the shape producers and consumers agree on |

- **Rules are proven by contract tests.** Types are not generated today: each client (the Flutter
  repository, a `site/` module) copies the shapes it reads.
- **One implementation per domain at a time.** During the move, PHP and the new API both pass the
  same contract tests, then PHP's version is deleted. Keeping the same rules in several languages
  would drift, and drift is where leaks come from.
- **A consumer is not a second implementation.** A worker that reacts to a domain's events uses
  its published events; it does not re-implement the domain.
- **The spec is the published language,** the shape clients see, not the domain model itself.

#### 2.4 Rules

The rules are in `domains/CLAUDE.md`, and only there. `hosts/api/tests` and `hosts/site/tests`
enforce the module boundaries; that file says which rules are review-only.

#### 2.5 Search: a read model fed by the event stream

`domains/search` owns no rules, only indexes. It consumes events from every domain and writes only
its own Elasticsearch indexes, so the owning domains do not know it exists.

1. **Permissions and gender segregation at query time.** Every indexed document carries its
   visibility fields. Every member query goes through access's `can()` and scopes. A test per role
   proves a ladies' class never reaches a gents admin, and the reverse.
2. **Public and member search are physically separate.** Site search reads a public index that
   holds only published content and no member data, so a filter bug there cannot leak a member.
3. **Rebuild without event sourcing.** Streams are trimmed, so each source domain exposes one bulk
   "export for index" query, listed as a read model, and the indexer rebuilds from those.
4. **Events carry what search needs,** so the indexer does not call back into the domains.

### 3. Around the domains

#### 3.1 `hosts/`: what runs or ships

- **`hosts/api`:** the one API process. Loads every domain's module from `Modules.cs` and wires
  middleware (identity's verifier first). Holds no rules; runs the module-boundary tests.
- **`hosts/gateway`:** an nginx reverse proxy for `api.` with its route table in the repo: every
  path goes to PHP by default, and a moved slice gets one line. It only forwards. Rollout and
  store-live safety: the migration file.
- **`hosts/app`:** the Flutter shell with the platform folders, built by Codemagic. The one client
  for every device.
- **`hosts/site`:** a .NET console program that renders Razor components to plain HTML, no
  JavaScript. `SiteModules.cs` lists each domain's `site/`. It reads the API, never the database;
  it owns the layout, home page and navigation; any API error stops the build
  (`site-spike/results.md`).
- **`hosts/scheduler`** (later): one process calling the same command handlers, replacing cron,
  and running the outbox relay.
- **`hosts/calendar`** (later): the calendar feed, a program with its own date logic and no member
  or class rules. **`hosts/media`** (later): the CDN config for `media.`.

#### 3.2 Deploying and scaling a domain on its own

A host chooses which domain modules it loads. Today `hosts/api` loads all of them: one process is
the cheapest to run and debug at TSR's size. When a domain needs its own deploy or scaling (for
example assessment during a Grand Quiz), a new host folder loads that module alone and the gateway
sends its paths there. No code moves; it is a production change, agreed first.

- Workers already run apart, and search queries can get their own host.
- The app does not split: the stores ship one binary.
- The database stays shared and is the real limit on scaling. Table ownership keeps a later split
  possible, but a domain with its own database is a much bigger step.
- What keeps it cheap: events first, listed dependencies, each module starting with only those.

#### 3.3 `shared/` and `db/`

- **`shared/`:** `shared/api`, `shared/app`, `shared/site`. If only two domains need something, it
  is not shared.
- **`db/`:** one database; ownership is per table. Platform-owned tables belong to no domain:
  the outbox, `outbound_messages`, `schema_migrations`, `admin_access_log`. Target: PostgreSQL with
  one schema and one DbContext per domain, and EF migrations holding all schema and base data in
  this public repo. The private repo keeps member data and prod config only.
- **How a database gets its data (decided 15 Nov 2026).** This repository sets up the database and nothing more:
  1. **Schema and base data: the migrations.** Rows the product cannot run without (`access.permissions`,
     `access.role_permissions`, `membership.interest_options`, `platform.lookups`) are created by the EF migrations,
     so a synthetic and a real database start the same.
  2. **Synthetic data: `db/synthetic/`**, public. It is all a contributor needs: every build, test and contract run
     works with it alone.
  3. **Real data: loaded separately**, by its owner, from outside this repository. `tools/data-load/` is the loading
     script; it holds no data and no connection details.

  The dependency runs one way: a real-data load depends on this repository's schema at a named version; nothing here
  depends on real data or on where it is kept.

#### 3.4 `tools/`, `.claude/` and `docs/`

- **`tools/`:** the contract builder, auth emulator, perf, scripts, security scanners, and
  `tools/ai/` for runnable AI dev tooling. AI inside the product (search embeddings) is product code.
- **`.claude/`:** agent and skill definitions. A skill about one domain lives in
  `domains/<context>/.claude/skills/`. A skill is written after a task has been done by hand twice.
- **`docs/`:** the lasting record of a feature is its **living capability document** in
  `domains/<context>/capabilities/`, rewritten by every PR that changes behaviour. The spec
  (GitHub issue) and the plan (draft PR description) stay on GitHub; there is no `plan.md` or
  `tasks.md` in the repo. `docs/specs/` is for research and spikes only.

### 4. The domains (draft)

`platform` is a holding area for small operational endpoints, not a true bounded context. What
each takes over from tsr-account: `domains/CLAUDE.md`.

| Domain | Covers |
|---|---|
| identity (AuthN) | sign-in, the account and its deletion |
| access (AuthZ) | `GET /me/permissions`; roles, grants, scopes, class-coordinator rules |
| membership | members, registrations, students, subscribers, join |
| classes | classes, levels, teacher training, syllabus, guides |
| assessment | MCQs, standard MCQs, quiz competitions |
| content | Quran, articles, lectures, books |
| notifications | notifications, devices, reminders |
| platform | app version, release notes, health, feedback, geo |
| search (read model) | member search and public site search (section 2.5) |

Not domains: `admin` is an audience (permissions decide it); `reports` are query slices owned by
the domain whose question they answer. `content` here is the API domain; the root `content/` folder holds its published text content (`content/README.md`), not the private data repo.

### 5. Why this layout, and what it costs

- **A change is local:** one domain folder holds its API slice, screen, page and spec. An agent or
  a contributor needs one folder of context.
- **Moving off PHP is slice by slice:** the gateway routes one path, which is one slice.
- **A domain can deploy and scale on its own** with a host and a gateway line.
- **Adding a use case is adding a folder.**

Costs: build files multiply (one per stack per domain, plus test projects); `hosts/api`, `hosts/app`
and `hosts/site` rebuild when any domain changes; moving today's folders needs production changes
(the migration file).

### 6. Open points

- The `can()` port's shape (spike-learnings D6): the sample's `CanAsync(caller, name)` has no target
  or scope, and gender segregation depends on scopes. Needs a slice with a scoped check.
- Account erasure across domains: no test and no spike.
- Parity with PHP: the contract tests have never run against the PHP route.
- When the sample moves to the decided stack (Postgres, EF or Npgsql, NUnit, Hurl), and whether EF
  migrations live with each domain's DbContext or together in `db/migrations`.
- `api.yaml`: generated from code or hand-written and checked (D2); generated or checked client types.
- Site: right-to-left pages, the sitemap and the search index; whether site search uses the API, a
  client-side index, or both.
- The domain list, its names, and whether `platform` stays.
- A signed store build from the pub workspace through Codemagic. Windows long paths under Gradle.
- AI tooling: move the TSR agents from `asifshakir/agents` into tsr-app or keep them there (each
  is read for quoted data before going public; `infra` may stay out); `AGENTS.md` replaces
  `copilot-instructions.md` and `.kiro/`.
- Brand public in `brand/` (recommended) or private. Where the other TSR tools go.
- Where the scheduler runs in production.
