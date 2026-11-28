# tools/data-load: MariaDB to PostgreSQL

Moves the member data of every ported table from the PHP database into the new schemas, in one command. Proven on synthetic
data only (`test/prove-synthetic.sh`, `test/prove-guards.sh`). You run it against the real database yourself; the report holds counts, never row values.

## Before you run it
1. **Migrate the target.** `hosts/api` with `--migrate` on an empty PostgreSQL (eight domain schemas). Do not run the seed.
2. **Bring the source up to date.** Production is migrated, so it has `class_scheduled_notifications` and
   `class_scheduled_notification_runs`, and the calendar's `class_scheduled_events` and `member_event_settings`; a source without a table in `tables.txt` stops the load with its name.
3. **Quiesce the source** (restore a backup into a scratch MariaDB, or stop the writers). The load counts each table, exports it
   and compares: a table written to in between stops the load.
4. **Clients.** One MariaDB client and one `psql`, on the host or inside a container. Nothing is installed by the script.

## Run it
Connection settings come from the environment: two client COMMANDS (host, user, database inside them) and the passwords as
environment variables, never arguments.
```
export MYSQL_PWD=...      # read by the mariadb client
export PGPASSWORD=...     # read by psql
export TSR_SRC_CLIENT="mariadb -h SOURCE_HOST -u SOURCE_USER SOURCE_DB"
export TSR_DST_CLIENT="psql -h TARGET_HOST -U TARGET_USER -d TARGET_DB"
tools/data-load/load.sh [--truncate [--yes-truncate DBNAME]] [--keep-staging] [--source-tz ZONE] [--report-dir DIR]
tools/data-load/load.sh --retry 30-membership      # after a failed domain, see below
```
Through containers, pass the variable NAME so the value stays out of the process list:
`TSR_SRC_CLIENT="docker exec -i -e MYSQL_PWD <mariadb container> mariadb -u... <db>"`, and the same with `-e PGPASSWORD` for psql.

- Without `--truncate` the load refuses a target whose tables hold rows (it lists the tables and counts). `--truncate` empties the
  50-odd target tables first, but only after it prints the target (client command, current database, total rows in the target tables: counts only)
  and gets a confirmation: you type the database name at the terminal, or pass `--yes-truncate <database name>` (it must equal the target's current
  database). No terminal and no `--yes-truncate`: it refuses. A target with no rows needs no confirmation. Four tables that the EF migrations seed (`access.permissions`, `access.role_permissions`,
  `membership.interest_options`, `platform.lookups`, marked `merge` in `tables.txt`) are never emptied: see "merge" below.
- `--source-tz` is the zone of MariaDB `datetime` columns (a name such as `Asia/Kolkata`; default UTC). **Confirm it before the
  real run**: design decision 2 needs the owner's answer for the PHP server. `timestamp` columns are always exported in UTC.
- Staging (`staging` schema, all-text copies) is dropped at the end unless `--keep-staging`. Staging holds real data while it
  exists: drop it yourself if the run is interrupted (the next run refuses to start while it exists).
- Exit status 0: no domain failed and every target table was loaded. Rejected rows and orphans do not change the exit status, but a rejected row
  makes the RESULT line say `LOAD INCOMPLETE` (read it, not only the exit status). 1: refused, or a domain failed (that domain is rolled
  back whole; the others are loaded) or a table was not loaded.
