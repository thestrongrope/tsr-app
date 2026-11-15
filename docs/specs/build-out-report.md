# tsr-app build-out report (14 Nov 2026)

State of the C# rebuild of The Strong Rope's API on branch `dotnet-11`, five days after the first commit (10 Nov 2026).
Every number below names where it came from; the last section lists what was run on which day. Nothing here is pushed.

## 1. Summary

- **The whole PHP API surface is ported.** 219 of 219 operations in the route catalog are built, each with contract tests
  and database tests. Six more public routes serve the app's Library in place of the website.
- **It is well tested locally.** 3,293 .NET tests and 3,344 contract requests pass. The same contract files pass against
  PHP. The Flutter app's own Patrol journeys pass against the new API: 20 of 20 reviewer journeys, 33 of 36 persona journeys.
- **It has never run for real.** No production wiring exists in this repo, no external service (push, Firebase deletion,
  Sheets, WhatsApp) has been called with real credentials, and the one load test so far ran on a laptop.
- **Security work is mostly decisions taken, not holes left.** The serious findings of the build were decided and built on
  12 Nov. What remains is a list of behaviours kept as PHP on purpose, and go-live items for the public routes.

## 2. What was done

### The API (PHP's routes, ported)

| Domain | Operations built | Owns |
|---|---|---|
| classes | 96 | classes, levels, enrolment, sessions, syllabus, guides, reports |
| assessment | 35 | MCQs, standard MCQs, quiz competitions |
| notifications | 30 | push, devices, class notifications, the calendar (6 routes) |
| membership | 25 | profiles, registrations, students, guardians, joining |
| access | 13 | roles, permissions, grants, scopes |
| identity | 9 | sign-in, the user row, account deletion |
| platform | 9 | app version, release notes, feedback, geo, lookups, audit log |
| content | 1 | the Quran list (plus the Library routes below) |
| search | 1 | global search over an Elasticsearch read model |
| **Total** | **219** | source: `docs/specs/initial-build/operations.csv`, all `built` |

Around the routes:

- **Database:** PostgreSQL 18, one schema per domain, 43 migrations. Reads across domains go only through published
  `v_*` views; writes across domains only through the owner's published command.
- **Background workers** (a second run mode of the API image): `push-drain`, `class-schedules`, `search-feed`,
  `content-refresh`. Not built: the WhatsApp reminder runner (the Node notifier still uses the old MariaDB).
- **Report downloads** (xlsx and PDF) through one exporter in `platform`, PDFs rendered by Gotenberg.
- **Gateway:** one nginx block per path, so a path can be handed from PHP to the new API one at a time.
- **Size:** about 59,000 lines of C# under `domains/`, `hosts/` and `shared/` (migrations excluded), and about 30,000
  lines in test files.

### Website port, feature 1: the app's Library reads (13 Nov)

Six public routes under `/api/v1/` answer as today's website does, so store-live app builds keep working: the article
list, one article as HTML with related articles, categories, tags, publications, and the channel's latest videos.
A worker copies the published content files into new tables. Capability document:
`domains/content/capabilities/library-reads.md`. Features 2 to 7 of the port (search, lecture search, the static pages,
redirects) are not started.

### Tooling for verification

- **Synthetic stacks:** a default test stack and up to eight lane stacks, each its own Compose project and database, so
  agents work in parallel without touching the dev database (which holds real data).
- **PHP parity stack:** the PHP API at tsr-account `develop` `819093ea` over synthetic data, for running the same
  contract files on both sides.
- **Website parity tool:** `tools/website-parity.cs`, a C# file-based app, with its cases and an allow file of known
  differences.
- **Patrol lanes:** `tools/patrol-lane.sh` runs the Flutter app's reviewer and persona journeys against the new API,
  with accounts in a local Auth emulator and no real credential. A shared lock keeps two runners off one emulator.

### Changes after the port, driven by running the real app

| Date | Change | Found by |
|---|---|---|
| 13 Nov | `POST /auth/link` moved to membership and answers the full profile (the app could not sign in) | Patrol |
| 13 Nov | `joinUrl` built from the public web base (Share Join Link was hidden) | Patrol |
| 13 Nov | Permissions resolve in 2 database commands, not 7; the push drain claims batch after batch | review |
| 14 Nov | The guide's `share_url` built from the public web base (Translate was hidden) | Patrol |
| 14 Nov | The waiting list follows PHP's scope again (coordinators could not place registrants) | Patrol |

## 3. What is tested and solid

