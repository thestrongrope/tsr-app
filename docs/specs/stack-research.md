# Stack research: alternatives considered (2026-11-09/10)

Why the choices in `dotnet-stack.md` were made, and what was turned down. Read this before reopening a decision.
Prices are approximate (from memory or the vendor's page on that date). Benchmarks ran on one Mac (OrbStack),
with 2 CPUs and 512 MB per stack and synthetic data. Details: `profile-bench/results.md`.

## 1. Language and framework: equivalent stacks

| Concern | **C# (chosen)** | Go | Python | TypeScript | Modern PHP |
|---|---|---|---|---|---|
| Web | Minimal APIs | net/http, Chi | FastAPI | Fastify/Hono/NestJS | Laravel/Symfony on FrankenPHP |
| Data + mapper | EF Core + Npgsql | pgx + sqlc | SQLAlchemy/asyncpg | Drizzle/Kysely/Prisma | Eloquent/Doctrine |
| Migrations | EF migrations | goose/atlas | Alembic | Drizzle Kit/Prisma | built in |
| Validation | built-in + value objects | validator | Pydantic | Zod | built in |
| Jobs and outbox | BackgroundService | goroutines | Celery/arq | BullMQ | Laravel queues |
| Tests | NUnit | testing | pytest | Vitest | Pest/PHPUnit |
| Contract tests | Hurl (same for all) | Hurl | Hurl | Hurl | Hurl |
| First-party coverage | **highest (Microsoft)** | good stdlib, rest community | mostly community | community, npm supply-chain risk | high within one framework |
| Fit for DDD and vertical slices | strong | more hand-built code | weaker typing | NestJS good | Symfony good |

### Measured (`/me`, req/s at 10 / 50 VUs, 1-3 reps)
| Stack | 10 VUs | 50 VUs | Idle RSS | Image | First request after restart |
|---|---|---|---|---|---|
| **C# raw (Warning logging)** | 2,165 | **2,893** | 15 MiB | 133 MB | ~160 ms JIT |
| **C# NativeAOT** (file-based / AOT slice) | 1,891 | 2,441 | 9.5-23 MiB | 29-38 MB | **9-15 ms** |
| C# EF Core (Oracle MySQL provider) | 1,298 | 1,713 | 15 MiB | 147 MB | - |
| Go, 4 microservices | 2,250 | 2,050 | 6 MiB total | 9 MB each | ~11 ms |
| Go monolith | not load-tested | - | 2.6 MiB | 9 MB | - |
| Python (FastAPI, 2 workers) | 1,340 | 1,460 | 103 MiB | 216 MB | ~32 ms |
| PHP FrankenPHP worker | 1,479 | 1,468 | 228 MiB | 1.7 GB | ~0.7 s to ready |
| PHP FrankenPHP classic | 1,109 | 443 (840-915 tuned) | 29 MiB | 1.7 GB | ~0.5 s to ready |
| PHP Apache (today) | 582 | 263* | 13 MiB | 992 MB | ~66 ms |

*Port-limited, see section 4.

### Why C#
Throughput is level with or ahead of Go. It has the widest first-party coverage, Asif knows it, and it fits DDD and
vertical slices. AOT removes the cold-start cost.
- **Go:** the WASI reason did not hold (Swarm cannot scale to zero; wazero raised memory to C#'s level), and it needs more code.
- **Python:** about half the throughput, the most memory, weaker typing; free-threaded is still young.
- **TypeScript:** no code to share with a Flutter frontend; npm supply-chain risk. It stays only for the WhatsApp worker (Baileys).
- **Modern PHP:** about 5× today's Apache and level with Python, but about half of C#. Worker mode needed 5 changes to
  legacy code (exit/die, persistent PDO, static permissions model, bootstrap state, shutdown hooks) and uses 228 MiB idle.

## 2. Hosting
| Option | ~ per month | Notes |
|---|---|---|
| **OVH server + Dokploy (chosen)** | **~$40** | Probably more CPU and RAM than 2 AKS nodes; the whole stack fits |
| AKS, all in cluster | ~$180-220 | 2 × D2s_v5, disks, load balancer; control plane free tier. Keep Container Insights off (billed per GB). |
| AKS + managed Postgres and Redis | ~$200-270 | |
| Azure Container Apps | low when idle | Scales to zero, but the databases still need always-on homes |

Plan: 2 OVH servers, managed from Dokploy Cloud. Swarm with **1 manager and 1 worker**, databases on the manager.
`unattended-upgrades` on both servers for OS patches (Dokploy deploys apps; it is not assumed to patch the OS).
Patch by draining a node; the databases have a short quiet-hour window. 2 managers would lose Swarm's majority on a reboot.

## 3. Database hosting
Rule: the database must sit **in the same data centre** as the app. `/me/permissions` runs 11 queries, so each
1-5 ms of distance adds 10-50 ms per request.

| Option | ~ per month | High availability | Verdict |
|---|---|---|---|
| **Self-hosted Postgres on OVH (chosen)** | ~$0 + backup storage | Manual (standby later) | Chosen |
| OVH Essential DB1-4 / Discovery B3-4 (1 node) | ~₹5,500 + GST (~$65) | No | Managed backups and patching only |
| OVH Business DB1-4 (2 nodes) | ~₹14,000 + GST (~$165) | Yes | Only if downtime really hurts |
| OVH Production B3-8 (Gen 3, 2 nodes) | ~₹33,000 + GST (~$385) | Yes | Too much |
| Azure Flexible Server B2s | ~$30 + storage (PITR included) | No | Far from OVH |
| Azure Flexible Server GP with zone-redundant HA | ~$250-280 | Yes | Far from OVH |
| Supabase / Neon | from ~$25 | Paid add-ons | On AWS or Azure regions, far from OVH |
| Cosmos DB (NoSQL) | free tier, then RU-based | Yes | Document model with no joins: wrong shape |
| Cosmos DB for PostgreSQL | - | - | **Retiring 31 Mar 2029, no new deployments**; the successor (Elastic Clusters) is overkill |

Self-hosting duties: off-server backups (`pg_dump` or WAL archiving), a **tested restore**, patching in a quiet hour.
A managed database earns its price when downtime or data loss would really hurt.

## 4. Side findings for tsr-account (not stack decisions)
- **Port exhaustion in today's PHP:** a new DB connection per request left 17-18.6k TIME_WAIT sockets at 50
  VUs, and "Cannot assign requested address" errors were swallowed by the app, so they don't show as HTTP errors.
  It may cap production throughput under load (e.g. a live quiz). The likely fix is persistent PDO or socket reuse tuning.
- The synthetic `schema.sql` lags the migrations (e.g. `idx_users_email`).
- Derived class roles are never granted in legacy `/user/permissions` (`permissions.php:91-98`).
- The local dev DB held production member data, and `tsr_mobileapi` held the real Firebase secret.
