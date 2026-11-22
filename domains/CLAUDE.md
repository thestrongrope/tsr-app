# domains/

One folder per bounded context, holding its whole stack. This is where every business rule lives.
A domain's code reaches people three ways: the API (`api/`, composed by `hosts/api`), the Flutter app
(`app/`, composed by `hosts/app`) and the static public site (`site/`, composed by `hosts/site`).

## Anatomy of a domain (copy `platform/`, the one complete example)

A domain folder, and each part inside it, is created with its first real file. Events are a table in
the domain's `CLAUDE.md` until a consumer exists; then they get a machine-readable spec.

```
domains/<context>/
├── CLAUDE.md          what it owns, its dependencies, its events, its status
├── capabilities/      LIVING DOCS: one <capability>.md per capability, describing TODAY
│                      (template: docs/templates/capability.md)
├── spec/              DEFINED ONCE, language-neutral; the published language
│   ├── glossary.md    ubiquitous language: use these words in code, tests and screens
│   ├── api.yaml       actions and field shapes (OpenAPI 3.1)
│   └── tests/         Hurl contract files, one per slice (`<slice>.hurl`): HTTP only, run against any base URL (`base_url`)
├── api/               THE ONE IMPLEMENTATION (C#, one project per domain)
│   ├── <Context>Module.cs   registration: Add<Context>(), Map<Context>(), Dependencies
│   ├── <Interface>.cs       what other domains may call (e.g. access's Permissions); not a slice
│   ├── <Context>Commands.cs published commands: the only way another domain writes here (rule 3)
│   ├── Migrations/          tables, and the published `v_*` views (a migration of its own, rule 2)
│   ├── features/<slice>/    one folder per use case, one file: <Slice>.cs = one static class (route, guards, SQL, response
│   │                        record; no handler class). Template: classes/api/features/class-levels/ClassLevels.cs
│   ├── domain/              helpers and rules used by two or more slices (a helper moves here on its second user, rule 6)
│   └── tests/               only the test .csproj: it compiles every *.Tests.cs next to the
│                            code it tests (a second .csproj in api/ would clash with the first)
├── app/               Flutter package (pub workspace member): views, view models, repository
│   └── lib/features/<screen>/
└── site/              its pages on the static site (Razor class library): components and
                       <Context>Site.PagesAsync. Reads the API through shared/site (public content that only
                       the site shows, the fixed pages, is read from content/ at build time); never
                       references api/ and never another domain's site/. Added to hosts/site/SiteModules.cs
```

`content/` has the one example of `site/` with a list and detail pages; `platform/site/` is a single page.

## Capabilities: the living documentation

A capability (e.g. Submit feedback, Enrol in a class) may span API slices and screens; its document lives in
its **owning domain**, and other domains link to it. It states what the capability does **today**:
requirements (EARS, IDs like `FEEDBACK-R1`), quality requirements, rules, interfaces, data and decisions
in force, each requirement linked to the test that proves it.

- **A PR that changes behaviour rewrites the capability document in the same PR**, to describe today.
  Never append history; git has it. Requirement IDs are never reused.
- The spec (GitHub issue) and the plan (draft PR description, with its verification plan) are change
  documents and are not kept in the repo. Workflow: the `spec-driven-development` skill.

## Which domain owns what

| Domain | Owns | Takes over from tsr-account (draft) |
|---|---|---|
| `identity` | AuthN: who is calling; the `users` row, sign-in, account deletion | `accountdeletion.php`, `api_authenticate()` |
| `access` | AuthZ: roles, permissions, grants, scopes (gender, city, level), class-coordinator rules, `can()` | `permissions.php`, `permissiongrants.php`, `classaccess.php`, `entityaccess.php` |
| `membership` | members' profiles, registrations, students, subscribers, guardians, joining | `registrations.php`, `students.php`, `subscribers.php`, `guardians.php` |
| `classes` | classes, levels, enrolment, sessions, teacher training, syllabus, guides, the MIS report | `classes.php`, `classstudents.php`, `sessions.php`, `syllabus.php`, `guides.php`, `teachers.php`, `training.php`, `thisweek.php`, `mis.php` |
| `assessment` | MCQs, standard MCQs, quiz competitions (Grand, Mega) | `mcq.php`, `mcqsheet.php`, `quizadmin.php` |
| `content` | Quran, recitation, articles, lectures, books; content pipelines | `holyquran.php`, `quranrecitation.php` |
| `notifications` | push, WhatsApp, reminders, devices, campaigns; their workers | `devices.php`, `mobilenotifications.php`, `classnotifications.php`, `classschedulednotification*.php`, `whatsappreminders.php`, `reminderschedule.php`, `pendingnudge.php`, `campaigns.php` |
| `platform` | app version, release notes, health, feedback, geo, lookups, audit log | `feedback.php`, `lookups.php`, `location.php`, `auditlog.php`, `reportexport.php` |
| `search` | read model only: indexes fed by events; global and public search | `search*.php` |

