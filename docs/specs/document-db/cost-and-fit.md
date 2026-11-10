# Document database vs self-hosted PostgreSQL: cost and fit

Read-only web research, pages read on 2026-11-10. Prices are USD, list price, no discounts.
"unverified" means the figure or claim was not confirmed on an official page during this research.

## Answer in short

- At this scale a document database is cheap in money, but not cheaper than PostgreSQL on a server already rented (marginal cost near zero).
- The Firestore and Cosmos bills are small ($0 to about $50 per month). The real cost is fit, not price.
- The workload is relational: joins, GROUP BY reports, many optional filters, case-insensitive search. Neither product joins across collections or containers. You would rebuild joins in C# code or duplicate data.
- A document database is cheaper or simpler only for: no server to run, built-in backups, and a free tier at the smallest size.

## Assumptions

| Item | 5k members | 50k members | 250k members |
|---|---|---|---|
| Daily active (30%) | 1,500 | 15,000 | 75,000 |
| Reads per day (20 each) | 30,000 | 300,000 | 1,500,000 |
| Writes per day (2 each) | 3,000 | 30,000 | 150,000 |
| Reads per month (x30) | 0.9 M | 9 M | 45 M |
| Writes per month (x30) | 0.09 M | 0.9 M | 4.5 M |
| Stored | 5 GB | 20 GB | 100 GB |

- Average document 1 KB. Stored size is taken as given (it should already include indexes; real index overhead is unverified).
- One read = one document read. Admin list screens and reports read many documents per request, so these totals are a floor.
- 730 hours per month. Deletes ignored. Single region, no replicas, no backup extras.
- Cosmos RU cost per operation is an assumption: 1 RU for a 1 KB point read, 5 RU for a 1 KB write. unverified (Microsoft request-unit page not fetched).

## Prices used (official sources)

| Product | Price | Source note |
|---|---|---|
| Firestore Standard, us-central1, reads | $0.30 per million ($0.03 per 100k) | Firebase pricing page |
| Firestore writes | $0.90 per million | same |
| Firestore deletes | $0.10 per million | same |
| Firestore storage | $0.00020 per GiB-hour = about $0.146 per GiB-month (my calculation, x730) | page gives hourly only |
| Firestore free daily quota | 50,000 reads, 20,000 writes, 20,000 deletes, 1 GiB stored, 10 GiB out per month | Firebase billing page |
| Firestore Enterprise edition | $0.05 per million read units (4 KiB), $0.26 per million write units (1 KiB), $0.00032 per GiB-hour | Firebase pricing page |
| Cosmos serverless | $0.25 per 1 M RU; storage $0.25 per GB-month | Azure Retail Prices API, eastus |
| Cosmos provisioned (manual) | $0.008 per 100 RU/s per hour; storage $0.25 per GB-month | same |
| Cosmos autoscale | $0.012 per 100 RU/s per hour (billed at least 10% of max) | same, and limits page |
| Cosmos free tier | first 1,000 RU/s and 25 GB free, lifetime of the account, one account per subscription, provisioned or autoscale only, not serverless | learn.microsoft.com free-tier |

Notes:
- Azure's public pricing page masks prices ("$-"). Prices above come from Microsoft's public Retail Prices API (prices.azure.com) for region eastus. Other regions differ.
- Firestore multi-region and other-region rates: unverified.
- Firestore bills by region price; the cloud.google.com pricing page did not load, so the Firebase page was used.

## Monthly cost

### Firestore Standard

| | 5k | 50k | 250k |
|---|---|---|---|
| Reads after free quota | 30,000 - 50,000 free = 0 | (300,000 - 50,000) x 30 = 7.5 M | (1,500,000 - 50,000) x 30 = 43.5 M |
| Read cost | $0 | 7.5 x 0.30 = $2.25 | 43.5 x 0.30 = $13.05 |
| Writes after free quota | 0 (3,000 < 20,000) | (30,000 - 20,000) x 30 = 0.3 M | (150,000 - 20,000) x 30 = 3.9 M |
| Write cost | $0 | 0.3 x 0.90 = $0.27 | 3.9 x 0.90 = $3.51 |
| Storage (GiB - 1 free) x 0.146 | 4 x 0.146 = $0.58 | 19 x 0.146 = $2.77 | 99 x 0.146 = $14.45 |
| **Total** | **about $0.58** | **about $5.29** | **about $31.01** |

### Cosmos DB for NoSQL

