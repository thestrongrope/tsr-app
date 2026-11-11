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
│   ├── features/<slice>/    one folder per use case, usually one file: <Slice>.cs
│   ├── domain/              value objects and rules shared by this domain's slices
│   └── tests/               only the test .csproj: it compiles every *.Tests.cs next to the
│                            code it tests (a second .csproj in api/ would clash with the first)
├── app/               Flutter package (pub workspace member): views, view models, repository
│   └── lib/features/<screen>/
└── site/              its pages on the static site (Razor class library): components and
                       <Context>Site.PagesAsync. Reads the API through shared/site; never
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
2. A domain uses another only through its listed public interface or its events, never its
   tables. Events first (the outbox): a direct call becomes a network call once domains run apart. List every dependency in `<Context>Module.Dependencies`; `access` is the usual one.
3. Commands write only this domain's tables. Cross-domain reads go through read models.
4. Every member handler: caller present (401) → `access` allows it (403) → validate (422) → act.
   A **public read** (no sign-in, e.g. `GET /articles`) skips the caller and `access` checks; its
   query must return only public data (e.g. only published articles), so no client or the site can
   show more by mistake. Mark it `security: []` in `api.yaml` and say why in the domain `CLAUDE.md`.
5. Expected failures are `Result<T>` (shared); exceptions are for bugs and infrastructure.
6. Interfaces only at external boundaries (DB, HTTP, FCM, Firebase). No repository layer.
7. Each domain module must start with only its listed dependencies; `hosts/api/tests` checks it.
   Each `site/` module references only `shared/site` and builds its pages alone; `hosts/site/tests`
   checks it. Both checks see real use of another module, not an unused project reference.
8. Tests sit next to the code (`Foo.Tests.cs`); behaviour visible over HTTP goes in a Hurl file in `spec/tests`, named after the slice.
9. Business rules never live in `site/` or `app/`: they render what the API returns. A `site/` module
   copies the response shapes it reads from `api.yaml` (it is a client of the published contract).
10. A cross-domain report is owned by the domain whose question it answers (e.g. the MIS report by
    `classes`), reads through read models only, and lists the domains it reads.
11. Account deletion is one command in `identity`; every domain owning member data handles its
    erasure event from the outbox (the privacy policy promises erasure). Not built or tested yet.
12. The change test: a typical business change touches one domain folder. If it keeps touching two,
    the boundary is wrong.

Enforced by tests: rule 7 (and with it the dependency part of rule 2), and the public surface: in each
`api/` library only the module class and the listed interface are `public`; slices, value objects and
plumbing are `internal`, so another domain cannot call a slice even when it lists the dependency
(`hosts/api/tests/PublicSurfaceTests.cs`; a new public type is added to its list). A domain's own unit
tests see its internals through `InternalsVisibleTo` in its `.csproj`. Everything else is review-only.

No skills yet: one is written after the same task has been done by hand twice (`add-slice` after slice 2). Until then, copy `platform/`.
