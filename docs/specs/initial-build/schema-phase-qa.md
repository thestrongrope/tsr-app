# Schema phase QA (2026-11-10)

Reviewer: independent QA, read-only. Scope: the uncommitted schema phase (S1, S2, S3) and commit d50e9c6 (ten membership operations).
No member row content was read or is recorded here. Not run, by order: Hurl files, `tools/*-contract.sh`, `load.sh`, `prove-synthetic.sh`, the parity stack.
Only read-only SELECTs on `tsr-app-dev-db-1` (catalog views: columns, indexes, constraints; counts) were issued.

## Verdict

S1 and S3: PASS on everything checkable here. S2: the script is sound but has three weak spots (silent source zone, a misleading RESULT line for merge tables, a failed run that cannot be resumed). d50e9c6: no status, message or null-rule difference found beyond those already in `php-parity-feedback.md`; three small unrecorded differences (below). Not checkable: any Hurl run, the S2 proof run.

Counts: High 0, Medium 4, Low 6, Info 5.

## Checks run

| Check | Command | Result |
|---|---|---|
| Build | `dotnet build TsrApp.slnx --no-incremental` | 0 warnings, 0 errors |
| Tests | `dotnet test TsrApp.slnx` (plus `dotnet test db/tests` again alone) | all pass: access 64, platform 205, membership 274, assessment 1, classes 1, notifications 1, site 12, shared 16, identity 63, host 235, db 271 |
| shellcheck | `load.sh`, `prove-synthetic.sh`, `membership-contract.sh`, `s2-source.sh` | 2 warnings (SC2034 unused `src` in load.sh:65; SC2120 in prove-synthetic.sh:16), rest info |
| Weakened bar | grep for pragma, SuppressMessage, Ignore, NoWarn, empty catch in the working tree; in d50e9c6 no assertion line removed from a test file, and the deleted `GeoRateLimit.Tests.cs` (124 lines) moved to `shared/api/MemberRateLimit.Tests.cs` (170 lines) | none. Guard allow-list grew by 2 (`classes.classes.city`, `.country`), each with a reason, within S1 scope. No test deleted or skipped. |
| Schema diff | script (scratchpad `cmp.py`) comparing `tools/synthetic-data/schema.sql` with the migrated PostgreSQL catalog, all 52 tables of `tables.txt`, 499 columns | see Schema below |
| Route diff | script comparing `operations.csv`, `web/api/mobile/index.php`, `web/api-docs.json` | see S3 below |

## Acceptance criteria

### S1 Schema (schema-phase-design.md:20)
| Criterion | Verdict | Evidence |
|---|---|---|
| Modules and contexts for classes, assessment, notifications | PASS | `domains/{classes,assessment,notifications}/api`; built, tests pass |
| 36 tables as EF migrations in owners' schemas | PASS | catalog: classes 16, notifications 8, assessment 7, platform 10 (4 new), content 2 (1 new); `db/tests/SchemaPhaseTests.cs` passes |
| Rest of `users`, `account_deletion_requests` | PASS | 7 columns added (13 columns; `active_token` replaced by partial unique `uq_active_token`, equivalent: NULLs never collide in either) |
| Synthetic seed rows for every table | PASS | every one of the 36 target tables has an `insert into` in `db/synthetic/*.sql` |
| Build 0 warnings | PASS | above |
| Guard tests pass | PASS | `SchemaGuardTests` in db 271/271 |
| 21 Hurl files still pass | NOT CHECKABLE | barred |

### S2 Load (design:21)
| Criterion | Verdict | Evidence |
|---|---|---|
| One script, MariaDB to PostgreSQL, CSV to staging, SQL converts and splits users | PASS | `tools/data-load/load.sh`, `sql/00..95` |
| Reports counts and orphans per table, never fails on an orphan | PASS (by reading) | `95-report.sql`, `90-orphans.sql` |
| Run on synthetic: counts match per table | NOT CHECKABLE | barred; notes claim 52 tables, 0 rejected |
| The 21 Hurl files pass on a dev database filled by the load | FAIL as written, documented | notes say 20 of 21: `content/list-published-articles.hurl` (article exists only in seed.sql). Deviation is written down. |

