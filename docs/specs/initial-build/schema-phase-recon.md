# Schema phase recon (2026-11-10)

Read-only recon for "port every remaining PHP table in one pass". Sources: tsr-account working tree at `ad0b8ab5`
(branch `docs/patrol-plan-ios-done`; `web/api`, `web/models`, `migrations/` and `tools/synthetic-data/schema.sql`
are identical to local `develop` `ed72cd98`; `origin/develop` `6b63b912` was not compared: unverified). The schema-only
dump `tools/synthetic-data/schema.sql`, the migration files (about 67 in `migrations/`, with rollback and preflight files) and the PHP code were read. No database, container or
`.env` was touched; no data was read except the aggregate row counts in the published `tools/synthetic-data/profile.json`.
Per-table facts: `schema-phase-tables.csv` (75 rows). "Unverified" marks what could not be confirmed.

## 1. Counts

| | Tables | Columns |
|---|---|---|
| In `schema.sql` | 68 (+1 view `class_access_from_rules`) | 702 |
| Created by migrations but missing from the dump (`class_scheduled_notifications`, `class_scheduled_notification_runs`, migration 2026_11_08) | 2 | 30 |
| **Verified tables** | **70** | **732** |
| Used only by dead code, not in dump or any migration (`teacher_training`, `teacher_training_history`): existence unverified | 2 | about 12 (inferred) |
| Named but unverifiable (`schema_migrations`, runner infra; `surveys`, named only in a trigger doc) | 2 | ? |

`schema.sql` is stale (lacks the two 2026_11_08 tables). Regenerate it from the migrations before the schema phase.

Of the 70 verified: **15 already ported in full** (112 columns), **2 partly** (`users`: 12 columns in `identity.users`, 14 in
`membership.member_profiles`, `roleid` in `access.user_roles`, 8 columns nowhere; `account_deletion_requests`: 6 of 14
columns), **53 remaining** (571 columns).

| Remaining 53 | Count | Meaning |
|---|---|---|
| To port | 36 (417 columns) | assessment 7, classes 16, content 1 (`holy_quran`), notifications 8, platform 4 (`admin_access_log`, `genders`, `languages`, `outbound_messages`) |
| Leave behind (no code reads them) | 15 | `age_ranges`, `book_chapters`, `class_events`, `class_events_phases`, `class_events_registration`, `notifier_settings`, `quiz`, `quiz_questions`, `quiz_registrations`, `quiz_responses`, `students`, `subjects`, `syllabus_legacy_2022`, `traditions`, `traditions_verses` (about 5,000 rows together) |
| Derived, do not load | 2 | `class_access` (grants now come from rules), `calendar_table` (regenerate with `generate_series`) |

Verified tables per proposed domain (done + remaining): identity 2, access 6 (5 done, `class_access` derived), membership 6 (5 done,
`students` left), classes 22, assessment 11, content 4, notifications 9, platform 10 (5 done), search 0 (it keeps no table:
indexes are fed from `outbound_messages` on a `search` channel). Tables read by two or more domains (derived from which model, hence which domain, queries them; marked `MULTI (domains)` in the CSV): 20, plus `users` (all nine):
`class_access`, `class_attendance`, `class_levels`, `class_registrations`, `class_schedules`, `class_sessions`, `class_students`, `class_tags`, `classes`, `feedback`, `genders`,
`guides`, `outbound_messages`, `spot_quiz_questions`, `spot_quiz_responses`, `spot_quizzes`, `standard_mcqs`, `tags`, `teachers`, `user_devices`.
`class_scheduled_notifications` and `quiz_campaigns` are single-model but point at another domain through ids or ownership (section 3).