| Check | Result | Last run |
|---|---|---|
| Build, warnings as errors | 0 warnings, 0 errors | 14 Nov |
| Database tests (`db/tests`, real PostgreSQL in a container) | 1,347 pass | 14 Nov |
| Host tests (route catalog, module boundaries, SQL boundary, public surface) | 97 pass | 14 Nov |
| Domain unit tests (8 domains) | 1,698 pass | 13 Nov; membership (257) again on 14 Nov |
| Shared and site tests | 151 pass | 13 Nov |
| Contract tests, every Hurl file, new API | 250 files, 3,344 requests, all pass | 14 Nov |
| Contract tests against PHP | every contract script passed at `819093ea` | 12 Nov; membership (24 files, 233 requests) again on 14 Nov |
| Website parity, Library routes | 67 cases and all 501 published articles, 0 failed | 13 Nov, against a local run of the website |
| Patrol, reviewer journeys on the new API | 20 of 20 pass, no 5xx at the gateway | 14 Nov |
| Patrol, persona journeys on the new API | 33 of 36 pass | 14 Nov (three causes below) |

What makes these results trustworthy:

- **PHP is the oracle.** A slice is done when its Hurl file passes on PHP and on the new API.
- **Structure is enforced by tests, not by convention:** which domain may reference which, which SQL may read which
  schema, what is public in each assembly, and that the route catalog matches the code.
- **The app itself is a test.** The Patrol runs found four real gaps that the contract tests could not see, because the
  PHP parity stack lacked a setting or because a deliberate deviation broke a screen. All four are fixed.
- **Reviews were unanchored.** Each batch went to separate qa and security reviewers who saw the code and the spec, not
  the author's reasoning; the final Library review failed the first parity evidence and it was redone.

The three persona journeys that still fail:

| Journey | Cause | Kind |
|---|---|---|
| ladies admin | its own seed creates one ladies class, so the app opens it directly | stale journey (tsr-account) |
| super admin WhatsApp link | no notifier service on a lane | environment |
| gents admin (2 of 4 full runs) | a race in the test harness on a lazy list | fixed in the harness; passed 3 of 3 alone since, full run not repeated |

## 4. What is not verified

- **Real external services.** FCM push, Firebase account deletion, Google Sheets and the WhatsApp notifier have only
  met fakes at the boundary. Elasticsearch is proven on the test stack (real 9.2.3). The YouTube feed was read for real
  once, in the parity run.
- **Production.** There is no production compose file in this repo, no deploy has been made, and no data migration
  from MariaDB to PostgreSQL has been rehearsed end to end for a cut-over.
- **Load.** One load test on a laptop (section 6); not repeated, and not on production-class hardware.
- **The app on the Library routes.** Its website address is a constant, so its Library screens have never called the
  new routes; that rests on the parity run and field assertions.
- **The live website.** Parity was measured against a local development run on a feature branch.
- **iOS.** Patrol runs on Android only; the iOS run hangs and was not pursued.
- **The dev stack** still runs older code; it was deliberately not touched.

## 5. What is pending

**To build**

1. Production wiring: the Dokploy compose file, settings, the Gotenberg and Elasticsearch services, one worker instance.
2. The cut-over plan: path-by-path handover at the gateway, the data move, rollback.
3. The WhatsApp reminder runner.
4. Website port features 2 to 7.
5. One service-account token provider in `shared/api` (three Google clients were each written separately).
6. Telemetry: the stack document settles on OpenTelemetry to a collector, JSON files and DuckDB. None of it is wired in
   the code yet; today the API logs to the container's standard output only, and there is no usage-trend data from the API.
7. A git remote: this repository has none. A clean copy is to be pushed first, then the cut-over decided (Asif, 14 Nov 2026).
8. Catch up with PHP: tsr-account `develop` is at v1.6.0 (15 commits after the ported copy; no new route; changes to the
   pending nudge, this-week and phone-number handling), with 1.7.0 features due the following week.

**To verify**

9. Each external service once with real credentials, in a controlled way.
10. Act on the load test's findings (section 6), then repeat it with three repetitions on a quiet machine.
11. A confirming full persona run; a second ladies class in the persona seed.

**Housekeeping**

12. Rate limits live in memory per process: move them to the database before a second API instance runs.
13. The content tests need Docker though many are pure logic; `content` has no unit-test project.
14. `domains/CLAUDE.md` rule 11 (erasure) describes an event-only design that is no longer what is built.

## 6. Performance

**What was measured**

