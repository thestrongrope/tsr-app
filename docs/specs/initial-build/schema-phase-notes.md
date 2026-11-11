# Schema phase, task S1: notes (2026-11-10)

Built on `main`, uncommitted. Design: `schema-phase-design.md`. Facts: `schema-phase-recon.md`, `schema-phase-tables.csv` (now with a `decision` column).

## Tables per schema (from the migrated database)

| Schema | Tables | Of which new in S1 |
|---|---|---|
| `classes` (new module) | 16 | 16 |
| `notifications` (new module) | 8 | 8 |
| `assessment` (new module) | 7 | 7 |
| `platform` | 10 | 4 (`admin_access_log`, `genders`, `languages`, `outbound_messages`) |
| `content` | 2 | 1 (`holy_quran`) |
| `identity` | 2 | 0; `account_deletion_requests` gets its 7 missing columns (`source`, `reason`, `contact_name`, `operator_note`, `cancelled_at`, `confirmation_sent_at`, `handled_by`) |
| `access`, `membership` | 7, 6 | 0 |

36 tables ported (16 + 8 + 7 + 4 + 1). One migration per context: `Initial` (classes, assessment, notifications), `AddQueueAndLookupTables` (platform),
`AddHolyQuran` (content), `DeletionRequestRest` (identity). `active_token` is a partial unique index (`uq_active_token`, status pending or awaiting_prize_delivery).

## Schema facts refreshed (scope 1)

- **The parity MariaDB is built from `schema.sql`, not from migrations** (`synth/build.py` loads `schema.sql` and seed files). It holds 68 tables and the view, and lacks
  `class_scheduled_notifications` and `class_scheduled_notification_runs`. So the check was redone in a scratch database inside the parity container: `schema.sql`, then every
  migration forward in name order (skipping `_rollback`, `_preflight` and `withdrawn.list`), then `SHOW CREATE TABLE` for the 36 tables and `account_deletion_requests`. The scratch
  database is dropped and the parity stack stopped.
- Result: the forward replay and the parity database are column-identical (every column, type, nullability and default diffed) apart from the two 2026_11_08 tables; the CSV has no per-column types, so against the CSV I compared column counts and text/enum counts per table: all match.
- **CSV corrections** (checked field by field against the original: only the new column and the four notes cells below changed): (1) new `decision` column: `port` 36, `ported` 17 (15 in full, `users` and `account_deletion_requests` partly), `leave` 15, `derived` 3, `absent` 4;
  (2) `teacher_training`, `teacher_training_history`, `surveys`, `schema_migrations` are in neither the dump nor any migration, so they are `absent`: nothing to port. Whether
  production has them stays **unverified**. Not a CSV change, a finding: the CSV lists only unique keys, so these non-unique indexes were missing from it: `class_attendance` (session, token), `class_sessions` (class, conducted_on) and (conducted_on),
  `class_students` (class_id) and (token_no), `spot_quiz_questions` (spot_quiz_id), `spot_quiz_responses` (spot_quiz_id, token) and (token), `spot_quizzes` (class_id, published_at). They come from the
  2026_10_28 migrations (the dump predates them) and are in the new migrations. The CSV's "N text-like + M enum/set" means N + M in total; nothing to fix there.
- UTC: `@@system_time_zone` is UTC in the parity container. That is the container, **not a fact about production**; design decision 2 still needs the owner's answer for the real PHP server and MariaDB.

## Type decisions

- Text: `citext` plus a length CHECK from PHP's length. `text` is capped at 65,535 (PHP's limit): `class_students.notes`, `guides.guide`, `notifications.body`, `class_scheduled_notifications.body`,
  `notifier_runs.error_message`, `notifier_sent_messages.error`, `outbound_messages.error`. `longtext` has no cap (as `feedback.message`): `class_audit_log.details`, `notifications.target_audience_criteria`,
  `notifier_runs.settings_snapshot`, `outbound_messages.payload`.
