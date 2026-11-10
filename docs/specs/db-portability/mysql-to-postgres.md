# tsr-account: MySQL/MariaDB to PostgreSQL portability

Read-only grep audit, 2026-11-09. Nothing was run against a database, and tsr-account was not edited.

**Scope:** `web/**/*.php` (215 files, vendor excluded), `migrations/*.sql` (66 files), `tools/synthetic-data/schema.sql`.
Counts are occurrences in scope and include SQL comments unless stated. Trigger sources in `DB/` are outside scope and are cited only because they were named.

**Effort key:** Trivial = delete or rename. Mechanical = rewrite by pattern, with tests. Needs thought = a design decision or a data or behaviour change.

## Syntax features

| Feature | Count (files) | Examples (file:line) | Effort | Notes |
|---|---|---|---|---|
| Backtick identifiers | 5,248 (125) | `migrations/2026_08_21_lookups_table.sql:53`; `web/models/classes.php` | Mechanical | Split: 1,396 in 82 PHP files, 1,372 in 42 migrations, rest in schema.sql. Quoting is only needed for reserved words. |
| `ON DUPLICATE KEY UPDATE` | 3 (2) | `web/models/classes.php:317`, `:402`; `web/models/guides.php:39` (uses `VALUES()`) | Mechanical | `ON CONFLICT (cols) DO UPDATE SET c = EXCLUDED.c`. Conflict target must be named per call site. |
| `INSERT IGNORE` | 5 (3) | `migrations/2026_08_21_lookups_table.sql:53`, `migrations/2026_08_22_seed_languages.sql:25` | Trivial | Only 2 real statements; the other hits are comments. Becomes `ON CONFLICT DO NOTHING`. |
| `REPLACE INTO` | 0 | | | |
| `LIMIT x, y` (offset form) | 0 | | | `LIMIT ... OFFSET ...` is used instead and is portable. |
| `GROUP_CONCAT` | 11 (2) | `web/models/mis.php:2046`, `:2060`, `:2064`; `web/cli/find_student.php` | Mechanical | `string_agg(x, ', ' ORDER BY ...)`. `DISTINCT` plus `ORDER BY` needs care. |
| `IFNULL` | 51 (2) | `web/models/mis.php:2357-2359`; `migrations/2026_09_06_reviewer_demo_cohort.sql` | Trivial | `COALESCE`. |
| `IF(` | 8 (3) | `web/models/mis.php:857`, `:1886-1887`; `migrations/2026_09_06_reviewer_demo_cohort_teardown.sql` | Mechanical | `CASE WHEN`. Some are built inside PHP strings. |
| `CONCAT_WS` | 0 | | | |
| `DATE_FORMAT` | 2 (1) | `web/models/mis.php:1882`, `:2545` | Mechanical | `to_char` with format tokens remapped. |
| `STR_TO_DATE` | 0 | | | |
| `DATE_ADD` / `DATE_SUB` / `INTERVAL` | 33 (2) | `migrations/2026_09_06_reviewer_demo_cohort.sql:246`; `web/models/mis.php:1194` | Mechanical | `CURRENT_DATE - INTERVAL '9 weeks'`. |
| `NOW()` | 269 (12) | `web/models/classes.php` (9 uses); `web/models/training.php:140` | Trivial | Works unchanged in PostgreSQL. |
| `CURDATE()` | 33 uses (2) | `web/models/mis.php:2599`; reviewer-demo migration | Trivial | `CURRENT_DATE`. |
| `UNIX_TIMESTAMP` | 1 (1) | `web/models/reminderschedule.php:114` | Mechanical | `EXTRACT(EPOCH FROM ...)`. |
| `FROM_UNIXTIME` | 0 | | | |
| `FIND_IN_SET` | 0 | | | |
| `REGEXP` | 11 (2) | `web/models/mis.php:2442`, `:2444`; `web/cli/find_student.php` | Mechanical | `~` or `~*`. Test patterns: MySQL 8 and PostgreSQL regex syntax differ. |
| `LAST_INSERT_ID()` / `lastInsertId()` | 25 (1 migration); 15 (11 PHP files) | `web/save_spot_quiz.php:62`; `web/models/classes.php`; `migrations/2026_09_06_reviewer_demo_cohort.sql:248` | Mechanical (PHP), needs thought (migration) | PHP: `INSERT ... RETURNING id`. PDO pgsql `lastInsertId()` needs a sequence name. |
| `SQL_CALC_FOUND_ROWS` / `FOUND_ROWS()` | 3 (3) | `web/models/sessions.php:36`, `:47`; `web/models/quranrecitation.php:33`, `:93`; `web/models/mcq.php:507`, `:531` | Needs thought | Replace with a separate `COUNT(*)`, or `COUNT(*) OVER()` (which returns no total on an empty page). |
| `FORCE INDEX` / `USE INDEX` | 0 | | | |
| `UNSIGNED` | 2 (2) | `migrations/002_create_admin_access_log.sql:5`; `migrations/2026_05_06_create_class_audit_log.sql:7` | Mechanical | `bigint` plus a `CHECK`. |
| `TINYINT(1)` as bool | 2 (2) | `migrations/2026_08_21_lookups_table.sql:46`; `migrations/2026_10_09_geo_countries.sql:19` | Needs thought | `boolean`. PDO pgsql returns booleans as `'t'`/`'f'` strings (verify), so PHP `=== 1` checks would break. |
| `ENUM(` | 5 (3) | `migrations/2026_11_05_user_guardians.sql:22-24` | Mechanical | `text` plus `CHECK`, or a PG enum type. |
| `AUTO_INCREMENT` | 76 (16) | `migrations/002_create_admin_access_log.sql:5` | Mechanical | `GENERATED ... AS IDENTITY`. Sequences must be reset after data load. |
| `ENGINE=InnoDB` | 89 (18) | `tools/synthetic-data/schema.sql` (every `CREATE TABLE`) | Trivial | Delete. |
| `CHARSET` / `COLLATE` | 108 / 105 (21) | `utf8mb4_unicode_520_ci` (95 uses), `utf8mb4_bin` (7), `utf8mb4_unicode_ci` (1), `utf8mb4_0900_ai_ci` (1) | Needs thought | PostgreSQL has no `_ci` collation. See implicit behaviours. |
| `JSON_EXTRACT` / `->>` | 0 | | | |
| `MATCH ... AGAINST` | 0 | | | |
| User variables `@var :=` | 11 (2 migrations) | `migrations/2026_09_06_reviewer_demo_cohort.sql:66`; `migrations/2026_09_06_reviewer_demo_cohort_teardown.sql:59` | Needs thought | Rewrite as a `DO` block or a CTE. |
| `STRAIGHT_JOIN` | 0 | | | |
| Zero dates `'0000-00-00'` | 5 (3) | `web/api/mobile/lib/response.php:99`, `:108`; `web/api/mobile/routes/whatsapp_reminders.php:17` | Needs thought | PostgreSQL rejects this literal. Stored zero dates must become NULL during data load. |
| `information_schema` (MySQL-style) | about 8 migrations | `migrations/2026_08_10_normalise_collation_preflight.sql:36` | Needs thought | Maintenance scripts. Rewrite against the PG catalog, not ported. |
| `SET NAMES utf8mb4` | 1 (1) | `web/functions.php:560` | Trivial | `client_encoding`. |
| PDO DSN `mysql:` | 1 (1) | `web/functions.php:552` | Mechanical | `pgsql:` DSN. `ATTR_EMULATE_PREPARES => false` can stay. |
| `SET SESSION group_concat_max_len` | 1 (1) | `web/models/mis.php:3227` | Trivial | Delete. PostgreSQL `string_agg` has no limit. |