**`users` column split (`USERS-SPLIT` in the CSV notes): 29 tables.** 83 SELECT statements in 17 PHP files (`mis.php` 26, `classes.php` 11, `classstudents.php` 11, `guardians.php` 8,
`teachers.php` 5, `subscribers.php` 4, ...) join `users` and read a column that moves to `membership.member_profiles` (`name` is by far the most read, then `gender`, `mobile`, `city`, `country`)
or to `access.user_roles` (`roleid`: `mis`, `classaccess`, `permissiongrants`, `permissions`). 18 of them read `users.gender` and sit on `classes` (8), `class_students` (6), `teachers` (6),
`user_guardians` (4), `class_levels` (3), `class_registrations` (2), `user_devices` (2), `class_access` (1): this is the gender-segregation scope, and after the split every one needs a
membership read interface (gender by token) instead of a join. Tables keyed by `users.id` rather than `token` (the id stays in identity): `feedback`, `user_permissions`, `admin_access_log`,
`class_scheduled_notifications.created_by_user_id`, `membership.member_profiles.user_id`, `access.user_roles.user_id`. Per statement: the other tables are listed per table in the CSV note.
24 of the 75 rows are not used by the API (the 15 above, 3 notifier tables reached only over HTTP by the node notifier, `quiz_campaigns`,
`languages`, `teacher_training*`, `schema_migrations`, `surveys`).

Scale (profile.json, aggregate): about 660,000 rows. Largest: `spot_quiz_responses` 237,000, `class_attendance` 228,000,
`spot_quiz_questions` 42,000, `spot_quiz_submissions` 34,300, `admin_access_log` 27,500, `users` 26,200, `class_sessions` 24,400. Full GeoNames adds 1.2 million (separate load, `tools/geonames/load.php`).

## 2. MariaDB to PostgreSQL type issues actually present

Counts are from `schema.sql` plus the two migration tables. `docs/specs/db-portability/mysql-to-postgres.md` covers SQL syntax; this covers schema.

| Feature | Count | Examples | Port rule |
|---|---|---|---|
| `enum` | 13 columns in 7 tables (+2 in migration table) | `class_audit_log.action`, `student_transfers.type`, `syllabus.link_type`, `class_scheduled_notifications.kind` | text + CHECK (9 done; 6 remain: `account_deletion_requests.source`, `class_audit_log.action`, `student_transfers.type`, `syllabus.link_type` and the two in the migration table) |
| `set` | 1 | `class_registrations.interests` (12 values with spaces and parentheses) | done: text + CHECK |
| json stored as `longtext` + `json_valid` CHECK | 6 columns (2 done as `jsonb`) | remaining: `class_audit_log.details`, `notifications.target_audience_criteria`, `notifier_runs.settings_snapshot`, `outbound_messages.payload` | `jsonb`; MariaDB already guaranteed validity |
| lists stored as CSV text | 4 | `notifier_reminders.levels`, `class_events.disallowed_levels`, `class_scheduled_notifications.weekdays`, `classes.extra_students` (free text, own plan doc) | keep text first; normalise later |
| `tinyint(1)` flags | 9 (+1 migration) | `class_access_rule_conditions.negate`, `interest_options.is_active`, `user_notifications.is_read` | `boolean` (4 done) |
| `tinyint(4)` flags in disguise | 8 | `class_attendance.present`, `class_students.mcq_admin`, `spot_quiz_responses.is_correct` | `smallint` until values are scanned; the JSON output must not change (unverified whether values other than 0/1 exist) |
| `bit(1)`, `binary(1)` | 1 + 3 | `spot_quiz_questions.is_arabic`, `calendar_table.isWeekday` | `boolean` |
| `char(1)` status or Y/N flags | 12 | `class_sessions.*_conducted`, `classes.status`, `class_students.status` | keep as text + CHECK |
| unsigned | 13 | 7 `bigint unsigned` ids, 4 `tinyint unsigned`, 2 `int unsigned` (notifier tables) | plain `integer`/`bigint`; no CHECK needed |
| zero dates | 0 in DDL; code treats `0000-00-00` as a sentinel in 3 files | `response.php:99,108`, `whatsapp_reminders.php:17`, `deactivated_classes.php:17` | load must turn them into NULL; scan the data (unverified, synthetic data may not contain any) |
| `ON UPDATE CURRENT_TIMESTAMP` | 4 (+1 migration) | `user_devices.last_accessed_at`, `syllabus.modified_at`, `notifier_reminders.updated_at`, `class_scheduled_notifications.updated_at` | set in the handler or a trigger; `user_devices` bumps on any UPDATE |
| `timestamp` vs `datetime` | 17 vs 110 | | `timestamp` is UTC; `datetime` is naive. Wall-clock columns (`class_scheduled_notifications.send_at`, `send_time`) must stay `timestamp without time zone`; the rest need a decision (question 2) |
| `AUTO_INCREMENT` | 59 (+2) | 59 of 68 tables | `generated by default as identity`; load keeps ids (they are referenced) then `setval(max(id))`; gaps are kept. Dump header uses `NO_AUTO_VALUE_ON_ZERO`: a row with id 0 is unverified |
| generated column | 1 | `account_deletion_requests.active_token` (STORED, unique) | partial unique index on `token` where status is live |
| triggers | 2 (+1 outside the dump) | `classes_before_create` sets `link`, `spot_quizzes_before_insert` sets `code`: random base-36, retried until unique, overwriting any given value; `surveys` trigger in `DB/` | PL/pgSQL function or do it in the slice; behaviour to copy: the supplied value is ignored |
| views | 1 (2 after the manual cutover) | `class_access_from_rules` joins access and classes tables | not ported; logic is `RuleMatcher` in C# |
| stored routines, events, fulltext, `ON DELETE` actions outside a domain | 0 | | none |
| collation | 68 tables `utf8mb4_unicode_520_ci`; 4 JSON columns `utf8mb4_bin`; 1 trigger variable | | see below |
| camelCase column names | 6 (`calendar_table`) | `monthName`, `isHoliday` | rename to snake case (or drop the table, it is derived) |
| mediumtext / longtext / text with no length | 18 columns (6 of them the json ones above) | `users.picture`, `book_chapters.arabic`, `feedback.message`, `guides.guide`, `class_students.notes` | citext with a chosen cap (decide per column; `platform.feedback.message` has no cap in the DB) |
| text-like columns in total | 217 (incl. the 6 json) plus 14 enum/set | | every one `citext` + `char_length` CHECK; geo columns ICU `geo_ci_ai` (done) |

