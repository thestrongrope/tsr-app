# Docs cleanup, pass 1: `domains/classes/CLAUDE.md` and `domains/search/CLAUDE.md`

A trim, not a rewrite of meaning. Sizes: classes 18369 to 13706 bytes; search 4194 to 4254 bytes (history removed; the same facts set out under headings and two tables, so no smaller).
The classes file stays above the 6 to 8 KB goal: the events table (about 3.6 KB) and the published views table (about 2.3 KB) are
kept whole, because `domains/CLAUDE.md` makes the domain file the home of events and of a view's readers.

## Removed

| File | What was removed (short) | Where the fact still lives (path), or "history only" |
|---|---|---|
| classes | "74 built operations (2026-11-11): 45 before B4a, 15 of B4a, 8 of B5a, 3 of B5b, 3 of B5c, 9 of B5d" | history only (old counts; today's 96 is `docs/specs/initial-build/operations.csv`, 96 folders in `domains/classes/api/features/`) |
| classes | Batch names and order (B1, B2a, B2b, B2c, B3, B4a, B5a to B5d, lane mcq-reports), "Batch X added ..." | history only; the notes files are still listed |
| classes | The list of each batch's slices and routes (19 reads of B1, 3 reads and 8 writes of B2a, the enrolment writes, deactivate, edit a student, bulk add, the six conduction routes, the 15 admin operations, each report and download by slice name) | `domains/classes/api/features/` (one folder per slice), `domains/classes/spec/api.yaml`; a group table with counts is kept |
| classes | Fixture details: WRITE, ENROLMENT (tokens 9005xx, classes 9411 and up), BULK (9007xx, 9451 and up), CONDUCTION (9008xx, 9471 and up, sessions 947101 and up, run-created sessions deleted), B4A (9009xx and 9010xx, classes 9511 to 9559, syllabus 9501 to 9599), B5A (9014xx, 9581 to 9589, fixed dates November 2025), B5C (9019xx, 9564 to 9568, language 9, October and November 2025), "reset on every run" | header comment of `tools/classes-contract.sh` |
| classes | B2C fixtures (tokens 9006xx, classes 9431 and up) | header of `db/synthetic/classes-b2c-fixtures.sql` (900601 to 900699, classes 9431 to 9449) |
| classes | B5B fixtures (tokens 9015xx, classes 9591 to 9599, sessions dated relative to the load time) | header of `db/synthetic/classes-b5b-fixtures.sql` |
| classes | The coordinators `rp_coord`, `rb_coord`, `rc_coord` | `MEMBERS` list in `tools/classes-contract.sh` |
| classes | "`classes-bulk-cleanup.sql` first deletes the members a run created" (kept in short form) | `db/synthetic/classes-bulk-cleanup.sql` header |
| classes | Full paths of each fixture pair (`db/synthetic/classes-<x>-fixtures.sql`, `tools/parity-php/classes-<x>-fixtures.sql`) | `tools/classes-contract.sh` (the load lists of both sides); the pattern is kept |
| classes | "unit tested" after `ConductionRules`, `SyllabusRules`, `DeactivationView`, `TeacherTraining`; "unit tests are the `*.Tests.cs` beside them" | the files `domains/classes/api/domain/*.Tests.cs`; `domains/CLAUDE.md` rule 8 |
| classes | "contract `spec/tests/admin-*.hurl`", "`report-*.hurl`", "`report-*-download.hurl`", `me-guides.hurl`, `me-guide.hurl` | `domains/classes/spec/tests/` (one file per slice; the rule is kept in Status) |
| classes | `Enrolment.cs` is PHP `addStudent` (kept in short form), what it does | header of `domains/classes/api/domain/Enrolment.cs` |
| classes | Guide guard detail: "PHP `api_require_guide_reader`", "else 403 'Guides are for students and teachers'" | `domains/classes/api/domain/GuideReaders.cs` |
| classes | "`ReportMonths.cs` its months", "`ReportCalendar.cs` its weeks", "`ReportCsv.cs` its CSV", "`ReportDates.cs` (the YYYY-MM-DD rule)" (kept as one row of "Where things are") | headers of those files in `domains/classes/api/domain/` |
| classes | "`v_classes` gained `level_name` (migration `ClassViewLevelName`)", "gained `extra_students` (migration `ClassViewExtraStudents`)" | the Published views table of the same file (kept) |
| classes | "assessment published `v_standard_mcqs` and `v_class_mcq_copies` (migration `McqAdherenceViews`)", "new columns, migration `McqReportViews`" | `domains/assessment/CLAUDE.md`; `domains/assessment/api/Migrations/` (both migrations exist); the views read are kept under Dependencies |
| classes | "Each read slice became thin and its query and rules moved to `domain/`" (the move) | history only; the standing rule is kept |
| classes | "Lane mcq-reports added eight MCQ report routes moved here from assessment" (the move) | history only; kept: the eight routes are here, not in assessment |
| classes | "`share_url` is `TSR_PUBLIC_WEB_BASE` plus ..." in the status paragraph | kept, moved to Settings; also `domains/classes/api/features/me-guide/MeGuide.cs` |
| classes | "every route is `create`" said three times (admin, B5a, downloads, me-guides) | kept once as a rule; `docs/specs/initial-build/operations.csv` (95 `create`, 1 `public`) |
| classes | "so every operation of this domain is built" narrative | kept as one Status line |
| classes | The Dependencies sentence listing each command per domain | kept as the table "Published command or interface used" (rows added for `ReportExport`, `NotificationsCommands.LastNudgeAsync`, `AnnounceAsync`, `Permissions`) |
| search | "proved up to the index boundary on both sides and against a fake index (test lane edge)" | history only; `docs/specs/initial-build/test-edge-notes.md` (still listed) |
| search | "never run against a real Elasticsearch" (top) and "Not verified against a real Elasticsearch" (feed) | superseded inside the same file by its section "Proven against a real Elasticsearch"; root `CLAUDE.md` says the same ("proven against a real Elasticsearch 9.2.3 on the test stack") |
| search | The date of the owner decision and of the proof (12 Nov 2026) | history only |
| search | "The first real run found two defects the in-process test double had accepted" (narrative) | history only; the two lasting facts are kept (the worker host test, the plain JSON content type), see `hosts/api/tests/WorkerModeTests.cs` and the comment at `JsonType` in `domains/search/api/domain/ElasticSearchIndex.Writer.cs` |
| search | "no view needed a new column" | history only |
| search | "the checklist for the test phase" (in the pointer to `lane-search-notes.md`) | history only; the pointer is kept |

Counts: classes 22 items (16 confirmed elsewhere or kept in another form, 6 history only); search 6 items (1 superseded and confirmed, 5 history only).

## Kept, unsure

| File | Statement | Why unsure |
|---|---|---|
| classes | The admin audit row is written for "manage, update, create, bulk add" | `ClassGuards.LogAdminAccessAsync` is also called from `admin-member-get`, `admin-member-enrol` and `AdminGuards.cs`. Kept as written. |
| classes | `classes.student_enrolled` source includes `by_token` | The header of `domain/Enrolment.cs` lists four sources (added, joined, placed, bulk). Kept as written. |
| classes | "`domains/search/api/domain/SearchFacts.cs` holds a copy" of the guide slugs | It holds the level ids with a page (2 to 5), not the slugs. Kept as written. |
| classes | "`IClassEnrolments` (membership) not yet" and "No other public interface yet" | Not checked against membership. Kept. |
| classes | Events: "no consumer yet", "Consumed: none" | Not checked against notifications and search. Kept. |
| classes | `ClientAddress` | The old text placed `ClientAddress.cs` in `api/domain/`; the file is `shared/api/ClientAddress.cs`. The new text names no path. |
| search | "until a worker container runs the feed, PHP's `drain_search` and `reindex_search` still feed the index" | True for production (not wired), not for the test stack. Kept, worded for production under Status. |
| search | Client version 9.5.3 | Matches `Directory.Packages.props` today; a version in prose goes stale. Kept. |

## Not checked

No build or test was run (documentation only). Every "confirmed" row above was checked by opening the named file.