## Triggers, procedures, functions, events

No stored procedures, functions or events exist in scope. The only routines are three `BEFORE INSERT` triggers. Each one overwrites the table's code column with a random base-36 string and retries until unique.

| Trigger | Table | Source | Summary |
|---|---|---|---|
| `classes_before_insert` (named `classes_before_create` in schema.sql) | `classes` | `DB/classes.sql:26`, `DB/class_trigger.sql:2`, `tools/synthetic-data/schema.sql:476` | Sets `NEW.link` to a random 10-char base-36 value, retrying until unused. Overwrites any value the app supplies. |
| `spot_quizzes_before_insert` (named `mcq_before_insert` in `DB/`) | `spot_quizzes` | `tools/synthetic-data/schema.sql:936`, `DB/mcq_trigger.sql:2` | Sets `NEW.code` to a random 8-char base-36 value, retrying until unique. This is the "mcqs" trigger. `standard_mcqs` has no trigger. |
| `surveys_before_insert` | `surveys` | `DB/surveys.sql:16` | Sets `NEW.code` to a random 10-char base-36 value. The `surveys` table is not in the synthetic schema. |

Porting: each becomes a PL/pgSQL function plus trigger. `RAND()`, `CONV()` and `POW()` have no direct equivalent, so the base-36 generator needs a small helper. The name drift (`classes_before_create` vs `classes_before_insert`, `spot_quizzes_before_insert` vs `mcq_before_insert`) should be settled first.