| Measurement | Result | Caveat |
|---|---|---|
| Stack benchmark, 9 Nov: PHP against a C# prototype of `GET /me`, 10 users at once | C# 1,950 req/s, p95 6.1 ms; PHP 582 req/s, p95 76.5 ms | a spike on MariaDB with synthetic data, before the build |
| Same, 50 users at once | C# 2,260 req/s, p95 31 ms; PHP 263 req/s, p95 383 ms | same |
| Same benchmark, EF Core against raw SQL in C# | EF Core about 40% lower throughput at 50 users | one run, and on a different database driver |
| A signed-in request on the built API | about 6.5 ms, before and after the permissions change | single requests on a laptop, 13 Nov |
| Permissions for a caller | 2 database commands where PHP spends 7 | pinned by a test; no latency gain measured |
| Library routes, 95th of 100 reads | list 3 to 7 ms, article 3 to 4 ms (target 300 ms) | sequential, one client, 501 articles |
| The full contract suite | 3,344 requests in 17 to 66 seconds | not a benchmark; shows nothing is slow |

The benchmark's own fairness review (`docs/specs/profile-bench/review.md`) notes a fanless laptop, a fixed run order and
uneven logging between stacks; its direction (C# several times PHP's throughput under concurrency, with far lower tail
latency) held across three repetitions.

**Load test of the built API (14 Nov, `docs/specs/load-test/results.md`)**

Lane 5, PostgreSQL, 26,244 synthetic users, the API limited to 2 CPUs and 512 MB, k6 inside the Docker network.
The mix is the five calls the app makes on opening.

| Members in flight | Requests a second | p95 | Errors |
|---|---|---|---|
| 10 | 287 | 77 ms | none |
| 20, for 15 minutes | 437 | 96 ms | none |
| 50 | 358 | 255 ms | none |
| 100 | 177 | 1.4 s | 20 answers of 401, 2 of 500 |

- The API uses its 2 CPUs fully from about 10 members in flight; past 50, throughput falls instead of holding.
- Memory was flat over the 15 minutes (320 to 335 MiB) with 20 database connections.
- Slowest routes at 10 members (p95): the registrations report 195 ms, search 151 ms, the class list 113 to 142 ms,
  this-week 118 ms.

Findings:

1. **Logging. Fixed 14 Nov.** The image set no log level, so every request logged each SQL command. The framework now
   logs at Warning by default. Measured gain: 60% in one control run, 2% to 17% in the rerun after the fix; single runs
   on a noisy machine, so the size of the gain is not established.
2. **Every signed-in request runs six SQL commands before its route**, one of them an `UPDATE`.
3. **The registrations report** answers 577 KB of JSON, unpaged.
4. **PDF downloads. Partly fixed 14 Nov.** The gateway now waits 70 s on downloads, so it no longer cuts a render short.
   The renderer's own limit is raised from 30 s to 60 s (15 Nov). A rerun of five at once had no failure (p95 2.6 s), but it
   was also about eight times faster than the earlier runs for a reason not found, so the new limit was not exercised.
5. **Overload:** no shedding; at 100 members throughput halves and sign-in checks start to time out.