- **A domain failed:** the report ends `RESULT: LOAD INCOMPLETE: domains failed (rolled back): 30-membership; target tables not loaded (...)`, naming every
  target table that has no loaded rows (a split source such as `users` is named per target: `identity.users`, `access.user_roles`,
  `membership.member_profiles`). Schema `staging` is KEPT, because it holds the source data (real member data on a real run) and the failed domain
  needs it. Fix the cause (the error is printed above the report), then `load.sh --retry 30-membership` (several: comma separated; same client
  environment; the first run's `--source-tz` is remembered and a different one is refused). The retry loads only the failed domains from staging,
  re-counts the orphans and writes a new report; it drops staging when nothing is left to fix. Do not use `--truncate` to start over unless you mean
  to wipe the domains that did load. Without a retry, drop the kept schema by hand: `drop schema staging cascade`.

## What it does
Per source table: reads the column list from `information_schema`, exports PostgreSQL COPY text with `mariadb` (backslash, tab, newline
and carriage return escaped; NULL is `\N`; an empty string stays empty; `SET time_zone='+00:00'`), streams it into
`staging.<table>` (all `text`), and checks the staged count against `count(*)` of the source. `sql/10..80` then load one domain per
transaction, converting by the TARGET column's type: `datetime` (source zone) and `timestamp` (UTC) to `timestamptz`, wall-clock columns
(`timestamp`, `time`, `date`) unchanged, `tinyint` to `smallint` or `boolean` as the target is, enum and SET as their text, `bit(1)` to boolean,
JSON as the target keeps it (`jsonb`, or text with `IS JSON`). `users` is split into `identity.users`, `access.user_roles` (only
`roleid <> 0`) and `membership.member_profiles` (name cut to 200, picture to 2000, counted). Identities continue at max(id)+1. Then
the logical references are counted (`sql/90-orphans.sql`) and the report is printed and written to `build/data-load/report-<UTC time>.txt`
(git-ignored).

## Reading the report
- `src` rows in the source table. `filtered` rows left out by design (`access.user_roles` skips `roleid = 0`). `loaded`. `rejected`: refused by
  the target, detailed below (merge tables too). `skipped` (merge tables only): the migration's seed row was kept. src = filtered + loaded + rejected + skipped.
- `rejected`, reason `<SQLSTATE> [constraint X] [column Y]`: that whole row was NOT loaded. `23514 constraint ck_*_length` a value longer than its
  limit (never cut silently); `23502 column X` NULL in a required column (a zero date in one is also `zero_date_in_required_column`); `23505` a duplicate key
  (note `citext` is stricter than MariaDB's collation on accents and trailing spaces); `22P02`/`22003`/`22007` a value that does not convert or is out of range
  (for example `account_deletion_requests.id` is `integer`, PHP's was `bigint unsigned`). The reject path loads the other rows one by one, so a table with
  rejects loads slower.
- `zero_date_set_null`: `0000-00-00` (or a zero month or day) in a nullable column, loaded as NULL. `invalid_json_set_null`: text that is not valid JSON
  in a nullable JSON column, loaded as NULL (`invalid_json_in_required_column`: the row is rejected). `truncated_to_N`: the two decided cuts.
- `seed_value_differs_kept_target`, per column (merge tables): the migration's seed row and the source row differ in that column; the seed row stays.
  `created_at` differs by design (the migration's clock). Look at any other column.
- Orphans: rows whose logical reference names nothing (`class_students.class_id` with no class, a `token` with no user). NULL is not counted;
  `0` is looked up like any value (guests hold token 0). `member_profiles.language -> languages` counts `0` ("not set") in PHP: expect a large number.
  The list of references is `sql/90-orphans.sql`, not every one of the 112 token columns.
- The first lines give the source zone (`--source-tz`), and say when it was the default; the same two lines head the saved file. A wrong zone shifts
  every `datetime` column without any other sign.
- The `RESULT` line (stdout and file, identical) says whether every row was loaded: `LOAD INCOMPLETE` names the failed domains, the target tables not
  loaded and the rejected row count. Below it: whether staging was kept, and how to retry or drop it.

## Known gaps
- Not loaded, with no source table: `assessment.quiz_state` (PHP keeps the quiz competition's state in JSON files, not in MariaDB; it needs its own import).
- Not loaded: the 15 leave-behind tables, `class_access`, `calendar_table`, `geo_*` (GeoNames load), the 8 unread `users` columns, `account_deletion_requests.active_token`
  (a generated column in PHP; the partial unique index replaces it), `teacher_training*`, `surveys` (not in any dump; unverified in production).
- PHP triggers and `ON UPDATE CURRENT_TIMESTAMP` are not ported (the load copies the stored values).
- Merge tables keep PostgreSQL-only seed rows (for example the permission added after PHP's seed); they are not synchronised with the source.
- A NUL byte in a text value cannot be stored in PostgreSQL; a table with one fails its export check. Not seen in synthetic data.
- Real data will show values the synthetic set lacks. Expect one or two rounds of fixing from the first report.
- Nothing yet reads `staging.report` automatically in CI: the proof is `test/prove-synthetic.sh`, run by hand.

## Proof (synthetic only)
**Run these only against a throwaway, synthetic PostgreSQL.** The dev database may hold real member data. `test/prove-synthetic.sh` and
`test/prove-guards.sh` truncate and reload their target, which comes from `TSR_DST_CLIENT` with no default, and both start by running
`test/require-synthetic.sh`, which refuses a target holding any `identity.users` row whose email does not end in `.invalid`, except a bulk-add placeholder (`<own token>@thestrongrope.com`, token 900000 or above) (it prints a count only).
`prove-guards.sh` tests that refusal, the `--truncate` confirmation, the zone line, the failed-domain result and the retry, and the merge-table reject.

`tools/parity-php/s2-source.sh` builds the scratch source `tsr_synth_s2` in the parity stack; `test/prove-synthetic.sh` loads it into the throwaway target in `TSR_DST_CLIENT`
(migrated, synthetic only) and runs the checks: counts, `test/assert.sql` (values per type class), `test/reject.sql` (the reject path, rolled back), orphan counts against
the source, the refusal, `--truncate`, `--source-tz` (`test/assert-tz.sql`).
