# tsr-account: workload shape for a document-database decision

Read-only grep and script audit, 2026-11-10. Nothing was run against a database, and tsr-account was not edited.
This records facts only. It makes no recommendation.

**Scope:** `tools/synthetic-data/schema.sql` (1,349 lines); `web/models/*.php` (43 files) and `web/api/**/*.php` (46 more PHP files, 89 total in scope, vendor excluded). `web/api/mobile/routes/` holds 36 route files.
The existing syntax audit (`docs/specs/db-portability/mysql-to-postgres.md`) is not repeated here. This file covers shape: relations, joins, aggregates, transactions and filters.

**Approximate counts:** most SQL counts are grep hits. They include SQL comments, PHP string text and PHP function names (for example `join(`). Counts marked "approx" come from `/private/tmp/claude-501/-Users-asifshakir-Projects-tsr-app/3c358743-ba64-4b12-9b64-be1e04150aa4/scratchpad/sqlshape.py`, which windows each `SELECT` up to the next `SELECT` or 3,000 characters. Treat those as order-of-magnitude.

## 1. Schema (tools/synthetic-data/schema.sql)

Grep used: `grep -ciE '^\s*CREATE TABLE'`, `grep -ciE 'FOREIGN KEY'`, `grep -nE 'UNIQUE KEY'`, `grep -ciE 'CREATE\s+TRIGGER'`, `grep -ciE 'CREATE\s+PROCEDURE'`, `grep -ciE 'CREATE\s+(OR REPLACE\s+)?VIEW'`.

| Object | Count | Notes |
|---|---|---|
| Tables | 68 | All InnoDB, utf8mb4. One `PRIMARY KEY` per table (68 hits). |
| Foreign key constraints | 10 | On 8 tables. `feedback` 2, `user_permissions` 2; `class_access_rule_conditions`, `notifier_sent_messages`, `role_permissions`, `student_interests`, `syllabus`, `user_notifications` 1 each. |
| UNIQUE KEY declarations | 12 | Lines 32, 509, 575, 599, 630, 676, 756, 884, 1012, 1241, 1257, 1323. |
| Generated column | 1 | `active_token` (line 30, STORED) backs a unique key for the one-live-request rule. |
| Triggers | 0 | |
| Stored procedures | 0 | |
| Views | 1 | `class_access_from_rules` (line 126). |

Migrations: `migrations/` holds 66 SQL files that create 24 distinct tables by name. `schema.sql` is the snapshot used here.

Most-wide tables by column count (awk over `CREATE TABLE` blocks): `users` 35, `class_sessions` 30, `class_registrations` 29, `classes` 27, `spot_quizzes` 21.

Note: 60 of 68 tables have no declared FK. Most links between tables are plain `token` or `*_id` columns that the application joins on.

## 2. Query shape in web/models and web/api

Grep used: `grep -rIE '<pattern>' web/models web/api --include='*.php'`, with `-i` where noted. Counts are occurrences, then the number of files that contain at least one.

| Feature | Occurrences | Files | Top files (occurrences) |
|---|---|---|---|
| `JOIN` (raw word) | 399 | 27 | `mis.php` 173, `classes.php` 45, `classstudents.php` 35, `subscribers.php` 18, `guardians.php` 18 |
| `JOIN` followed by a table name (refined, approx) | 145 | n/a | `mis.php` 78 |
| `LEFT JOIN` | 69 | n/a | |
| `INNER JOIN` | 233 | n/a | |
| `GROUP BY` | 105 | 13 | `mis.php` 65, `classstudents.php` 9, `subscribers.php` 8, `mcq.php` 6 |
| `COUNT(` / `SUM(` / `AVG(` | 398 | 37 | `mis.php` 180, `quizadmin.php` 31, `classstudents.php` 23, `mcq.php` 20 |
| `(SELECT` subqueries (approx) | 113 | n/a | `mis.php` 6 by line grep |
| `SELECT` statements (approx, script) | ~505 | n/a | |
| `UNION` | 12 | 6 | `teachers.php`, `permissions.php`, `classes.php`, `mis.php`, `quizadmin.php`, `subscribers.php` |
| `LIKE` (raw word, includes comments) | 56 | 20 | `classstudents.php` 16, `permissiongrants.php` 7, `location.php` 6 |
| `beginTransaction` | 24 | 12 | `classes.php`, `classstudents.php`, `mcq.php`, `teachers.php`, `sessions.php`, `guardians.php` and others |
| `->commit(` | 24 | n/a | |
| `rollBack` | 32 | n/a | |