| | 5k | 50k | 250k |
|---|---|---|---|
| RU used (reads x1 + writes x5) | 0.9 M + 0.45 M = 1.35 M | 9 M + 4.5 M = 13.5 M | 45 M + 22.5 M = 67.5 M |
| Serverless RU cost | 1.35 x 0.25 = $0.34 | 13.5 x 0.25 = $3.38 | 67.5 x 0.25 = $16.88 |
| Storage | 5 x 0.25 = $1.25 | 20 x 0.25 = $5.00 | 100 x 0.25 = $25.00 |
| **Serverless total** | **about $1.59** | **about $8.38** | **about $41.88** |
| Provisioned 400 RU/s (minimum manual) | 0.008 x 4 x 730 = $23.36 | $23.36 | $23.36 |
| Provisioned storage | $1.25 | $5.00 | $25.00 |
| **Provisioned total, no free tier** | **about $24.61** | **about $28.36** | **about $48.36** |
| Provisioned with free tier (1,000 RU/s, 25 GB free) | $0 | $0 | (100 - 25) x 0.25 = $18.75 |

- Average load is tiny: 67.5 M RU per month is about 26 RU/s on average at 250k members. 400 RU/s leaves headroom, but reports will burst (see below).
- Autoscale (minimum max 1,000 RU/s): idle floor 0.012 x 1 x 730 = $8.76 per month; full 1,000 RU/s = $87.60.
- Free tier is one account per subscription, so it may already be used elsewhere.

### Self-hosted PostgreSQL on the existing server

| | 5k | 50k | 250k |
|---|---|---|---|
| Licence | $0 | $0 | $0 |
| Marginal server cost | about $0 | about $0 | about $0 (100 GB needs disk; check free space, unverified) |
| Owner time | backups, upgrades, monitoring | same | same, plus tuning |

Marginal cost is zero only while the rented server has spare CPU, RAM and disk.

## Where a document database is cheaper or simpler

- No server, patching or disk to run. Backups are built in.
- Firestore at 5k members: effectively free (inside the daily quota; storage under $1).
- Cosmos free tier at 5k and 50k members can be $0 with provisioned 400 RU/s.
- Scales to zero effort for traffic spikes (Firestore, Cosmos serverless).
- Firestore needs no query planning for key lookups; reads are cheap per document.
- Firebase Auth and FCM already exist, so the project and billing account exist (Firestore only).

## Where it is not cheaper or simpler

- Server cost is already paid. Savings versus PostgreSQL are $0 in money; any document bill is extra.
- Reporting is billed per document read or per RU (see next section).
- Cost is variable and can surprise: one new admin screen or a retry loop multiplies reads.
- You rewrite about 190 API paths' data access. Joins become denormalised copies kept in sync in code.
- EF Core and SQL tooling (migrations, constraints, foreign keys) are largely lost.

## Reporting example: 200,000 documents, 20 runs per day

Reads per month: 200,000 x 20 x 30 = 120 M.

| Product | Arithmetic | Per month |
|---|---|---|
| Firestore Standard | 120 M x $0.30 | about $36 (the 50k/day free quota saves at most $0.45) |
| Firestore count/sum/avg only | billed per 1,000 index entries: 200,000 / 1,000 = 200 reads per run; x 20 x 30 = 120,000 reads | about $0.04 (only for count, sum, avg; no GROUP BY, see limits) |
| Cosmos serverless | assume 1 RU per document scanned: 120 M RU x $0.25 per M | about $30 (RU per scanned document is unverified; real queries can cost more or less) |
| Cosmos provisioned 400 RU/s | a 200,000 RU run takes about 500 s at 400 RU/s and may be throttled (HTTP 429) | extra RU/s needed, cost unverified |
| PostgreSQL self-hosted | one scan of 200,000 rows | $0 marginal; uses server CPU |

This one report adds about the same as the whole 250k-member app bill. Several such reports multiply it.

## Query limits that matter (relational workload)

| Topic | Firestore | Cosmos DB for NoSQL |
|---|---|---|
| Joins across collections or containers | not stated on the pages read; unverified | none. "Joins are scoped to that item and can't occur across multiple items and containers" |
| JOIN count | n/a | up to 10 per query (raisable by support request) |
| Aggregation | count, sum, avg supported; 60 s limit (DEADLINE_EXCEEDED); billed per 1,000 index entries, minimum 1 read; GROUP BY not mentioned (unverified) | GROUP BY supported (single query language); no limits found on the page read |
| Range or inequality filters on several fields | up to 10 range or inequality fields; composite index needed; Standard edition support not stated on the page (unverified) | supported; composite indexes (max 8 properties each) help |
| OR / IN | OR: 30 disjunctions; IN: up to 30 values; not-in up to 10; cannot be raised (Standard) | no such limit found; unverified |
| Cross-document transactions | up to 10 MiB per transaction, 20 s lock deadline, 270 s total; reads before writes | only inside one logical partition key, at most 100 operations per batch |
| Case-insensitive equality | not documented on the pages read; unverified. Common workaround: store a lowercase copy of the field (practice, unverified) | `STRINGEQUALS(a, b, true)`; "performs an index seek" |
| Substring (contains) | not documented on the pages read; unverified | `CONTAINS(a, b, true)`; "performs a full scan" (every document billed) |
| Full-text search | native text search needs Enterprise edition and text indexes | full-text search exists in Cosmos; not confirmed in this research (unverified) |
| Other | document size and partition limits not checked | 2 MB per item; 20 GB per logical partition; 5 s per query page; 500 databases plus containers per account |