- **Divergence from membership:** those four JSON columns stay text (the task rule), where membership made its two `jsonb`. They carry `CHECK (col::text IS JSON)` to keep MariaDB's `json_valid` guarantee.
- Enums to text plus a CHECK of the listed values (`class_audit_log.action`, `student_transfers.type`, `syllabus.link_type`, `class_scheduled_notifications.kind` and `status`, `account_deletion_requests.source`).
  `char(1)` status and Y/N columns get only the length-1 check: I did not invent value lists PHP code does not prove (code shows 'A' and 'I' for a class).
- Flags: every `tinyint`, `tinyint(1)` included, is `smallint` (decision 3). This differs from the older ported tables, which use `boolean` for `tinyint(1)`. `spot_quiz_questions.is_arabic` is `bit(1)`, so `boolean`.
- `bigint unsigned` is `bigint`, `int unsigned` is `integer`, `float` is `real`, `decimal(10,8)` and `(11,8)` keep their precision.
- `classes.city` and `classes.country` are `text` with the ICU collation `geo_ci_ai` and a hand-written length CHECK (300); platform's migration owns the collation. Guard allow-list updated with a reason.

## Wall-clock columns (judged)

- `class_scheduled_notifications.send_at`: `timestamp without time zone` (ONCE: local date and time in the row's `tz`, per the PHP column comment).
- `class_scheduled_notifications.send_time`, `notifier_reminders.send_time`: `time` (local time of day in `tz` / `timezone`).
- Seven PHP `date` columns stay `date`, not an instant: `classes.started_on`, `shutdown_on`, `completed_on`, `class_sessions.conducted_on`, `class_students.joined_on`, `notifier_runs.from_date`, `to_date`.
- Judged instants (`timestamptz`, read as UTC), flagged because the data cannot prove it: `quiz_campaigns` windows (registrations, quiz start and end: an admin probably typed local times), `class_scheduled_notifications.last_run_at`,
  `notifier_runs.started_at` and `finished_at` (PHP `timestamp`, so UTC in MariaDB). `class_schedules` has no date-time: weekday, hour and minute integers with a timezone name.

## Deferred or not ported (by design, no handler yet)

- PHP triggers: `classes_before_create` (the share `link`) and `spot_quizzes_before_insert` (the `code`): the slices that create the rows must do it.
- `ON UPDATE CURRENT_TIMESTAMP` (`user_devices.last_accessed_at`, `notifier_reminders.updated_at`, `class_scheduled_notifications.updated_at`, `syllabus.modified_at`): columns default to `now()`; the updating handler sets them.
- The leave-behind 15, `class_access`, `class_access_from_rules`, `calendar_table`, `age_ranges`, the 8 unread `users` columns: not ported.
- **Defaults trap for the next phase:** EF treats the CLR default as "not set", so a slice that saves `0` into a non-nullable numeric column with a non-zero default is written as that default. Affected: `class_sessions.conducted` (default 1), `syllabus.is_active` (1), `spot_quizzes.restrict_to_class` (1), `notifier_reminders.enabled` (1) and `leeway_days` (10). Write those with SQL, or map them nullable, in the slices.
- The one foreign key with a delete rule that PHP leaves as RESTRICT (`syllabus` to `class_levels`) first came out as CASCADE (EF defaults a required key to it). A db test now pins all three delete actions; the classes migration was regenerated (still one `Initial`).
- `account_deletion_requests.id` stays `integer` (PHP: `bigint unsigned`); the load script (S2) should know.

## Surprises

- The Hurl run needs the root `CLAUDE.md` preparation (not repeated in the task text): `tools/identity-contract.sh dev`, `tools/membership-contract.sh dev --prepare`, then the documented command with `--variables-file build/dev/membership.vars`, and 60 s since the last geo run. Some membership files change rows, so prepare again before each run.
- The seed's idempotence check cannot be a whole-database diff: `membership-fixtures.sql` resets its rows on every run (it did before this task). Check used: per-table row counts and an md5 of every row text for all 58 tables; only four membership tables differ.
- The seed uses fixed ids (9001 and up) with `ON CONFLICT DO NOTHING`; sequences are not advanced, so a first generated id is 1 (no clash below 9001 rows).
- The membership-style "tests first, watch it fail" applied to the shared `CheckSql` helper (red on compile, then green), and the guard allow-list (mutation: removing the two new entries fails `Every_text_column_is_citext_unless_allow_listed_with_a_reason`).
  The three new model tests were written before the contexts but I did not run them red separately; the db tests passed on first run.

# Task S2: the data load (2026-11-10)

Built on `main`, uncommitted. Tool, run guide and report key: `tools/data-load/README.md`.

## What exists
- `tools/data-load/load.sh` (bash, no installs; clients are commands given in the environment, passwords only through `MYSQL_PWD` and `PGPASSWORD`), `tables.txt` (52 source-to-target rows: the 36 S1 tables and the 16 earlier-ported ones; geo excluded), `sql/00-engine.sql` (one PL/pgSQL loader that converts by the TARGET column type, so the older `boolean` and the S1 `smallint` flags both work), `sql/10..80` (one transaction per domain), `sql/90-orphans.sql` (57 logical references), `sql/95-report.sql`.
- Export is PostgreSQL COPY text produced in MariaDB SQL (not `mariadb -B`, which prints NULL as the word NULL), streamed into an all-text `staging` schema; no file holds row data.
- Rows the target refuses are counted per reason (SQLSTATE, constraint, column; never a value) after a row-by-row retry; the load does not stop.

## Decisions I made (please confirm)
1. **Migration-seeded tables are merged, not replaced:** `access.permissions`, `access.role_permissions`, `membership.interest_options`, `platform.lookups` already hold rows after `--migrate`. The load keeps the seed rows, adds missing ones and counts the differences per column (only `created_at` differs in the synthetic data). Replacing would have dropped the permission the access migration added after PHP's seed (PG has 102, a stale source 101).
2. A rejected row is not loaded (over-length value, NULL in a required column, duplicate key, bad number). Only `name` (200) and `picture` (2000) are cut, counted.
3. Invalid JSON in a nullable JSON column becomes NULL and is counted; in a required one the row is rejected.
4. Zero dates become NULL where the column allows it; in a required column the row is rejected and counted.
5. `datetime` read in `--source-tz` (default UTC), `timestamp` always UTC (the export session is set to +00:00).

## Source for the proof
Not a fix of the parity build: a scratch database `tsr_synth_s2` in the parity MariaDB (`tools/parity-php/s2-source.sh`): a copy of `tsr_synth`, plus the two additive 2026_11_08 migrations, plus invented rows (`s2-fixtures.sql`, tokens 960001 and up; `s2-contract-fixtures.sql` and `membership-fixtures.sql`, the Hurl members). A full forward replay was tried first and abandoned: the data migrations (reviewer demo cohort, collation and profile-text rewrites) are not safe over generated rows and one ran for minutes. S1 had shown the dump equals the forward replay apart from the two tables. The generator left `syllabus`, `tags` and the two 2026_11_08 tables empty; the fixtures fill them.

## Results (synthetic, run 2026-11-10)
- Build 0 warnings; all NUnit projects pass (access 64, platform 205, membership 274, site 12, host 29, assessment 1, identity 63, notifications 1, classes 1, shared 16, db 267).
- Load into a freshly migrated, empty database (no `--truncate`): 52 target tables, source 705,039 rows, loaded 678,565, filtered by design 26,193 (users with role 0), skipped 281 (the merge tables' seed rows), rejected 0. Per table, loaded = source (`prove-synthetic.sh` step 2). 27 assertions on values (a timestamptz, `timestamp`, wall-clock `time` and `timestamp`, an enum, a SET, JSON and NULL JSON, NULL versus empty, accents and emoji, multi-line text with tab, CRLF, backslash, quotes and `\N`, a zero date, a 2001-character picture), the reject path (8 hand-made rows: 2 load, 6 rejected under 6 reasons; invalid JSON), orphan counts equal to MariaDB's on 5 references, refusal of a non-empty target, `--truncate`, `--source-tz Asia/Kolkata`, staging dropped.
- Hurl on the loaded database (identity-contract, membership `--prepare` with `TSR_FIXTURES_LOADED=1`, the documented all-files command): 20 of 21 files, 273 requests ran; the one failure is `content/list-published-articles.hurl`, because `content.articles` has no PHP table and its article exists only in `seed.sql`. A new variable `TSR_FIXTURES_LOADED` in `tools/membership-contract.sh` skips adding the seed's fixtures on top.
- The normal dev stack was restored (empty volume, migrate, seed): 21 files, 273 requests pass. Parity is stopped.

## Cannot do yet / open
- Never run on real data: expect values the synthetic set lacks (zero dates, bad JSON, over-length, duplicates under `citext`). Production's zone for `datetime` is still unconfirmed (decision 2).
- The 57 orphan references are a chosen list, not all 112 token columns. `member_profiles.language` reports every `0` as an orphan.
- Tests are scripts run by hand (`prove-synthetic.sh`), not part of `dotnet test`. Tests were written before the engine was run, but the engine and the assertions were written in one pass; the first run failed at the load (a glob), not on an assertion, and I did not mutate the engine to watch each assertion fail.
- I ran one bare `python3 -` by mistake (empty stdin, no effect; it may linger as a hung process). Nothing else broke the tool rules.

# S3: the route surface (2026-11-10)

## What was built
- Catalog `docs/specs/initial-build/operations.csv` (method, path, domain, auth, state). **213 rows, not 211** (see deviations). Built 21, planned 192.
- Per domain (built / planned): identity 1 / 9, access 3 / 10, platform 7 / 2, membership 10 / 14, content 0 / 3, classes 0 / 85, assessment 0 / 43, notifications 0 / 25, search 0 / 1.
- New `search` module (routes only, no tables), registered in `Modules.cs`, `Program.cs`, `TsrApp.slnx`, the boundary and public-surface tests; the guard test "one context per domain" allows a domain without tables.
- One `Planned.cs` per domain, generated once from the catalog; shared helper `shared/api/PlannedRoutes.cs` (`MapPlanned`, `MapPlannedPublic`, marker `PlannedRoute`). Placeholders: member routes `.RequireMember()`, public ones nothing, then 501 `{"detail":"Not implemented"}`.
- `shared/api/RouterErrors.cs`, `app.UseRouterErrors()`: the built side answered unknown path and wrong verb with an empty 404/405; PHP gives `{"detail":"Not Found"}` / `{"detail":"Method Not Allowed"}`. Now it does, only where the body is empty (a handler's own 404 is untouched).
- Gateway: 175 new locations (one per planned path not already routed); the fallback for unknown paths is kept.
- Tests: `hosts/api/tests/RouteSurfaceTests.cs` (route table = catalog, extras only `GET /articles`; states and sign-in kinds match the real endpoint metadata; every planned route 401 without a token, public ones 501; 404/405 bodies; the 8 PHP route-order overlaps resolve to the literal route), `GatewayTests.cs` (every catalog path has a gateway location), `db/tests/PlannedRoutesTests.cs` (signed in: every planned member route 501 and no user row created; an unknown user on a PHP create route is 404 and creates nothing). Hurl: `hosts/api/spec/planned-surface.hurl` (15 requests: one placeholder per domain, 401, 405, overlap, 404), outside the per-domain folders because it is cross-domain and PHP has no 501 (the platform script would run it on PHP); the all-files command in `CLAUDE.md` and `README.md` gained a second `--glob`.

## Deviations and assumptions
- **213, not 211.** `api-docs.json` and PHP's router both have `GET /me/guides` and `GET /me/guides/{slug}`; `operation-domains.csv` and `permission-map.csv` lack them (left unedited). Added to the catalog under `classes` (it owns `guides`), auth `member`. Tests count from the catalog.
- Auth kind `create` means PHP's handler body calls `api_authenticate(true)` directly. Helpers hide others: the 3 geo routes were `member` by that rule and are `create` in the built code, so I took the built truth for the 21 built rows. For the 192 planned rows the label is a guess for the 73 non-public routes whose handler has no direct `api_authenticate(` call; it does not affect behaviour, because every placeholder uses the non-creating check.
- Placeholders never create a member, so where PHP's route would, a first-time caller gets 404 `User not found` (not 501). A placeholder still records the sign-in (a write on `users`, as every member route does).
- Catalog parameter names are PHP's; the built routes use camelCase names. Tests compare shapes (`{}`).
- Route-order: PHP's first-match order and ASP.NET's literal precedence agree on all 8 overlapping pairs (all literal before parameter), so nothing needed reordering; a test pins it.

## Tests first, and where not
Route table, 404/405, placeholder and gateway tests were written and seen failing before the implementation. `PlannedRoutesTests` (db) and the Hurl file were written after it.

## Open
- Bodyless POST/PUT through the gateway answers 400 from the proxy (HTTP/1.0 to Kestrel, no length); seen with the 501 placeholders, probably already true of built routes. The Hurl file sends `{}`. Not investigated.
- ASP.NET matches paths case-insensitively and tolerates a trailing slash; PHP does not. Pre-existing, unchanged.
- Verified at build time only: nginx accepted the new config (the gateway container restarted healthy).

# Fix round (S2 after QA, 2026-11-10)

Scope: QA M1, M4, L1, the two guards, and recording U1 to U3. Not touched: L2 (truncate before the exports succeed), L3 (unbounded row-by-row retry), M2, M3.

## What changed
- `test/prove-synthetic.sh` no longer has a target of its own: `TSR_DST_CLIENT` is required, and `test/require-synthetic.sh` (new) refuses first unless no `identity.users` row has an empty email or one not ending `.invalid` (a count is printed, never a value). Header and README say it is destructive and that the dev database may hold real data.
- `load.sh --truncate` prints the client command, current database and total rows, then needs the typed database name at a terminal or `--yes-truncate <database>`; otherwise refuses. A target with no rows needs no confirmation. `--yes-truncate` without `--truncate` is an error.
- The report: a header with the source zone (and "the default" when it was); the RESULT line is built by `load.sh` and is identical in stdout and file. `LOAD INCOMPLETE` names failed domains, every target table with no loaded rows (the split `users` targets included) and the rejected count. Merge tables now count refused rows as rejected, not skipped (`00-engine.sql`). The old `NOT LOADED` line is part of RESULT.
- A failed domain keeps `staging` and the report says so, with the drop command. `--retry <domain>` (new) loads only the failed domains from staging, re-counts orphans and reports again; the failed list and the zone live in `staging.run_info`.
- `php-parity-feedback.md`: "Found by review, 2026-11-10" (U1 to U3).

## Tests (`test/prove-guards.sh`, new; throwaway target only)
Written before the code. Seen failing first: the guard script step failed with "No such file" before `require-synthetic.sh` existed; step 2 failed against the old `load.sh` ("--truncate without confirmation exited 0": it truncated). For the report steps I ran the old `load.sh` (copied aside) with a trigger that fails the membership domain and one that rejects a merge row: its RESULT read "every exported row was loaded", `member_profiles` was not named, the rejected permission was counted as "skipped", and there was no zone line. I did not run the old `prove-synthetic.sh` (it was hard-wired to the dev database). Then all steps pass; `prove-synthetic.sh` passes on the throwaway target (`PROVE_TRUNCATE=1`).

## Assumptions and open
- A rejected row still exits 0 (README: "reported, never a failure" kept); only the RESULT text changed. Say if a rejection should exit 1.
- NULL email counts as non-synthetic in the guard (the synthetic data has none).
- The retry only accepts domains that failed in the first run; after a retry that still fails, staging stays.
- Failure injection uses a trigger that raises SQLSTATE 57014 (the engine re-raises 57xxx), the only way found to make a domain fail without editing the source.