Platform-owned tables (no domain): `outbox`, `outbound_messages` (PHP's `schema_migrations` is replaced by EF's history tables),
`admin_access_log`.

## Rules for code in domains/

1. A slice never calls another slice. Shared rules go to `domain/` once two slices need them.
2. **The database is the integration surface for reads (D1).** A domain publishes views `v_*` in its own schema, created by its own
   migration; another domain's SQL may join those views and nothing else of that domain (`platform.outbox` aside). Permissions
   still go through `access` in C#. Other uses go through the listed public interface or events. A view is a contract: change
   one with its readers. List every dependency in `<Context>Module.Dependencies`. `hosts/api/tests/SqlBoundaryTests.cs` scans every domain's, `shared/` and `hosts/` SQL literals (quoted names too). It cannot see a name built from variables: review that.
3. Commands write only this domain's tables. A cross-domain write is a published command of the owner (D2): a public static method
   in the owning domain. There are two kinds, and no command takes an Entity Framework type (`hosts/api/tests/PublishedCommandTests.cs` checks every public method):
   a command that writes as part of the caller's change runs on the caller's transaction and takes the caller's `DbTx` (e.g. `MembershipCommands.RecordAcceptedRegistrationAsync(tx, ...)`). A converted caller passes its own `DbTx`. A caller still on Entity Framework passes `EfTransaction.Join(db)`, which throws unless `db` has an open transaction; a project with the AOT analyzer on cannot call it (build error IL2026).
   A command whose contract is to commit at once takes no transaction. The admin audit row, `PlatformCommands.RecordAdminAccessAsync(context, ...)`, takes the `HttpContext` and finds the `NpgsqlDataSource` in its request services. The five queue commands of `PlatformCommands.Queue.cs` (the claim and the four results) take the `NpgsqlDataSource`. Each statement runs on its own pooled connection and commits at once. A caller must not call these inside its own transaction.
4. Every member handler: caller present (401) → `access` allows it (403) → validate (422) → act.
   A **public read** (no sign-in, e.g. `GET /articles`) skips the caller and `access` checks; its
   query must return only public data (e.g. only published articles), so no client or the site can
   show more by mistake. Mark it `security: []` in `api.yaml` and say why in the domain `CLAUDE.md`.