Verdict for the owner's collation complaint: neither product has a database-wide case-insensitive setting. Cosmos lets you ask per query (`ignoreCase`) and equality uses the index, but "contains" scans everything. Firestore has no confirmed built-in way. PostgreSQL `citext`, or `ILIKE` with a trigram index, remains more capable and cheaper for substring search.

## .NET support

| | Firestore | Cosmos |
|---|---|---|
| Official client | Google.Cloud.Firestore for .NET exists; details not fetched (unverified) | Cosmos .NET SDK; EF Core provider `Microsoft.EntityFrameworkCore.Cosmos` |
| EF Core | none | works for single-document patterns |
| What EF Core Cosmos cannot do | n/a | no loading related entities from different documents (no Include across documents); no migrations or scaffolding; no ACID across operations; indexes and constraints in the model are ignored; synchronous APIs throw (EF 9 and later) |
| LINQ translation list (GroupBy, joins) | n/a | full list not captured; unverified |
| Native AOT | not stated (unverified) | not stated on the pages read (unverified) |

## Lock-in and operations

| | Firestore | Cosmos | PostgreSQL self-hosted |
|---|---|---|---|
| Export | managed export to Cloud Storage; one read billed per document; not an exact snapshot | continuous backup restore, or custom export (not fetched) | `pg_dump`, standard formats |
| Point-in-time recovery | 7 days, off by default, extra storage charge, no free tier | continuous backup 7, 30 or 35 days; 7-day tier free for backup storage; 30/35-day $0.20 per GB-month; restore $0.15 per GB | WAL archiving, set up by you |
| Local emulator | Firebase emulator exists; not fetched (unverified) | Docker and Windows emulator; not for production; Windows emulator limited; the older Linux emulator does not run on Apple silicon; no serverless mode | the real engine in a container |
| Data residency | location choice; not fetched (unverified) | serverless runs in one region only; any Azure region | wherever the server is |
| Lock-in | proprietary API and data model | proprietary NoSQL API and RU model | open source, portable |

## For comparison

- Managed PostgreSQL entry price on a mainstream cloud: unverified (Cloud SQL and Azure pages did not return a price; Azure retail query for B1ms returned no rows).
- Self-hosting: no licence fee; cost is the owner's time (backups, restore tests, upgrades, security patches) and spare capacity on the existing servers.

## Conclusion

- Money: PostgreSQL on the existing server is $0 extra. Firestore is about $1, $5, $31 per month; Cosmos serverless about $2, $8, $42; Cosmos provisioned about $25, $28, $48 (or $0, $0, $19 with the free tier).
- Fit: the workload needs joins, grouped reports and substring search. A document database makes these costly (per document) or impossible in the query layer.
- Reasonable use of a document store: a narrow slice such as notification state or feedback, not the core relational model. Not recommended as a replacement.

## Sources (read 2026-11-10)

- https://firebase.google.com/docs/firestore/pricing
- https://firebase.google.com/docs/firestore/enterprise/pricing
- https://firebase.google.com/docs/firestore/query-data/queries
- https://firebase.google.com/docs/firestore/query-data/aggregation-queries
- https://firebase.google.com/docs/firestore/query-data/multiple-range-fields
- https://firebase.google.com/docs/firestore/solutions/search
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/firestore/manage-data/export-import
- https://firebase.google.com/docs/firestore/pitr
- https://azure.microsoft.com/en-us/pricing/details/cosmos-db/autoscale-provisioned/ (prices masked)
- https://azure.microsoft.com/en-us/pricing/details/cosmos-db/serverless/ (prices masked)
- https://prices.azure.com/api/retail/prices (Azure Retail Prices API, Cosmos DB, eastus)
- https://learn.microsoft.com/en-us/azure/cosmos-db/serverless
- https://learn.microsoft.com/en-us/azure/cosmos-db/free-tier
- https://learn.microsoft.com/en-us/azure/cosmos-db/concepts-limits
- https://learn.microsoft.com/en-us/azure/cosmos-db/continuous-backup-restore-introduction
- https://learn.microsoft.com/en-us/azure/cosmos-db/emulator
- https://learn.microsoft.com/en-us/cosmos-db/query/join
- https://learn.microsoft.com/en-us/cosmos-db/query/stringequals
- https://learn.microsoft.com/en-us/cosmos-db/query/contains
- https://learn.microsoft.com/en-us/cosmos-db/query/group-by
- https://learn.microsoft.com/en-us/ef/core/providers/cosmos/limitations
- https://learn.microsoft.com/en-us/ef/core/providers/cosmos/