Collation caveat: `utf8mb4_unicode_520_ci` ignores case AND accents AND trailing spaces (PAD SPACE). `citext` ignores case only.
Equality, unique keys and `LIKE` on the 12 unique keys (`lookups.type,code`, `interest_options.name`, `user_guardians.code`,
`notifier_reminders.name`, `outbound_messages.channel,dedupe_key`, `guides.level_id,language_id`, `feedback.user_id,client_id`, ...)
are stricter in PostgreSQL: harmless for a load (no new duplicates) but a different answer for a query like `city = 'Köln'`. Where it matters
today (classes `city`, `country` matched to access rules with `lcase()`) the rule is ASCII in practice (unverified on real data).
Only 12 unique keys exist besides primary keys (56 of the 68 dumped tables have none). Secondary indexes are many (migrations 2026_10_28 add several), so
index lists need their own pass per table.

## 3. Cross-domain foreign keys and contested ownership

**Declared FKs: 10, none still crosses a domain.** Three crossed (`feedback.user_id`, `feedback.handled_by`, `user_permissions.user_id`,
all to `users.id`) and were already dropped (platform migration `DropIdentityForeignKeys`; access). Seven stay (same domain): `class_access_rule_conditions`
to rules, `role_permissions` and `user_permissions` to `permissions`, `student_interests` to `interest_options`, `syllabus` to `class_levels`,
`user_notifications` to `notifications`, `notifier_sent_messages` to `notifier_runs`.

**Undeclared (logical) references, kept as plain integers with no FK:**
- To `users.token` or `users.id`: 112 columns in 49 tables (`token`, `token_no`, `created_by`, `teacher`, `parent_token`, ...). Same rule as today.
  `users.token` is not unique (1,729 accounts hold token 0), so a FK would not be possible anyway.
- Crossing a non-user domain: access to classes 3, assessment to classes 5, assessment to platform 4 (genders, languages), classes to platform 3,
  access to platform 1, membership to classes 1 (`class_registrations.for_classid`), notifications to classes 3, notifications to platform 2.
  Orphan counts on real data: unverified; the load check (section 4) should report them, not fail on them.

