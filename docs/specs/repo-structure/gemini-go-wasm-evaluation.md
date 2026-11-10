# Evaluation: Gemini "Go + wazero + WasmEdge" blueprint, and serverless/durable workflows for TSR (2026-11-09)

Planning note, not a decision. Inputs: the Gemini blueprint ("Agentic AI Architecture Plan:
Enterprise Go, wazero, and WasmEdge"), Gemini's Go vs C# vs Java comparison, and the TSR plan
(`docs/specs/repo-structure.md` = RS, `tsr-account/docs/specs/target-architecture/plan.md` = TA),
the spike (`docs/handover.md`), `CLAUDE.md`, `domains/CLAUDE.md`.

Asif's actual question (reframed 2026-11-09): a "domain service" idea where each domain scales on
demand, with a self-hosted equivalent of Azure Functions (scale-to-zero, HTTP and event triggers)
and Durable Functions (durable orchestrations, timers, retries, fan-out/fan-in), on Docker Swarm on
self-hosted VMs.

## Recommendation

- **Keep C#/ASP.NET Core.** Nothing in the serverless or durable-workflow space needs Go or wazero;
  the two strongest self-hostable durable engines (Temporal, Dapr Workflow) have first-class .NET SDKs.
- **Do not build scale-to-zero on Swarm.** Swarm has no autoscaler, and the scale-on-demand
  frameworks (Knative, KEDA, OpenFaaS, Fission, SpinKube) are Kubernetes-only or have dropped Swarm.
  TSR's load does not need it: RS 3.2 already answers bursts (e.g. a Grand Quiz) with a separate
  host for one domain, no code moved.
- **Durable workflows: start with what the plan already has** (outbox, Redis Streams consumer
  groups, `hosts/scheduler`, workers). Adopt Temporal only if a real multi-step orchestration
  appears that the outbox cannot express cleanly. Account deletion's erasure fan-out is the one
  candidate today.
- **Swarm itself is not in the plan.** RS and TA describe one Dokploy server with
  `docker-compose.yml`. "Swarm on self-hosted VMs" is a new production decision; ask Asif.

## 1. Serverless and durable workflows on self-hosted Swarm

### 1.1 Candidates

| Option | What it gives | Runs on Swarm / plain Docker? | Durable Functions semantics? | SDKs (C#, Go) | Storage it adds |
|---|---|---|---|---|---|
| Knative | Scale-to-zero HTTP/events | **No**, Kubernetes only | No | n/a | k8s |
| KEDA | Event-driven autoscaling | **No**, Kubernetes only | No | n/a | k8s |
| OpenFaaS | Functions, HTTP/async | **Swarm deprecated**: faas-swarm archived, community support ended Dec 2020. faasd runs on one host (containerd, no clustering); scale-to-zero is a Pro/k8s feature, to my knowledge | No | Templates for both | none |
| Fission | Functions | **No**, Kubernetes only | No | n/a | k8s |
| Azure Functions host in a container | Same programming model, HTTP triggers, timers | **Yes as a container**; scaling is yours (KEDA, i.e. k8s, is the only documented autoscaler) | **Yes**, Durable Functions with the MSSQL provider runs without Azure ("disconnected environments are supported") | C# first-class; Go only via custom handlers | **SQL Server** (a second database engine beside MariaDB) |
| Dapr Workflow | Durable orchestrations on Dapr actors | **Yes**, self-hosted mode (sidecar per app + placement/scheduler services); Dapr does not scale anything itself | **Yes**: activities, timers, retries, fan-out/fan-in, external events, child workflows | .NET and Go SDKs exist | Any actor-capable state store; the MySQL/MariaDB store has an `actorStateStore` flag (that it backs Workflow on MariaDB is inferred, not documented) |
| Temporal | Durable execution, the reference product | **Yes**: server is containers (compose works); dev server is one binary | **Yes**, the closest match and most mature | .NET and Go (also Java, TS, Python, PHP, Ruby), from my knowledge, not re-checked today | **MySQL 8 or Postgres**; MariaDB not supported (community reports JSON differences). Optional Elasticsearch for advanced visibility |
| Restate | Durable execution, single binary | **Yes** | **Yes** | Go official; **.NET only a community alpha** (Restate.Sdk 0.1.0-alpha.5) | Own embedded log |
| Inngest (self-hosted, 1.0+) | Event-driven durable steps | **Yes** | Mostly (steps, sleep, retries, fan-out) | TS, Python, Go; .NET on the roadmap, not shipped | Postgres + Redis (to my knowledge) |
| Hatchet | Durable task queue/workflows | **Yes** | Mostly | Python, TS, Go, Ruby; no .NET | Postgres |
| DBOS | Durable workflows as a library | Library, so yes | Yes | Python, TS, Go, Java (some preview); no .NET found | **Postgres only** |
| wasmCloud, Spin/Fermyon | Wasm functions | wasmCloud: hosts anywhere over NATS; Spin at scale = SpinKube (k8s) | No | Wasm guests | NATS etc. |
| In-process .NET options (MassTransit sagas, Wolverine, Hangfire, Elsa) | Retries, sagas, scheduled jobs inside the API/worker | Yes, no new service | Partial (sagas/timeouts, not replay-based orchestration) | C# | MariaDB via EF or community storage (not re-checked) |

### 1.2 Does TSR need scale-on-demand?

No evidence it does. RS 3.2: "one process on one Dokploy server is the cheapest to run and debug
at TSR's size"; split a domain "only under pressure". The known peak is a quiz competition; the
plan already lets `assessment` run in its own host behind the gateway. Scale-to-zero saves money
on pay-per-use clouds; on owned VMs an idle container costs a few tens of MB of RAM, so it saves
almost nothing. Its cost is real: cold starts on the first request (bad for a store-live mobile
app), an autoscaler to run and debug, and on Swarm, one you would have to write. Not checked: the
deploy server's RAM and today's peak request rate; that is the evidence to gather first.

### 1.3 Does the plan already cover the durable-workflow needs?

| Durable Functions feature | Plan's equivalent | Gap |
|---|---|---|
| Reliable trigger from a state change | Outbox row in the same transaction, relayed to Redis Streams (TA, RS 2.4 rule 2) | none |
| Retries, at-least-once | Consumer groups: unacked entries stay pending and are reclaimed (XPENDING/XCLAIM) | dead-letter policy and idempotent handlers must be written |
| Timers / schedules | `hosts/scheduler` calls command handlers; cron jobs move there (RS Part 1 "How it evolves") | durable per-instance timers (e.g. "remind this student in 3 days") need a due-time table the scheduler polls |
| Fan-out | One event, many consumers (search indexer, push, WhatsApp) | none |
| Fan-in / "all done" | Not stated | **Account deletion** (RS 2.4 rule 10): every owning domain must erase; knowing "all domains finished" needs a completion record per domain. This is the one place a workflow engine would earn its keep |
| Long-running orchestration with compensation | Not needed by any listed use case | none today |

So the plan covers triggers, retries, schedules and fan-out. Fan-in for erasure is a small table
plus a check, not a platform.

### 1.4 Does any of this change the language choice?

No. Temporal and Dapr Workflow have .NET SDKs; Azure Durable Functions is C#-first. Go would only
be favoured if Restate, Inngest, Hatchet or DBOS were chosen, and none of them is needed. wazero
and WasmEdge play no part in durable workflows or scaling.

### 1.5 Smallest spike that would settle it

Only if Asif wants to decide now (about one day, local only, nothing in prod):
1. **Measure first (an hour, read-only):** peak requests per minute and memory on the prod server
   during the last quiz, from Traefik/Dokploy logs. If peaks fit one server with headroom,
   scale-on-demand is settled as "not needed".
2. **Model account deletion two ways**, on the spike's dev compose: (a) outbox + Redis Streams +
   a per-domain completion row, in C#; (b) the same flow as a Temporal workflow with the .NET SDK
   against Temporal's dev server. Compare lines of code, what an agent has to understand, the new
   services to run (Temporal adds a server plus MySQL 8 or Postgres, since it does not support
   MariaDB), and how a failure is seen and retried.
If (b) is not clearly simpler, stay with the plan.

## 2. Fit of the original blueprint (shortened)

The blueprint is about running **untrusted, LLM-generated code** at **500-12,000 instances per
host** on Swarm with WasmEdge and WASI-NN. TSR has none of these needs: no runtime LLM or plugin
feature (AI use is dev tooling, RS 3.4), no density pressure (RS 3.2), no GPU inference (the only
ML piece is the Python embeddings build [9]), and prod is compose on one Dokploy server, not
Swarm. The old RunCloud host ran Swarm (`imantix-infra/connection_details.md`), but that is legacy.

## 3. What transfers anyway

| Idea | Verdict |
|---|---|
| govulncheck-style gate | Yes, C# form: NuGet audit already fails the build on old pins (handover "Traps"); make `NuGetAuditMode=all` and lock files in locked mode explicit in CI. |
| Dependency minimalism | Already true: one runtime package (MySqlConnector 2.6.2), central pins. Keep "a new package needs a reason". |
| Small, shell-less images | Cheap: try the chiseled ASP.NET image when `hosts/api` goes to prod; the healthcheck must not need a shell. |
| NativeAOT | Not now. Saves tens of MB on one server; costs `CreateSlimBuilder`, JSON source generation, no MVC, a second build mode to test. Revisit on measured memory pressure. |
| Go for workers | Already allowed (TA line 30) and already present (`tsr-migrate`). Do not grow it: default new workers to C# `BackgroundService` so they share outbox types, `Result<T>`, analyzers and the boundary test. |
| wazero, WasmEdge, Swarm | No. Docker Desktop's Wasm workloads are deprecated and "no longer actively maintained". |

## 4. Claims checked (shortened)

| Claim | Status | Evidence |
|---|---|---|
| Container cold start 1,500-10,000 ms | Overstated | True for JVM/large Python images; small native binaries start in tens of ms. Not measured here. |
| 128-512 MB per container, 1-5 MB per Wasm instance, 48x density | Unsupported | No benchmark cited. Thinktecture: ASP.NET Core NativeAOT ~17-23 MB, CoreCLR >50 MB (.NET 8). A Go `wasip1` guest carries the Go runtime and is several MB itself. |
| Gemini's CoreCLR 80-150 MB | Stale/high | See above; .NET 9 enabled DATAS by default, lowering Server GC memory. |
| Go / NativeAOT RSS 10-25 / 20-45 MB | Plausible | Consistent with Thinktecture. |
| "Production-ready" Go code | Wrong | Does not compile (`fmt.fmtErrorf`); `WithSysWalltime(time.Now(), 0)` does not match wazero's API, and the real clock contradicts its "timing side-channel" comment; `safeBuffer` has no lock; recompiles per call; Go guests need `//go:wasmexport` (Go 1.24+). |
| Swarm compose file | Wrong | `image_type` is not a compose key; `version` is obsolete; `CGO_ENABLED=0` as a runtime env var does nothing; Swarm does not pick a per-service Wasm runtime (to my knowledge). |
| C# Wasm embedding weak | Partly stale | `wasmtime-dotnet` is not archived; NuGet `Wasmtime` 44.0.0 (May 2026) seen on an aggregator. Needs a native library. |
| NativeAOT for ASP.NET Core + MySqlConnector | Partial | Docs (10.0): Minimal APIs partial, MVC not supported, JWT auth supported. MySqlConnector added AOT/trimming support in 2.5.0; an open trim warning (#1607) may need a suppression. The spike has not been AOT-published: not verified. |
| C# wins on Semantic Kernel | True, irrelevant | No runtime agents planned. |

## 5. Questions for Asif

1. What was the Gemini blueprint written for: imantix, a separate agent platform, or TSR? It
   describes a multi-tenant platform running LLM-written tools, not TSR.
2. Is Swarm on several self-hosted VMs a real plan for TSR? Today's plan is one Dokploy server
   with compose. Which load or failure would the extra VMs answer?
3. Which TSR flow needs a durable workflow that the outbox and scheduler cannot do? (Account
   deletion's fan-in is the only one found.)

## Sources

- OpenFaaS Swarm deprecation: https://awesome.ecosyste.ms/projects/github.com%2Fopenfaas%2Ffaas-swarm , https://www.openfaas.com/blog/introducing-faasd/
- Durable Functions storage providers (MSSQL, disconnected): https://learn.microsoft.com/azure/durable-task/common/durable-task-storage-providers , https://learn.microsoft.com/azure/azure-functions/durable/choose-orchestration-framework
- Dapr: https://docs.dapr.io/developing-applications/building-blocks/workflow/workflow-architecture , https://docs.dapr.io/reference/components-reference/supported-state-stores/setup-mysql
- Temporal persistence: https://docs.temporal.io/temporal-service/persistence , MariaDB thread: https://community.temporal.io/t/can-we-use-mariadb-for-temporal/10955
- Restate: https://docs.restate.dev/docs/ , community .NET SDK: https://www.nuget.org/packages/Restate.Sdk
- Inngest self-hosting: https://www.inngest.com/docs/self-hosting , roadmap: https://roadmap.inngest.com
- Hatchet: https://docs.hatchet.run/llms/reference.md ; DBOS: https://docs.dbos.dev/explanations/portable-workflows
- ASP.NET Core Native AOT: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/native-aot
- MySqlConnector AOT: https://github.com/mysql-net/MySqlConnector/issues/1265 , https://github.com/mysql-net/MySqlConnector/issues/1607
- Docker Wasm workloads (deprecated): https://docs.docker.com/desktop/features/wasm/
- wasmtime-dotnet: https://bytecodealliance.org/projects
- .NET memory: https://www.thinktecture.com/?p=20991 , https://devblogs.microsoft.com/dotnet/preparing-for-dotnet-10-gc/

Not verified: Temporal's SDK list (from memory), Dapr Workflow on a MariaDB actor store, OpenFaaS
faasd scale-to-zero terms, Inngest's storage, .NET in-process options' MariaDB storage, container
start times, the prod server's RAM and peak load, the spike's AOT readiness.
