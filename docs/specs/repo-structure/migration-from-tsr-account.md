# Moving from tsr-account to the tsr-app layout

Split out of `../repo-structure.md` on 2026-11-10, text unchanged unless marked. That file is the
design; this one is how today's repositories get there. Read it when moving a route, a folder or a
deploy path. The full pre-split plan is `full-2026-11-10.md`.

## When the layout applies

**When this layout applies.** The 2026-11-28 flip publishes today's layout unchanged, and prod
keeps deploying from the old private repo (option (a), `plan.md`). This layout is the target for
tsr-app after the deploy source moves to it (task L1). Each folder move lands together with the
production change it needs (Dockerfiles, entrypoint, compose, Codemagic, Dokploy watch paths),
agreed first. New folders that touch no production path (`domains/*` for new slices, `hosts/api`,
`hosts/gateway`) can start earlier.

## Order of work

Rewritten 2026-11-10, agreed with Asif. It replaces the "Stages" list (Stage 0 to 3), which is kept
in `full-2026-11-10.md` and still appears under those names in dated records (`spike-learnings.md`,
`repo-structure-review.md`). `target-architecture/plan.md` still has the old stages and has not been
updated.

Already done, mostly: clean seams in PHP (no SQL in PHP pages, no role lists outside
`PermissionsModel`).

1. **PostgreSQL first, in tsr-account.** PHP moves from MariaDB to Postgres before any route moves,
   so the new API is built on Postgres only (`../dotnet-stack.md`). It is the prerequisite, not a
   quick win: one cutover for all 191 paths, estimated at 3 to 5 weeks
   (`../db-portability/mysql-to-postgres.md`). The hard parts are behaviour, not syntax:
   keeping text case-insensitive (see "Database and migrations"), `mis.php`, zero dates and lax
   `GROUP BY`. The data move is rehearsed on a synthetic copy first, and the cutover waits for the
   two guards under "Database and migrations". Nothing in tsr-app changes.
2. **Foundation, once.** What every slice needs before the first route can go live: the Firebase
   caller verifier in `identity`, the `can()` scope shape in `access`, the gateway in production,
   and the outbox with its relay.
3. **Slices, one domain at a time.** A route moves together with its queries, its `api.yaml` entry
   and its gateway line, and passes the same contract tests as the PHP route. `POST /feedback` goes
   first; `classes` and the MIS report go last, being the largest. PHP shrinks until it is gone.
   Cron jobs move into the scheduler as their handlers move. A domain folder is never created ahead
   of its first route.
4. **The Flutter app and the static site, last.** Neither blocks the steps above and neither waits
   on the other. The app needs no change while routes move (the API stays forward compatible and
   the gateway keeps the old host name); screens move into domain packages as they are touched. The
   site needs only the public reads from `content`.
5. **Afterwards, only under pressure:** a domain that needs its own deploy or scaling gets its own
   host and a gateway line. No code moves.

Not decided:

- Whether Postgres starts from one baseline schema or the 67 MariaDB migrations are ported
  (recommended: a baseline).
- The old Stage 1 (outbox and Redis Streams inside the PHP stack): built on the .NET side in step 2
  instead, or still done in PHP first.

## Where today's folders go