Limits of this test: one to two repetitions, a laptop that was itself saturated at 50 members and above (repetitions
differ by up to 1.8 times), and sign-in checked against a local emulator over HTTP where production checks a signature
in process. A PHP run was made on the same data but is not a valid comparison (the synthetic MariaDB lacks
production's indexes), so no ratio is quoted. That PHP run's own sign-in wrote a last-login stamp to about 360
synthetic user rows in the parity database.

**What is still not known**

- A like-for-like comparison with PHP on the same data and indexes, and figures from production-class hardware.
- The heavy routes: report downloads, PDF rendering through Gotenberg, the MIS report, bulk adds, search.
- The workers at production volume: the push drain takes batches of 50 for up to 50 seconds a tick; never run against FCM.
- Memory and start-up of the real image. The API is built with the AOT and trim analyzers on; no AOT publish is in the
  command list.
- One known hot spot, kept: the quiz winners feasibility check tries every subset of the started quiz days (capped at
  20 days) on each read of the quiz admin page.

## 7. Security

**Built into the design**

- Rules live in a domain, never in a client. The repository is public and anyone can build a modified app.
- Every member route: caller present (401), `access` allows it (403), validate (422), then act.
- Gender segregation is a scope from `access`, applied by each domain to its own data.
- Prepared statements only; a test scans every SQL literal for cross-domain reads.
- Synthetic data only in code, tests, seeds and logs. The dev database holds real data and no test tool may run on it.
- No secret in git; gitleaks over the Library change found only a local-only compose password that predates it.

**Decided and built on 12 Nov** (`docs/specs/initial-build/decisions.md`)

- Completing an account deletion removes the Firebase account of every user row of the token, before the database.
- A Firebase delete found by email, or returning a uid, that another member's row holds is refused.
- A permission grant to oneself is refused. A gender admin cannot change the rules of a super admin or gender admin.
- A member holds at most 20 devices and may register 10 new device ids an hour.
- A quiz with answers cannot be edited. This needs the release process before production: a live app build's edit that
  used to succeed is now refused.
- A unique index on the quiz code.
- Case-sensitive comparison bugs found in the test phase (C1, C2, C3, C5, C6) are fixed, each with a test.

**Kept as PHP on purpose, still true**

- The operator does not confirm the Firebase account found by email (a confirmation would break the store-live admin app).
- One holder of `deletion-requests:manage` can raise, confirm and complete a deletion alone.
- Registering a device id takes it over from another member (a phone that changes hands), within the limits above.
- Personal data in the access log goes to every `audit-log:read` holder; student names in the MCQ summary go to every
  `reports:read` holder; the leaderboard's row scope is the reports one.
- The waiting list shows a coordinator every waiting person of their gender (reversed to PHP's rule on 14 Nov; an
  automated review flagged it as wider exposure of contact details, and the owner's decision stands).
- Deactivated classes and transfer history follow PHP's scope since 15 Nov (the right is the only gate; the stricter rule of 11 Nov is withdrawn).
- Search: a teacher hit is re-checked for existence only, not current gender or teaching status.
- The WhatsApp routes forward the notifier's own error text.

**The Library routes (public, unauthenticated)**

- Reviewed three times by qa and security. No blocking finding at the end.
- Holds: Markdown rendered with raw HTML dropped and unsafe link schemes emptied (58 hostile inputs produced nothing
  that could run); the front-matter reader refuses aliases, anchors and tags; the feed reader prohibits DTDs, follows no
  redirect, and is bounded in time, size and depth; a failed refresh cannot empty the public tables.
- Drafts are never copied. On the local run of today's website, a draft is readable by its slug; worth checking on the
  live site before cut-over.
- Open before go-live: no rate limit or shared cache in front of `/api/v1` (deferred to an API gateway);
  `OPTIONS` and `HEAD` answer 405, which a browser client needs fixed.
- Low, recorded: a hostile content file can stall the refresh worker for a while; the API and the worker share one
  database role with write rights on every schema.

**At cut-over**

- Push dedupe keys use SHA-256 where PHP uses SHA-1, so keys PHP already queued will not match.
- `TSR_NOTIFIER_URL` has no default: without it every WhatsApp route answers 502.
- Database role grants for the cross-schema deletes of an account erasure are unchecked.

## 8. Decisions waiting on the owner

1. Answered 14 Nov, built 15 Nov: deactivated classes and transfer history follow PHP's scope.
2. Website port: does production use lecture search by meaning; which small pages are kept? (Decap CMS: unused.)
3. Library details that were assumed: how soon a published article must appear (the worker ticks every 5 minutes),
   the oldest supported app build (17), and whether a future-dated article stays visible as today.
4. What comes next: the production compose file and cut-over plan, or website port feature 2.

## 9. Where the numbers come from

| Number | Source |
|---|---|
| 219 operations, by domain | `docs/specs/initial-build/operations.csv`, counted 14 Nov |
| Database, host and membership test totals | `dotnet test`, run 14 Nov |
| Other domain, shared and site test totals | `dotnet test`, run 13 Nov; not rerun after the 14 Nov changes |
| 250 files, 3,344 requests | Hurl on the rebuilt default test stack, 14 Nov |
| PHP parity | contract scripts' `parity` side, 12 Nov; membership 14 Nov |
| Website parity | `docs/specs/website-port/parity-results.md` |
| Patrol | `build/patrol-journeys.log`, `build/patrol-personas-4.log` (not kept in git) |
| Benchmark | `docs/specs/profile-bench/results.md` and `review.md` |
| Security findings and decisions | `docs/specs/initial-build/build-out-findings.md`, `decisions.md`, the four `review-*.md` |
| Lines of code | `wc -l` over `*.cs`, approximate |

Commits: tsr-app `dotnet-11` up to `49ad475`; tsr-account `test/patrol-journeys-new-api` up to `18958535`.