5. Expected failures are `Result<T>` (shared); exceptions are for bugs and infrastructure.
6. Interfaces only at external boundaries (DB, HTTP, FCM, Firebase). No repository layer, no handler class, no mapping layer (D3).
   A helper moves to `domain/` only when two slices use it; the PHP-emulation helpers (`PhpValue`, `PhpText`, `JsonBody`) are in `shared/api` (D4).
   PHP is the oracle (D6): a slice is done when its Hurl file passes on PHP and on the new API.
   **An unconverted domain** reads with `SqlQuery<T>` and writes with EF entities or `ExecuteSql`, as before; its published commands that run on a `DbTx` (rule 3) use the shared helpers below even while the rest of the domain is unconverted.
   **A converted domain** uses no Entity Framework at run time. Its context and migrations stay (the schema is still made by them); the context is registered
   for the migrate job only: the module has an `Add<Context>Migrations()` (access: `AddAccessMigrations`, marked JIT only) and `hosts/api/HostServices.cs` calls it in `RunMode.Migrate` just before `Add<Context>()`, so the migration order is unchanged.
   `hosts/api/tests/RunTimeEfUseTests.cs` fails on any Entity Framework or `AccessContext` name in access's run-time files (the one allowed line is that registration). Its file names and banned context name are written for access alone: the next converted domain must extend them, not only its domain list.
   A read route that needs a port or an uncached `Permissions` read after its own reads opens a short transaction for them and disposes it first: no code path holds two connections of the data source at once, so no number of requests can starve the pool by waiting on itself. (`Permissions.CanAsync` for the caller `RequireAsync` already resolved opens none, so a guard may call it inside the transaction; `db/tests/AccessPoolTests.cs` runs every access route on a pool of one and fails if a path needs two.)
   A helper that runs both in a write transaction and on its own takes the `DbTx`; a read route passes its short transaction.
   SQL is an interpolated string given to `Sql` (`shared/api/Sql.cs`), never built by hand and never a `$$"` string.
   No raw `NpgsqlCommand` and no `*Raw` call outside `shared/api/Db.cs`; `SqlHandlerUseTests` lists the few files that still have one.
   It runs on an `NpgsqlDataSource` or a `DbTx` (`Db.cs`, `DbTx.cs`) and reads rows by column name with `DbRow`;
   `ScalarAsync` is for value types only. An event goes through the `Outbox.WriteAsync` overload that takes the domain's `<Context>Json`
   (a source-generated context in `domain/`). An answer serialized from a value goes through `Results.Json(value, <Context>Json.Answers.<Type>)`: a second instance of the context built on the host's JSON options (web defaults and the relaxed encoder, so `+` and non-ASCII text stay as written); events use `<Context>Json.Default`, which is what the outbox always wrote. Access is the pattern (`domains/access/api/domain/AccessJson.cs`). Every runtime type behind an `object` field is registered in the context. An answer a domain writes by hand (content's `V1` with `Utf8JsonWriter`) does not need it.
   The unit test project of a converted domain sets `<JsonSerializerIsReflectionEnabledByDefault>false</JsonSerializerIsReflectionEnabledByDefault>`, so a serialization that would need reflection fails there as it would in a native build; `AccessJson.Tests.cs` writes each answer type that way.
   A test of a converted query must return at least one row: `DbRow` checks the row's shape on the first row, so a `ListAsync` with no rows checks nothing.
   A handler keeps its declared parameters and the project sets `<EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>`.
   A text value compared with a citext column still needs `::citext` (a LINQ comparison that became SQL gets it too: `{permission}::citext` in access); a select of one needs no `::text`.
   The project sets `IsAotCompatible` and is added to the list in `hosts/api/tests/AotAnalyzerTests.cs`.
7. Each domain module must start with only its listed dependencies; `hosts/api/tests` checks it.
   Each `site/` module references only `shared/site` and builds its pages alone; `hosts/site/tests`
   checks it. Both checks see real use of another module, not an unused project reference.
8. Tests sit next to the code (`Foo.Tests.cs`); behaviour visible over HTTP goes in a Hurl file in `spec/tests`, named after the slice.
9. Business rules never live in `site/` or `app/`: they render what the API returns. Public content that only the site shows (the fixed pages, and the lecture library until lecture search, issue 22, is built: `content/lectures/lectures.ndjson`) is read from `content/` at build time; content the app also reads, and anything with a rule or member data, still comes from the API. A `site/` module
   copies the response shapes it reads from `api.yaml` (it is a client of the published contract).
10. A cross-domain report is owned by the domain whose question it answers (e.g. the MIS report by
    `classes`), reads other domains through their `v_*` views only, and lists the domains it reads.
11. Account deletion is one command in `identity`; every domain owning member data handles its
    erasure event from the outbox (the privacy policy promises erasure). Not built or tested yet.
12. The change test: a typical business change touches one domain folder. If it keeps touching two,
    the boundary is wrong.

Enforced by tests: rule 7 (the dependency part), rule 2's SQL boundary (`SqlBoundaryTests`), and the public surface: in each
`api/` library only the module class and the listed interface are `public`; slices, value objects and
plumbing are `internal`, so another domain cannot call a slice even when it lists the dependency
(`hosts/api/tests/PublicSurfaceTests.cs`; a new public type is added to its list). A domain's own unit
tests see its internals through `InternalsVisibleTo` in its `.csproj`. Everything else is review-only.

No skills yet: one is written after the same task has been done by hand twice (`add-slice` after slice 2). Until then, copy `platform/`.