Numbers in `[ ]` are the software units of `software-data-split.md`. (New on 2026-11-10: this table
replaces the `←` arrows that were in the plan's tree.)

| Target in tsr-app | Comes from |
|---|---|
| `hosts/api/`, `hosts/gateway/` | new |
| `hosts/app/` [2] | `mobile/`; Codemagic `working_directory` changes |
| `hosts/site/` [8] | tsr-web `web/`, rewritten in Razor, not moved |
| `hosts/calendar/` [14] | tsr-creative |
| `hosts/media/` [25] | tsr-content |
| `domains/notifications/worker/` [3] | `notifier/` |
| `domains/notifications/push-worker/` | `web/cli/drain_push.php` (with the outbox, step 2 or later) |
| `domains/search/embeddings/` [9] | tsr-web |
| `domains/content/pipelines/` | lectures [10], site-content [11] |
| `db/migrations/` | `migrations/` (see below) |
| `db/synthetic/` [5] | `tools/synthetic-data` |
| `db/sql/` | `DB/` |
| `legacy/php/` [1] | `web/`, `tests/`, composer, phpunit/phpcs config, `web/cli` jobs, cron |
| `tools/` [7]: `api-contract/` [6], `scripts/`, `security/` | `tools/api-contract`, `scripts/`, `security/` |
| stays in tsr-account | `tools/migrate` (tsr-migrate, Go) [4] |

Dropped: `copilot-instructions.md`, `.kiro/` (open point), `.vscode/`, `webapp-php.ini` (moves into
`.docker/`), `CONTRIBUTORS.md` (folded into `CONTRIBUTING.md`).

Not in the tree: superseded copies (tsr-app-archived, tsr-notifications, tsr-admin,
tsr-training, tsr-mobile-api ...), ahlebaytrepo* (separate), and generated output (search
indexes, embeddings, build caches).

## The gateway rollout

- A small nginx container with its route table in the repo. Moving a slice is a
  one-line change, reviewed in a PR, and checked against the specs (this file, next section).
- The local compose runs the same gateway, so contributors get prod's routing. Routes set in
  Dokploy's own Traefik would live in its UI, unreviewed and not reproducible.
- Traefik stays the outer layer: it terminates TLS and sends `api.` to the gateway. One Dokploy
  change, agreed first.
- It only forwards. Contracts, Firebase verification and permissions stay in the API.
- Not an APIM (Azure API Management, Kong, Tyk): keys, per-client rate limits, a developer
  portal and usage analytics are for third-party consumers. Reconsider if outsiders call the
  API.
- **Store-live safety:** it is a single point of failure for every installed build. It is
  stateless, with a healthcheck that uses a tool the base image has (Alpine: BusyBox `wget`, no
  `curl`). `api.` goes through it first; `mobile-api.` moves behind it only after it has served
  `api.` cleanly for one release. Rollback is one Traefik line back to `mobileapi`. The
  `mobile-api.` alias stays until `minimumBuild` passes the first build that calls `api.`.

## Which route source wins while slices move

- **Until a path moves, the PHP route table stays the authority.** `web/api-docs.json` keeps being
  generated from it and gated in CI, unchanged (`docs/dev/api-contract.md`).
- **When a path moves,** its definition moves to the owning domain's `spec/api.yaml` in the same
  PR, and the gateway table sends it to the new API.
- **`tools/api-contract` fails the build** if a path appears in both the PHP table and a domain
  spec, or if the gateway table routes a path that neither defines.

Today's 191 paths carry operation tags partly by domain (`classes` 43 operations, `mcq` 18),
partly by audience (`admin` 51, `me` 17) and partly by mechanism (`reports` 37, `health`). They are
regrouped by domain as slices move.

## Permissions while PHP remains

- **Today `PermissionsModel::can()` mixes all three** (scopes, the teacher gender rule, "a class
  must be active"). The class rules move to `classes` when `PermissionsModel` is rebuilt as slices
  move; until then the PHP model stays as it is, written once (`CLAUDE.md`).

## Database and migrations

- **Until the move:** MariaDB, and tsr-migrate (Go, in tsr-account) applies one ordered directory
  keyed by file name and checksum. tsr-migrate does not come to tsr-app. The sample's
  `db/migrations/*.sql` and `db/dev-init/load.sh` stand in for it locally.
- **Text stays case-insensitive on Postgres** (rule from Asif, 2026-11-10). Every text column ignores
  case, as it does on MariaDB today. A column is case-sensitive only with a distinct reason written
  beside it in its migration (for example a hash or a token compared byte for byte). Today no plain
  text column is: the only `utf8mb4_bin` columns are JSON columns (`payload`, `details`,
  `field_of_study`, `professional_courses`, `settings_snapshot`), which become `jsonb`.
  - How: `citext` for every text column, applied by the schema conversion, not chosen per query.
  - Not verified: MariaDB's collation also ignores accents and `citext` does not, so name searches
    (Latin, Arabic, Urdu) need a test on synthetic names; if they rely on it, use an ICU collation
    that ignores both. Also unchecked: `citext` in the Postgres image and its EF Core mapping.
  - Length limits are kept: `citext` has no `citext(n)`, so each `varchar(n)` becomes `citext` with
    `CHECK (char_length(col) <= n)`, generated by the schema conversion.
  - **Guard 1, parity before cutover (not built).** The same reads run against MariaDB and Postgres
    on the same synthetic data and must return the same rows: sign-in by email in mixed case,
    name and city searches, unique keys refusing `Ali` when `ali` exists, joins on text keys, and
    the behaviours listed under "Implicit behaviours to flag" in
    `../db-portability/mysql-to-postgres.md` (`GROUP BY`, booleans, zero dates). No cutover until
    this passes.
  - **Guard 2, schema check in CI (not built).** A test reads the Postgres catalog and fails if a
    text column is not `citext`, unless the column is on a short allow-list with its reason. It
    also fails if a column that had a length in MariaDB has no length check. This keeps new tables
    from quietly going case-sensitive.
  - Known leak the guards must cover: a cast to `text` inside a query (`col::text`, or a string
    function returning `text`) compares case-sensitively again.
- **Moving today's `migrations/` to `db/migrations`** (only if the MariaDB history moves at all
  before Postgres) is not a plain rename. The lint compares against
  the base tree, so from the new path all 67 files look added and the legacy `001_*` and
  `*_rollback.sql` names fail. It needs a one-off lint exemption, and three production files
  hardcode the old path: `.docker/entrypoint.sh:21`, `.docker/Dockerfile.webapp:84` and
  `.github/workflows/migrations-lint.yml:26,32`. It lands with the deploy-source switch.

## `legacy/php/` and the Flutter app

- **`legacy/php/`:** not restructured. Its `web/models/` (43 files) map onto the domains in
  section 4 of `../repo-structure.md`; which model moves first is decided per slice.

- **`hosts/app`:** today's `lib/features/` groups by screen area (`admin`, `reports`, `wordpress`,
  `grand_quiz` ...), not by domain. Screens move into domain packages as they are touched, not in
  one go.

## Build and platform notes

**Docker build contexts.** Today compose builds with `context: .` and `.dockerignore` excludes by
top-level folder (`mobile`). With Flutter packages inside `domains/*/app`, that no longer works:
each host gets its own build context, or `.dockerignore` adds patterns such as `domains/*/app`.

- **Windows:** deeper paths (`domains/*/app/lib/features/...`) under Gradle are a long-path risk;
  not verified. The README tells Windows contributors to set `core.longpaths`.