| Contested table or group | Options | Recommendation |
|---|---|---|
| `class_access` (table) and view `class_access_from_rules` | (a) access owns and ports both; (b) classes owns; (c) port neither, access matches rules in C# | **(c)**. `access.IClassScopes` and `RuleMatcher` already do it. Production may still hold the legacy table (cutover migration is on `withdrawn.list`, run by hand): verify, then drop the legacy grants (2,290 rows) |
| `class_levels`, `tags`, `class_tags` read by access, assessment, notifications, search | each reads a copy / classes publishes a read interface (as `IClassScopes`) / events | classes owns; others hold the id and ask a classes read interface (names, tags) |
| `genders`, `languages`, `age_ranges` | platform (lookups) / classes / membership | **platform**, as rows of `platform.lookups` (types gender, language, age_range); drop `age_ranges` (web only) |
| `class_students` (membership "students" vs classes "enrolment") | classes / membership | **classes** (domains table: enrolment). access reads it through `IClassScopes`; membership through `IClassEnrolments` |
| `outbound_messages` vs the new `platform.outbox` | keep both / merge / replace | platform owns (domains doc); keep it as the delivery queue for push, WhatsApp and search; the outbox stays the events table. Question 7 |
| `quiz_campaigns` (`campaigns.php` is listed under notifications) | notifications / assessment / leave behind | **assessment**; 3 rows read only by the web home page, so it can be left behind |
| `user_devices` (identity deletes it, notifications sends to it) | notifications / identity | **notifications**; identity erases through the erasure event (rule 11) |
| `class_attendance`, `class_sessions`, `holy_quran` (content's recitation leaderboard reads classes' tables) | content reads through classes / content copies | classes owns the attendance tables; content calls a classes read interface for recitation columns |
| `spot_quizzes` (assessment writes, classes shows counts on class cards) | classes counts via assessment interface / shared read model | assessment owns; classes asks for counts |
| `class_scheduled_notifications` (needs `classes`, written for a class) | notifications / classes | **notifications** (the worker and the limits are theirs); class and schedule ids are plain ints |
| `teachers`, `teachers_history`, training | classes / membership | classes (domains table) |

## 4. The data load

