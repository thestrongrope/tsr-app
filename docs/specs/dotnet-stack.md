# tsr-app .NET stack (decided 2026-11-09)

Status: **complete, not yet built** (2026-11-09). Every library and tool choice is made; only the checks under
"To verify" remain. Evidence: `profile-bench/results.md` (C#, Go, Python, PHP),
`profile-bench/review.md`, `db-portability/mysql-to-postgres.md`.

Alternatives considered (languages, hosting, database hosting) and why they were turned down: `stack-research.md`.

Selection test (Asif): first-party Microsoft where it exists; a well-funded foundation or company
otherwise; our own small code where a library adds risk. Avoid libraries that went commercial
(MediatR, AutoMapper, FluentAssertions v8).

| Area | Choice | Backing | Why / notes |
|---|---|---|---|
| Runtime | .NET 10 LTS; move between LTS releases only | Microsoft | Supported to Nov 2028 |
| Web | ASP.NET Core **Minimal APIs**: route groups per module, endpoint filters, built-in OpenAPI | Microsoft | Already the sample's style; fastest stack in the benchmark |
| Compilation | JIT for the API, written **AOT-ready** (source-generated JSON, slim builder, no runtime reflection). NativeAOT only for small standalone workers. | Microsoft | AOT: fast start and small image, but about 85% throughput and EF Core AOT is experimental |
| Database | **PostgreSQL, moved before the new API** | | Strongest EF provider; MySQL EF options lag (Pomelo stops at EF 9). Estimated move: medium, 3-5 weeks (case-insensitive matching via `citext`/ICU, `mis.php`, zero dates) |
| Data access | **EF Core 10 + Npgsql**. Hand-written SQL via `SqlQuery<T>`/`FromSql`, LINQ where simpler, no tracking for queries | Microsoft / Npgsql | One DbContext and one Postgres schema per domain, so every table has one owner. EF used mainly as the mapper. |
| Migrations | **EF migrations**, all schema and base data (permissions catalog, role grants, lookups, synthetic dev data) in this public repo. Deployed as a migration bundle, run as a one-off Dokploy job before the app starts. | Microsoft | Review the idempotent SQL script in each PR. Expand-then-contract; never edit an applied migration. Explicit `InsertData`, not `HasData`. Baseline migration from the current schema. |
| Private repo | Member data and prod config only; never schema | | Secrets belong in Dokploy's secret store, not git |
| Hosting | **2 OVH servers + Dokploy Cloud**, Swarm with 1 manager and 1 worker; **self-hosted Postgres** on the manager | | Off-server backups, a tested restore, `unattended-upgrades`. Why not AKS or managed DBs: `stack-research.md` |
| Validation | .NET 10 built-in Minimal API validation for request shape, plus value objects returning `Result` for domain rules | Microsoft / ours | |
| CQRS | By convention, no library: one handler per slice, called by its endpoint; queries read with no tracking, commands use the DbContext | ours | |
| Mapping | Hand-written mapping to records | ours | |
| Errors | Shared `Result<T>` for expected failures; responses stay `{"detail": "..."}` (ProblemDetails only adds fields) | ours / Microsoft | Exceptions are for bugs only |
| AuthN | `JwtBearer` checking Firebase ID tokens against Google's published keys; no Firebase SDK | Microsoft | |
| AuthZ | The `access` domain (`Permissions.CanAsync`) plus scopes (gender, ...) | ours | |
| Logging | `Microsoft.Extensions.Logging`, JSON console, source-generated `LoggerMessage`, framework at **Warning** | Microsoft | Information-level logging measurably cost throughput. No PII in logs. |
| Telemetry | **OpenTelemetry** SDK → **OpenTelemetry Collector** on our server (removes or hashes PII) → **JSON files**, rotated, queried with **DuckDB** by agents. Move to ClickHouse if volume grows. No UI. | CNCF | Nothing leaves our server. Mobile keeps Firebase Analytics and Crashlytics. |
| Health | Built-in health checks (liveness, DB) | Microsoft | |
| Resilience | `Microsoft.Extensions.Http.Resilience` (Polly v8) for outbound HTTP; Npgsql retry-on-failure; built-in request-timeout and rate-limiting middleware | Microsoft | |
| Cache | `HybridCache`: in-memory, with **Redis** as the second level | Microsoft / Redis | |
| Events | Outbox table → `BackgroundService` relay → **Redis Streams** between domains (event streaming, not event sourcing) | ours / Redis | Temporal later, only if a durable fan-in is needed (account deletion) |
| Scheduling | `BackgroundService` + `PeriodicTimer` | Microsoft | |
| Tests | **NUnit** next to the code; `WebApplicationFactory` + Testcontainers (Postgres) for in-process API tests | NUnit (.NET Foundation) / Microsoft / Docker | NUnit's `Assert.That` replaces FluentAssertions. Convert the sample's xUnit tests in the first build story. |
| Contract tests | **Hurl** files in `domains/<ctx>/spec/tests`, run against any base URL | Orange | Language-neutral; replaces the C# contract project |
| E2E | Patrol (Flutter app), Playwright (static site) | LeanCode / Microsoft | |
| Load | k6 | Grafana Labs | |
| Quality gates | Nullable, `TreatWarningsAsErrors`, analyzers at `latest-recommended`, central package versions, module-boundary tests | Microsoft / ours | |
| Images | Chiseled ASP.NET runtime images | Microsoft | |

## AOT per host, persistence per domain (Asif, 2026-11-09)
- NativeAOT is decided **per host process**, not per module: every module in one host shares one binary.
- Domains are layered, and persistence is one layer of a domain, chosen per domain behind its module
  boundary. It is not a shared repository layer, so the "no repository layer" rule still holds.
  - **AOT-safe domains**: Npgsql plus hand-written or source-generated mapping, no EF. They can run in an
    **AOT host**: fast start, low RSS, small image. Good for small, hot or rarely used domains.
  - **Other domains**: EF Core as the mapper, in the **main JIT host**.
- Moving a domain between hosts is a wiring change (as in the plan's section 3.2). When EF Core's AOT support is
  stable (spike: EF 10 + Npgsql + `SqlQuery<T>` + compiled model + precompiled queries, after the
  Postgres move), the main host can switch to AOT too.
- At most two persistence patterns (EF for JIT domains, Npgsql with mapping for AOT domains), so agents
  have one convention per host type.

## Build pipeline: JIT in development, AOT in test and prod (Asif, 2026-11-09)
| Stage | Build | Why |
|---|---|---|
| Development | JIT: `dotnet run` / `dotnet watch`, seconds, hot reload | Fast feedback. AOT is never built locally (a macOS AOT link also fails; see E2). |
| Every build | AOT and trim **analyzers on**: `<PublishAot>true</PublishAot>` in the AOT host project, `<IsAotCompatible>true</IsAotCompatible>` in each domain library, `TreatWarningsAsErrors` | Most AOT problems (reflection, dynamic code, unannotated libraries) fail a normal JIT build, with no native compile |
| Merge to main → **Dokploy** | Dokploy builds the Docker image: NativeAOT `dotnet publish` in the Linux build stage (about 1 min), NUnit in a test stage (a failing test fails the build), then deploys to **test**. The **Hurl contract tests run against that deployed AOT image** before it is promoted. | Analyzers miss behaviour differences (seen in the spike: JSON `+` escaping, the `[AsParameters]` validation gap). The AOT image passing Hurl is the real gate. |
| Release builds → **GitHub Actions** | Security and quality analysis only: CodeQL, NuGet vulnerability audit, analyzers | GitHub Actions is not the deploy path (Asif) |
| Test, then prod | **Promote the same image**; never rebuild for prod | What was tested is what runs |

Rule: behaviour visible over HTTP needs a Hurl test (rule 8 of `domains/CLAUDE.md`). That is what catches AOT-only
differences the analyzers miss.

## Spike: AOT end to end (started 2026-11-09)
One route (`GET /me/permissions`) through the whole stack under NativeAOT: handler, JWT access token,
Npgsql query on Postgres, HybridCache + Redis, OpenTelemetry → Collector → files → DuckDB, logging,
resilience, NUnit and Hurl. Code and results are in `~/Projects/tsr-spikes/aot-e2e/` (outside this repo; `RESULTS.md`).

Outcome (2026-11-09): **works.**
- Hurl 12/12 against the AOT binary; NUnit 23/23. PII check on the telemetry files: 0 hits.
- Cache: misses then hits, keys in Redis.
- Image 38.6 MB, idle 23 MiB, restart to healthy 0.14-0.19 s, **first real request 9-15 ms**. The JIT C# stack's
  first request was about 160 ms, so AOT removes the warm-up cost.
- AOT warnings: 5, all from Microsoft's own first-party `Microsoft.Extensions.Caching.Hybrid` 10.11.0 (its default reflection-based JSON serializer; unused
  because the app registers a source-generated one). Under the zero-warnings rule this needs a narrow, documented
  suppression or an upstream fix.
- Clean under AOT: Npgsql (slim builder), JwtBearer/IdentityModel, OpenTelemetry OTLP, StackExchange.Redis,
  Polly, built-in validation.
- Built-in validation gaps: `[AsParameters]` header properties are not validated; `[MaxLength]` triggers an AOT
  warning. Validate direct parameters and value objects instead.
- Use a shared relaxed-escaping JSON setting: the default encoder escaped `+` in timestamps, unlike PHP.

## Further decisions (Asif, 2026-11-09)
| Area | Decision |
|---|---|
| MariaDB → Postgres move | `pgloader` for the one-off data move, rehearsed on a synthetic copy first. Backups: `pg_dump` plus off-server copies. No PgBouncer on a single host. |
| Strangler routing (PHP → .NET) | Keep **nginx**, proven in the spike. No YARP. |
| Primary keys (new tables) | `bigint` identity for internal tables; UUIDv7 (`Guid.CreateVersion7`) where an ID is exposed or made by the client |
| CI/CD | Dokploy builds, tests and deploys on merge to main; GitHub Actions for release builds only (CodeQL, NuGet audit). See "Build pipeline". iOS stays on Codemagic. |
| Flutter API client | Generated from the built-in OpenAPI document; the tool is picked in the first Flutter story |
| API versioning | No library. Changes are additive only (rule 7). |
| Search | **Keep Elasticsearch**: tsr-web, which already uses it, merges in. Official client `Elastic.Clients.Elasticsearch` (Elastic). It is **not AOT-supported** (maintainer statement and AOT failure reports on 8.x; its transport library is not AOT-ready), so `search` runs in the **JIT host**. |
| Push | **Firebase Cloud Messaging** (iOS through APNs, and Android, from one API), called **directly over HTTP**: `POST https://fcm.googleapis.com/v1/projects/{id}/messages:send` with a Bearer token. The token: sign a JWT with the service-account key (built-in `RSA`), exchange it at Google's token endpoint, cache it for about 1 h. About 50-80 lines, no SDK, **AOT-safe**; the standard resilience handler covers 429/5xx and timeouts. One request per device (FCM v1 has no multicast). Delete device tokens on `UNREGISTERED`/`INVALID_ARGUMENT`. |
| WhatsApp | **Stays TypeScript**, because of Baileys: a separate worker consuming `notifications` events from Redis Streams. One implementation per concern, in the language that earns it. |
| Report export: Excel | **ClosedXML** (MIT, on Microsoft's Open XML SDK) replaces PhpSpreadsheet. Keep `reportexport.php`'s rules: sheet names (31 characters, none of `[]:*?/\`) and **neutralise values starting with `=`** (formula injection). AOT status unverified, so it starts in the JIT host. |
| Report export: PDF | **Gotenberg** container (HTML → PDF with Chromium, over HTTP) replaces Dompdf. Same HTML-template model; shapes Urdu and Arabic correctly. One extra container (heavy image, a few hundred MB of RAM when busy). |
| Email | None: the app sends no email |
| File uploads | A mounted volume, or an S3-compatible container. Verify MinIO's 2025 community-edition changes before choosing it (alternatives: Garage, SeaweedFS). |
| Feature flags | Built-in configuration (`IOptions` on/off settings) first; Microsoft's `Microsoft.FeatureManagement` package (first party, not in-box) only for gradual or per-user rollout |

**Also decided** (Asif, 2026-11-09; revisit only if a domain needs something different):
- AI: **`Microsoft.Extensions.AI`** (the base layer: `IChatClient` and embeddings, any provider, e.g. OpenRouter or Azure)
  for simple calls. Add **Microsoft Agent Framework** (`Microsoft.Agents.AI`, the successor to Semantic Kernel and AutoGen,
  reported 1.0 GA in April 2026) only for agents with tools or workflows. Do not use Semantic Kernel (maintenance
  only). AOT status unverified, so AI features start in the JIT host.
- Localisation: translations as database content.
- Security: built-in headers, and CORS limited to the static site.
- Redis client: **StackExchange.Redis** (Microsoft's Redis cache package depends on it; AOT-clean in the spike).
- AOT warning policy: zero warnings, with **one allowed exception**: a narrow, commented suppression of the 5
  warnings from `Microsoft.Extensions.Caching.Hybrid` (its unused default serializer). Remove it when fixed upstream.

## To verify before building (from memory, not yet checked)
- ~~.NET 10 built-in Minimal API validation~~: confirmed by the AOT spike (gaps: `[AsParameters]` headers, `[MaxLength]` warns under AOT).
- The licence changes of MediatR, AutoMapper and FluentAssertions.
- MinIO's community-edition status, if S3 storage is chosen.
- How Dokploy runs Hurl after a deploy to test, and promotes the same image to prod.
- The JSON file exporter's settings and rotation in the OpenTelemetry Collector (contrib distribution).