Largest joins (script window; the first was read and confirmed, the others were not read):

| Example (file:line) | Tables in one statement | Notes |
|---|---|---|
| `web/models/mis.php:1752` | 6 | `class_attendance` plus five `inner join` (class_sessions, classes, class_levels, users, genders). Read and confirmed. |
| `web/models/mis.php:2807` | 5 (approx) | Script reports 5 `JOIN` keywords in its window. Not read. |
| `web/models/teachers.php:212` | 5 (approx) | Script reports 4 `JOIN` keywords in its window. Not read. |
Script: 183 SELECT windows (approx) contain at least one table JOIN; maximum 5 JOIN keywords, so 6 tables.

## 3. web/models/mis.php (reporting model)

| Measure | Value |
|---|---|
| Lines | 3,464 (`wc -l`) |
| Functions | 80 (`grep -cE 'function '`) |
| `SELECT` tokens | 120 |
| `SELECT` statements containing `JOIN` or `GROUP BY` (approx, script) | 90 of 120. 67 with `JOIN`, 57 with `GROUP BY`. |
| `COUNT(` / `SUM(` / `AVG(` | 180 occurrences (145 lines) |
| Subquery `(SELECT` | 6 |
| Transactions | 0 |

## 4. Document-like versus many-to-many tables

Judged from column lists and FKs in `schema.sql`. Document-like means a parent with child rows that are normally read together. Named tables only; not exhaustive.

Document-like (parent with children), up to 10:

1. `classes` with `class_sessions` and `class_attendance` (attendance under session).
2. `class_access_rules` with `class_access_rule_conditions` (FK enforced).
3. `spot_quizzes` with `spot_quiz_questions` and `spot_quiz_responses` (response unique on question plus token).
4. `standard_mcqs` with `standard_mcq_questions`.
5. `class_events` with `class_events_phases`.
6. `traditions` with `traditions_verses`.
7. `notifier_runs` with `notifier_sent_messages` (FK, ON DELETE CASCADE).
8. `class_schedules` with `class_schedule_topics`.
9. `quiz` with `quiz_questions` and `quiz_responses`.
10. `users` with `user_devices`.

Many-to-many or link tables, up to 10:

1. `class_students` (class to student, with status and removal fields; 14 columns).
2. `class_tags` (composite PK `class_id, tag_id`).
3. `user_guardians` (parent_token to child_token, self-referencing users; 13 columns).
4. `user_permissions` (user to permission, FK both sides).
5. `role_permissions` (FK to `permissions.name`).
6. `student_interests` (token to `interest_options`, FK).
7. `user_notifications` (user to notification, FK).

Only seven link tables were verified by reading columns. `class_registrations_languages` and `class_access` look like link tables but were not read. Document-like tables 1-10 are judged from names and column lists, not from query code.

## 5. Ad-hoc filtering on list screens

Optional filters built as `$where[]` or `$filter .=` only when a value is set. Examples (file:line):

1. `web/models/classes.php:800-812` (`listForUser`): optional `level`, `language`, and free-text `q` (`LIKE` on `code` and `name`), plus a managed-reach clause.
2. `web/models/auditlog.php:141-150` (`filters`): optional `since`, `token`, and `page LIKE`.
3. `web/models/guardians.php:1000-1010`: gender scope, then an optional parent-or-child token match.

Other places with the same pattern: `web/api/mobile/routes/classes.php:456-460` (optional start and end date on a chosen column), `web/models/classstudents.php:1009-1013` (optional date range appended to a filter string), `web/models/mis.php:115-135` (`setDashboardLocations`: selected location buckets are ORed, then ANDed into the class filter).

Search is separate: `web/models/search.php` runs a planned, per-kind search; `web/models/searchfilter.php:48` (`toEs`) translates filters to an Elasticsearch-style query. The search model is not a SQL list filter.

Count of conditional filter-append sites (`$where[] =` or `$filter .=` pattern, grep): 16 across 7 files (`guardians.php` 3, `classes.php` 3, `auditlog.php` 3, `classstudents.php` 2, `classaccess.php` 2, `mobile/routes/classes.php` 2, `mis.php` 1).

## Method and limits

- Grep counts include SQL comments, PHP strings and PHP function names. `LIKE` and `JOIN` are the noisiest.
- The SELECT-window script (approx) cuts each statement at the next `SELECT` or 3,000 characters, so it can run into PHP code after a query.
- No database was connected. No real member data was read; schema column names were read, not row data.