### S3 Surface (design:22)
| Criterion | Verdict | Evidence |
|---|---|---|
| Every operation routed, from api-docs.json | PASS | `operations.csv` = PHP router exactly: 213 rows, 213 distinct method+path pairs, 0 only-in-PHP, 0 only-in-CSV; `api-docs.json` also has 213 (design's "211" was wrong; recorded in the S3 notes) |
| Unbuilt answers 501 `{"detail":"Not implemented"}` after the sign-in check | PASS | `shared/api/PlannedRoutes.cs`: `RequireMember()` then 501; public ones 501 with no check; tests pass |
| A test compares the route table with the spec | PASS with a gap | `RouteSurfaceTests` compares the table with `operations.csv`; nothing pins `operations.csv` to PHP's router or `api-docs.json` (Low L5) |
| Placeholders never write | PASS | the only write is identity's sign-in record, as on every member route; `PlannedRoutesTests` asserts no user row is created |

### d50e9c6 (ten membership operations)
| Operation | Verdict | Notes |
|---|---|---|
| 1 GET /me | PASS by reading | cast rules (`name` empty is integer 0, `gender`/`age_range` non-numeric is null, `mobile ''` null) match `api_cast` (`ProfileView.cs`) |
| 2 PATCH /me | PASS by reading | order: empty body answers before validation, field order, messages, place rules, postal override, gender lock last; all as `users.php:49-110`. Deviations: see U2 |
| 4 GET /me/children/links, 8 GET /me/parents | PASS with U1 | joins reproduced (shared token doubles, creator by id, `Invite link`/`Unknown`) |
| 5 inspect, 6 accept | PASS by reading | 410 before the 422 group, one 422 text, 403 on the invite creator's rights, 409 twice, 404 for an unknown child; matches `guardians.php:195-310` |
| 7, 9 revoke | PASS by reading | UPDATE on the pair, 404 texts, 204 |
| 15 GET /registration, 16 POST /registration | PASS by reading | GET: key order, int-or-null years, decoded lists with `[]` fallback (JSON object read as its values, as `array_values`), `languages` `{}` when empty, lowest-id row: all match `registration.php:20-140`. POST: required check, whitelists, three unguarded writes, wipe of `for_classid`/`profession`/`interests` match. Multi-select JSON text is stored in `jsonb` here (canonical form), so PHP's `\/` escaping cannot differ (checked with a literal cast). Only difference: U3 (option ordering). |
Depth: read-and-compare, not differential runs (Hurl barred). Geo/place rules (`PlaceRules`, `PlaceCheck`) and `JsonBody`/`PhpValue` edge cases were not re-derived; they carry their own unit tests.

## Schema comparison (52 tables, 499 columns)

Types, nullability, defaults, lengths (CHECKs), enum lists, decimals (`lat` 10,8 and `lng` 11,8 kept), unique and plain indexes, and the three declared foreign keys with their delete rules (`syllabus` to `class_levels` RESTRICT, `user_notifications` CASCADE, `notifier_sent_messages` CASCADE) agree for every one of the 36 new tables, including the two 2026_11_08 tables checked by hand against their migration files. Enum CHECKs hold exactly PHP's values (`class_audit_log.action`, `student_transfers.type`, `syllabus.link_type`, scheduled-notification `kind`/`status`, `account_deletion_requests.source`).
Wall-clock vs instant: `send_at` (timestamp), `send_time`/`reminder send_time` (time), seven `date` columns kept; `quiz_campaigns` windows flagged in the notes as a judgement. Judgement reasonable; the data cannot prove it.
Silent losses: the PHP triggers (`classes_before_create`, `spot_quizzes_before_insert`) and the four `ON UPDATE CURRENT_TIMESTAMP` columns that matter are written down (notes "Deferred"). I found one more `ON UPDATE` table, `notifier_settings`, but it is a leave-behind. Nothing else lost silently on the 36.
The d50e9c6 tables checked the same way (after fixing my first query, which had skipped the `access` and `membership` schemas): `membership.user_guardians.code` is unique (`idx_code`), `student_interests (token, interest_id)` is unique, every citext column in `user_guardians` has its length CHECK and enum CHECKs hold PHP's lists. Differences found only on older (pre-S1) ported tables, outside this phase, not written down: see L4.

## Findings, ranked

### Medium

**M1. The load reads every MariaDB `datetime` in UTC unless told otherwise, and nothing records or checks the zone.** `tools/data-load/load.sh:19` (default `SOURCE_TZ=UTC`), `sql/00-engine.sql` timestamptz branch. Decision 2 is open (the owner's answer on the PHP and MariaDB zone), yet a run without `--source-tz` succeeds and the report does not print the zone used. Scenario: production MariaDB is Asia/Kolkata; the operator forgets the flag; `users.createdon`, `lastlogin`, guardian `created_at`/`expires_at`, `notifications.sent_at` are all 5h30 early, with no sign in the report. The API then prints instants as UTC (`domains/membership/api/domain/LinkRowView.cs` `Stamp`, comment "the database's clock is UTC"), so `GET /me/children/links` `created_at`/`activated_at`/`revoked_at` differ from what PHP printed (MariaDB local time), even when the flag is right. Also `expires_at` is written by PHP's `date()` (PHP zone) but compared by SQL (DB zone): the legacy rows are consistent only if the two zones match. Reproduce: load one synthetic row twice with `--source-tz UTC` and `Asia/Kolkata` (`test/assert-tz.sql` already proves the shift) and read `GET /me/children/links`. Fix direction: make `--source-tz` required; print it in the report; record the API-side display decision.

**M2. `hosts/gateway/default.conf` now sends all 192 unbuilt paths to the new API, which answers 501.** `default.conf:47-225`; the file's own header (lines 1-3) still says every other path goes to legacy/php, and the fallback (line 227) still says so. Scenario: this file, or its pattern, is used in front of PHP: every store-live app call to an unbuilt route (for example `GET /classes`) becomes 501, breaking root rule 7 (forward compatibility). Today only `docker-compose.dev.yml` uses it (no PHP behind it) and the header documents the choice, so this is a hazard, not a defect. No guard marks the planned block as dev-only. Reproduce: read the block; `curl -i localhost:8088/classes` with a token on the dev stack gives 501.

**M3. About 70 of the planned `operations.csv` auth labels are wrong.** `operations.csv` (planned rows, auth `member`). The S3 notes call the label "a guess" for 73 rows. Script check: for 70 of them the PHP route calls a helper (`api_require_*`) that itself calls `api_authenticate(true)` (for example `routes/permission_grants.php:33`, `routes/reports.php:68`), i.e. PHP creates a member, so the label should be `create`. Behaviour today is unaffected (placeholders never create), but the catalog is what a later slice author reads to choose `RequireMember(createsMember: ...)`; a wrong `member` makes a rebuilt route stop creating members where PHP does. The notes do not say the guess is wrong in nearly every case. Corroboration: the membership recon (section 1) states all 26 membership operations call `api_authenticate(true)`, yet the three `/members/{child_token}/parent-links` rows are labelled `member`; `routes/reports.php:68` (a report gate helper) and `routes/permission_grants.php:33` were checked by hand. Method to reproduce: for each planned route, take the handler in `index.php`, find the first `api_*` helper it calls, and search that helper (and what it calls, 3 levels) for `api_authenticate(true)`; a temporary script did this (70 of 70 found true).

**M4. A failed domain leaves the target half loaded, and the saved report still ends "RESULT: every exported row was loaded".** `load.sh` loop over `sql/[1-8]*.sql` (one transaction per domain), `trap cleanup`, `sql/95-report.sql`. Answer to "can a failure leave a half-loaded domain unnoticed": inside one domain no (the transaction rolls back whole); across domains partly. A failed domain's `staging.report` rows roll back with it, so the RESULT line (computed from the surviving rows) reads success. The failure shows on stderr (`DOMAIN FAILED`), in the exit status (1) and in a `NOT LOADED` line appended to the report file, but that line names source tables that no domain loaded, never targets: if `membership` fails, `users` is still "loaded" by identity and access, so `membership.member_profiles` (and `access.user_roles` if access fails) is never named. The cleanup trap also drops `staging` on failure, so the failed domain cannot be retried alone; a re-run refuses (non-empty targets) unless `--truncate`, which wipes the domains that succeeded. Scenario: one required column missing from a real source table (the engine raises) in `membership`: exit 1 is the only reliable signal. Reproduce: run against a source lacking one `class_registrations` column. Fix direction: write `DOMAIN FAILED <name>` and the failed targets into the report before RESULT, make RESULT depend on `FAILED`, keep staging on failure.

### Low

**L1. Merge tables hide rejects as "skipped", and the RESULT line says all is well.** `sql/00-engine.sql` (`v_skipped := v_source - v_filtered - v_loaded`, then `v_rejected := 0` in merge mode); `sql/95-report.sql` last select compares only loaded+filtered+skipped. A rejected row in `access.permissions`, `role_permissions`, `interest_options` or `platform.lookups` (over-length value, NULL in a required column) lands in the "skipped" column and the line "RESULT: every exported row was loaded" prints; only the detail section names the rejection. Scenario: source `permissions.description` NULL (the PHP column is NOT NULL, so unlikely) or a name over 100. Reproduce: stage one over-length `permissions.name` and run the merge.

**L2. `--truncate` empties the targets before any export is checked.** `load.sh:68-75` then the export loop (after line 85). A missing source table or a count mismatch dies after the truncate; the targets stay empty. Harmless on a fresh target; on the dev database that now holds real data it is the destructive step to be careful with (README says so in words only). Fix direction: truncate after the exports succeed.

**L3. The row-by-row retry is unbounded in time and subtransactions.** `00-engine.sql` retry loop: one bad row in a large table (for example `classes.class_attendance`, `platform.admin_access_log` 27,500 rows) redoes the whole table one row at a time inside one transaction, bounded only by the 60 min `statement_timeout`. CODING-GUIDELINES MUST 2. Not seen on synthetic data. Fix direction: retry only the failing chunk, or cap the retried rows and report the rest as "not attempted".

**L4. Older ported tables lost defaults or loosened nullability, not written down.** Outside S1 but found in the comparison: `identity.account_deletion_requests.status` (PHP default `pending`) and `requested_at` (default now) have no default in PostgreSQL; `access.class_access_rules.note` (default `''`) and `class_access_rule_conditions.negate` (default 0) likewise; `access.permissions.description` is nullable here, NOT NULL in PHP; `access.user_permissions` is indexed (user_id, permission) where PHP has (user_id, revoked_at); `membership.interest_options.sort_order`/`is_active` are NOT NULL here, nullable in PHP (the load would reject a NULL). Any writer other than the C# handlers that omits these columns now fails or writes NULL. Low while only the C# API writes.

**L5. Nothing pins `operations.csv` to PHP's router.** `RouteSurfaceTests` and `GatewayTests` compare the code with the CSV; if PHP adds a route the tests stay green. My script found the CSV equal today (213/213). A one-line test reading `api-docs.json` would close it.

**L6. `age_ranges` is left behind on the claim "no API, web page or worker reads them".** `schema-phase-design.md:13`; `web/functions.php:100-127`, `index_profile.php` and `tsr_class_mis.php` read it through `reference_list('age_ranges')`. The design's decision 5 correctly says "web only", so the header sentence is wrong, not the decision. Matters when the web profile page moves.

### Info

- I1. Placeholders on a PHP create route answer 404 "User not found" to a first-time caller (S3 notes; recorded).
- I2. `identity.users.firebase_uid` is citext with a unique index: a Firebase UID is case-sensitive. Same as PHP's case-insensitive collation, so parity, but worth the security review's eye.
- I3. (U2) `PATCH /me` with `mobile: null`: `ProfileUpdate.cs` `SaveAsync` inserts a blank `member_profiles` row (committed, autocommit) before the setter throws the 500. PHP changes nothing. A blank row reads back as the defaults (`SendUpdates` "N", `Mobile` "", `Language` 0, as the column defaults), so no visible effect.
- I4. (U3) `GET /registration` `interestOptions` order `sort_order, name`: PostgreSQL sorts the citext name under `en_US.utf8`, MariaDB under `utf8mb4_unicode_520_ci`; only matters for ties on `sort_order` with accents or punctuation (19 options today).
- I5. Tests of the loader are scripts run by hand (`prove-synthetic.sh`), not in `dotnet test` or `scripts/check.sh` (recorded in the notes).

## Membership differences not already in php-parity-feedback.md

U1 (M1): timestamps printed in UTC on the two guardian lists. U2 (I3): blank profile row before a `mobile: null` 500. U3 (I4): option ordering collation. Everything else I compared (validation order, messages, status codes, response fields, null rules for operations 1, 2, 4 to 9, 15, 16) matched the PHP source or is already recorded. Already recorded and confirmed present in code: 413 over 1 MiB, 200-row cap, gender lock by user id, entity table, per-process rate limit, the shared-token registration risk (plan.md).

## Rules no tool checks here

`AnalysisLevel latest-recommended` plus warnings-as-errors cover nullability, style and common analyzers. Nothing checks, so review only: MUST 1 (nesting and cyclomatic limits; the PL/pgSQL engine `load_table` is one 150-line function), MUST 2 (bounded work: L3), MUST 3 (timeouts: the load sets them; the .NET side not re-audited), MUST 4 and 5 (validation, silent failures: L1), MUST 8, MUST 9 (no PII in logs: reports and logs carry counts only on my reading), MUST 10 and 11 (dead code; regression tests: no bug fix in this diff). Root rules: 1 (rules only in domains), 5 (prepared statements: EF and interpolated `ExecuteSql` are parameterised; the loader builds SQL with `format(%I/%L)` and one validated zone string), 6 (no real member data in the repo: not scanned by any tool; I did not read member rows), 7 (forward compatibility: only Hurl, not run). Rule 3 (no cross-slice or cross-domain table reads) is enforced by `hosts/api/tests` and `SchemaGuardTests`.