## Implicit behaviours to flag

1. **Case-insensitive matching (high risk).** The `_ci` collations apply to nearly all text columns. `users.email` is one of them.
   - `web/models/subscribers.php:95` and `:161`: `WHERE email = :email`, with the Firebase email passed through without lowercasing.
   - `web/api/mobile/lib/auth.php:294`: `UPDATE users ... WHERE email = :email`.
   - `migrations/2026_09_06_reviewer_demo_cohort_teardown.sql:59`: `LIKE '%@demo.invalid'`. MySQL `LIKE` is case-insensitive; PostgreSQL `LIKE` is not.
   - Fix options: `citext` or ICU nondeterministic collations, plus `LOWER()` at boundaries. This is a product decision, because it changes login matching.
2. **`GROUP BY` with non-aggregated columns (medium).** 62 `GROUP BY` lines in 10 PHP files. Several comments show these were fixed for `ONLY_FULL_GROUP_BY` (`web/models/subscribers.php:448`, `web/models/classstudents.php:1232`, `:1365`). Other queries may still rely on lax mode. PostgreSQL is strict, so grep cannot prove these are clean.
3. **String and number comparisons (medium, review only).** MySQL coerces `'' = 0` to true, and PostgreSQL raises an error. No SQL-level case was found. The only `'0'` sentinel found is in JavaScript at `web/class_subject_conduction_report.php:615`.
4. **Booleans as `TINYINT(1)`.** PHP code that tests `=== 1` or `== '1'` will need changes (see the table).
5. **Zero dates.** Relied on as sentinels in `web/api/mobile/lib/response.php`. These need data cleaning before the move.

## Estimate: MEDIUM

The syntax surface is small: no `REPLACE INTO`, full-text, JSON, `STRAIGHT_JOIN` or `FORCE INDEX`. Most rows are mechanical, and `NOW()` already works.

The reasons this is not "small, about a week":

- **Collation semantics.** Case-insensitive matching is a behaviour change across login and lookups, and it needs a decision, not only a rewrite.
- **Concentration.** `web/models/mis.php` (over 3,000 lines) holds most of the MySQL-only functions: `IF`, `IFNULL`, `GROUP_CONCAT`, `REGEXP`, `DATE_FORMAT` and `CURDATE`, several built as PHP strings.
- **Write paths and triggers.** Eleven PHP files use `lastInsertId`, and three triggers need rewriting.
- **Data and history.** Zero dates and boolean columns need data work. The 66 migrations are MySQL DDL, so a PostgreSQL baseline has to be created.
- **Verification.** None of this was run. A real PostgreSQL test database with production-shaped data is required before any estimate is firm. A rough range is 3 to 5 weeks, which is a guess and not a measurement.