No MariaDB to PostgreSQL loader exists in either repo (grep for pgloader or PostgreSQL scripts: only a future-plans doc). Nearest precedent: `tools/access-catalog/export.sh` (runs `mariadb -N -B` inside the
parity stack's db container, writes PostgreSQL `insert` statements with `awk`).

**Per table, the script must:**
1. Load parents before children for the 7 same-domain declared FKs (`permissions`, `interest_options`, `class_access_rules`, `notifier_runs`, `notifications`, `class_levels`).
2. Rename nothing: table and column names are kept (only `calendar_table`'s camelCase columns would change, and it is not loaded).
3. Split `users` (35 columns): `identity.users` (id, token, email, provider, firebase_uid, createdon, lastlogin, lastloginip, lastdevice, device, platform, version);
   `membership.member_profiles` (user_id = users.id; name, first_name, last_name, picture, gender, age_range, mobile, country, state, city, zip, language, sendupdates,
   unsubscribe) first, because dropping `identity.users.gender` loses data otherwise (plan.md Checkpoint 4); `access.user_roles` only where `roleid <> 0`;
   drop `provider_id`, `region`, `lat`, `lng`, `timezone`, `browser`, `location_details`, `updated_at` (question 4). `name` cut to 200 and `picture` to 2,000 characters is
   data loss if longer: report `count(*) where char_length(picture) > 2000` first (unverified on real data).
4. Fill `account_deletion_requests` columns that exist only in PHP, after the migration adds them.
5. Convert types as in section 2: enum, SET to text; json to `jsonb`; `tinyint(1)` to boolean; zero dates to NULL; `datetime` per the timezone decision; `bit(1)` to boolean.
6. Keep `id` values (`overriding system value`), then `setval` each identity to `max(id)`.
7. Skip the 15 leave-behind tables, `class_access`, `calendar_table`; create `genders`, `languages` rows as `platform.lookups`.
8. Write nothing to the dev stack's database: `db/synthetic/seed.sql` uses tokens 900000+, the parity synthetic data uses tokens from 1; load into a scratch database.

**Reusable:** tsr-account `tools/synthetic-data/` (builds `tsr_synth` on MariaDB 11.4 in about 17 seconds at production size, row counts in `profile.json`);
tsr-app `tools/parity-php/` (compose project `tsr-parity`: MariaDB 11.4, the PHP API and `synth-build`, the only source DB allowed); `tools/access-catalog/export.sh`
(export pattern); `db/tests/TestDatabase.cs` (Testcontainers `postgres:18`, applies migrations); `db/synthetic/*.sql` (PG-side fixtures); `tools/geonames/load.php` (geo load, not from the member DB).

**Proof using only synthetic data:**
1. Build the parity synthetic MariaDB (`P --profile load run --rm synth-build`), export each table to TSV with `mariadb -N -B` (CSV-quote carefully; embedded tabs and newlines in `notes`, `comments`).
2. Run the new migrations on a scratch PostgreSQL 18, run the load script, then check per table: row counts equal (adjusting for splits and skipped tables); a hash of every column
   after canonical conversion on both sides (for example `md5(string_agg(row, '|' order by id))` with booleans, timestamps and json normalised); orphan counts for the logical references equal on both sides;
   each identity's next value is above `max(id)`; no CHECK or unique violation.
3. Add a small hand-written "nasty rows" fixture (synthetic): a zero date, a trailing-space duplicate, a mixed-case duplicate email, a 2,001-character picture, 4-byte emoji, `token = 0`,
   NULL vs empty string, a `set` value with a comma, an `enum` with an unlisted value. The generator probably produces none of these (unverified).
4. Run the existing Hurl contract files against the PHP stack and the new API on the loaded database: built operations only (identity, access, membership, platform); the rest answer 501 until filled.
5. Run the load twice (truncate then load) and compare. The real-data load is a later runbook; nothing real enters this repo.

## 5. The OpenAPI spec

- **Where:** one file, `tsr-account/web/api-docs.json` (316 KB, OpenAPI 3.0.3, `info.version` 1.0.0, "TSR Mobile API (PHP)"), generated 8 November by `tools/api-contract/generate_openapi.py` from the router
  (`web/api/mobile/index.php`) plus `tools/api-contract/contract.json` (308 KB; response fields recovered from Pydantic models and the Dart client). Not hand-written; served by `web/api_docs.php` behind `api-docs:read`.
  No other spec file exists. tsr-app has hand-written per-domain `spec/api.yaml` (OpenAPI 3.1) for access, content, membership, platform; identity has none.
- **Size: 191 paths, 211 operations** (as expected), 27 tags (first path segment, not domains), 164 component schemas, 117 path parameters.
- **Router match: exact.** 211 `[METHOD, path, file, function]` entries, 211 unique; none missing from the spec, none extra, and `operation-domains.csv` has the same 211. (By construction: the spec is generated from the router.)
- **operationIds:** 211 present, 211 unique, but they are PHP function names (`route_admin_access_log`), and `summary` is the function plus file name. Not usable as client method names; take names from `operation-domains.csv` slices.

| Check | Result |
|---|---|
| Operations with a described request body schema | **0 of 71** POST/PUT/PATCH (and 0 of the 140 others). 29 route files read a JSON body; the shapes sit in handler code |
| Operations with a 200 response schema that has properties | **164 of 211** (78%) |
| Only "Success", no schema | 47: 20 are file downloads (csv, xlsx, pdf), 27 are real gaps (`/feedback`, `/class-levels`, `/me/deletion-request` x3, `/classes/{id}/notifications/scheduled` x3, `/holy-quran`, `/health`, 6 `/mcq/*` reads, `/user/notifications` x3, `/me/children/*/link`, `/me/parents/*`, `/members/*/parent-links/*`, `/notifications/*` x2, `/admin/syllabus` x2, `/auth/debug-token`) |
| Described 200 schemas that are shallow | all 164 have properties, but 172 of 776 properties are `array` with no `items` and 60 are `object` with no `properties`; 0 schemas list `required`; 197 properties are nullable |
| Error responses | only 401 and 403 ("Registration incomplete"), on 207 operations; the 4 public ones list none. Handlers call `api_fail` with 404 (61), 409 (24), 422 (165), 429 (11), 400, 410, 500, 502, 503; no error body schema |
| Query parameters | 0 declared; 17 route files read `$_GET` (about 90 uses; `reports.php` alone 32, `classes.php` 14) |
| Shared component schemas | 164 schemas, one per operation, **none shared**: no Member, ClassCard, Error or Pagination |
| Source quality of the 164 shapes | `php-spec` 94, `php-route` 53, `pydantic` or `pydantic+dart` 12, `php` 1; but `dart-only` 13 and `NONE` 38 are what the Flutter client parses, not a server spec |
| Permissions, 201 and 204 statuses, rate limits | not described (permissions: `permission-map.csv`) |

**Gaps by domain** (operations / without a 200 schema / untyped array and object properties / write operations with no body schema / weak source):
access 13 / 0 / 30 / 5 / 1; assessment 43 / 10 / 32 / 15 / 11; classes 83 / 14 / 136 / 22 / 15; content 3 / 2 / 2 / 0 / 1; identity 10 / 4 / 6 / 7 / 5;
membership 24 / 6 / 8 / 6 / 3; notifications 25 / 8 / 7 / 13 / 12; platform 9 / 3 / 9 / 3 / 3; search 1 / 0 / 2 / 0 / 0.

**Verdict:** sufficient for the surface phase (route inventory, methods, paths, path parameters, an auth flag, 501 stubs, tag grouping). Not sufficient for generating typed request and
response models or clients: no request bodies, 27 empty responses, 232 untyped nested fields, only two error statuses, no query parameters, no shared types.
Hand-written per-slice schemas stay necessary (as in the four existing domains); treat `api-docs.json` as a skeleton, not a contract.

## 6. Open questions for the owner

1. **Leave-behind list.** 15 tables have no reader (rows are history or legacy; `quiz_responses` 3,930, `quiz_registrations` 331, `class_events_registration` 275 are the only member data). Options: port all; port none and archive a one-off MariaDB dump offline; port only `quiz_*` history. **Recommend: leave all 15 behind, archive the dump.**
2. **Timestamp zone.** `datetime` (110 columns) is naive. Options: all `timestamptz` assuming UTC (what the ported tables did); naive `timestamp` for wall-clock columns only. **Recommend: `timestamptz` except `send_at`/`send_time`/`conducted_on` kinds; first confirm the PHP server and MariaDB zone is UTC (unverified).**
3. **`tinyint(4)` flags.** `boolean` or `smallint`. **Recommend `smallint` and scan for values above 1; keep the JSON output as PHP emits it.**
4. **The 8 `users` columns nobody reads** (`provider_id`, `region`, `lat`, `lng`, `timezone`, `browser`, `location_details`, `updated_at`; only account deletion touches them) and the 2,000-character cap on `picture`. Options: drop and cap; keep in a `legacy_profile` table. **Recommend drop, after counting pictures over 2,000 on real data.**
5. **`class_access` cutover state in production.** Table or view? Verify; then drop the legacy grants and load rules only. **Recommend (c) in section 3.**
6. **The node notifier** (`notifier_reminders`, `notifier_runs`, `notifier_sent_messages`, WhatsApp sender) reads MariaDB directly. Options: keep it on MariaDB until it is ported; point it at PostgreSQL; port the worker to C# in `notifications`. **Recommend: port the three tables now (so the schema is complete) and keep the worker on its own connection setting until `notifications` is filled.**
7. **`outbound_messages` and `platform.outbox`.** Keep both (queue for delivery, outbox for domain events) or merge. **Recommend keep both; `search` and push/WhatsApp drains stay on `outbound_messages`.**
8. **Accent-insensitive matching.** `citext` is case-only; MariaDB also ignored accents. Options: accept; ICU column per case; ICU for `classes.city` and `country` only. **Recommend accept except where a rule matches names (access rule `city`, `country`).**
9. **Freshness of `schema.sql` and the two unverified production tables** (`teacher_training*`, `surveys`). Option: regenerate `schema.sql` from migrations on the parity stack; ask whether the three exist in production. **Recommend both before the load script is written.**
10. **How the spec grows.** Options: regenerate `api-docs.json` with request bodies recovered from handlers; hand-write each domain's `api.yaml` during the fill phase; both. **Recommend hand-written per domain (one recon per slice), using `api-docs.json` only for the 501 stubs.**
