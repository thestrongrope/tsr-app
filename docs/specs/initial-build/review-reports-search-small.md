# Review: reports, search and the small routes

Independent, read-only review (Opus, `security` agent) of `dotnet-11` at `8e04e3b` plus the uncommitted S1 fix, against `build/parity-php/src/web`, by the brief in `review-brief.md`. Received 12 Nov 2026. The reviewer ran only `dotnet test domains/search/api/tests` (54 passed). Saved as received; see "Follow-up" at the end for what was verified or fixed since.

**Verdict:** no authorization, row-scope, data-exposure, injection or irreversible-action hole in the area (the 8 MCQ reports, search, holy-quran, the access log and its download, the quran leaderboard and its download, and `ReportExport` as these routes use it). Two notes where the new code is looser or more fragile than PHP; one is a parity break.

## Findings

**R1 (should-fix / note). A trailing newline in `from` or `to` gives a 500 on `/reports/mcq-summary/download-all`.**
- Where: `domains/classes/api/features/report-mcq-summary-all/ReportMcqSummaryAll.cs:43` puts the raw `report.From` and `report.To` into `Content-Disposition` without `SafeName`.
- Why it gets through: `ReportDates.ParseDay` accepts `"2025-11-05\n"` on purpose (`domains/classes/api/domain/ReportDates.Tests.cs:12,47-49`), and `Check` echoes the raw text back.
- Trigger: `?from=2026-01-01%0A` by any `reports:read` holder. Kestrel rejects a control character in a response header value with an `InvalidOperationException`, so the answer is a 500.
- PHP (`routes/reports.php:1356`, `api_send_file` in `lib/response.php:154`): `header()` refuses the line with a warning and still sends the CSV with a 200.
- No header injection is possible: Kestrel blocks it. Reviewer: high on the cause, medium on the exact 500 (not run). The other download routes go through `ReportExport.SafeName`.

**R2 (note). Search can show a guide that no longer exists (looser than PHP, low impact).**
- Where: `domains/search/api/domain/SearchEngine.cs:112-126` (`CheckGuidesAsync`) keeps a guide hit whenever an active class of that level id is in reach, and takes the title from the index.
- PHP (`models/search.php:129-136`) re-reads the guide (`docsFor('guide')`: a non-empty guide in language 1 with a slug) and drops the hit when the guide is gone.
- Effect: a stale index can still list a deleted or emptied guide under its old name. Guides are not member data. Reviewer: high confidence.

## Checked and ruled out

- **MCQ row scope.** `ReportScope.ClassIdsAsync` applies the `reports:read` reach, the gender, status 'A' and the AYD1 exclusion; `KeepAssignedAsync` intersects with the `classes:read` assigned-only ids, as PHP's `ClassesModel::getAll` (`models/classes.php:202-244`). The list, class, download-all and class-download routes go through one `OpenAsync` (`McqSummaryReport.cs:46`, `McqAdherenceReport.cs:23`), so the files have exactly the scope and filters of the screen. `classIds` only filters inside the scoped report. `{class_id}` of 0 or a word picks the first class inside reach (copied quirk).
- **Leaderboard.** `QuranLeaderboard.cs:89-166` matches PHP's `api_require_quran_leaderboard` and `getLeaderboardData`. The download is the same query with no limit, capped at 50000 rows.
- **Access log.** `audit-log:read` is checked before the filters, as PHP; only role 1 holds it. The fields returned are exactly PHP's. PHP sends no `Cache-Control: no-store` here, and neither does the new code. `SpreadsheetSafe` matches PHP's (`models/auditlog.php:124`).
- **PDF (Gotenberg).** `ReportHtml` encodes the title, headings, headers and every cell, with a fixed inline style and no outside resource. `DownloadPageAsync` (new) has one caller, `assessment/.../ManageSheet.cs:67`; its page builder `QuizSheet.cs` encodes every value (lines 31-44; outside this area, skimmed). Timeout 60 s, response capped at 50 MB.
- **xlsx formulas.** ClosedXML stores a string as text, as PHP's `setCellValueExplicit` TYPE_STRING; `ReportXlsx.Tests.cs:73-83` proves `=HYPERLINK(...)`, `+` and `@` stay text. The CSV route uses `ReportCsv.Cell` (PHP's `csvSafeCell`), also on the topic headers.
- **Search.** Typed `MatchQuery` with the text as a value; constant index name; field names from `SearchPlans` constants; `kinds` checked against a fixed list. The reach filter is in the query and each hit is re-checked through `v_*` views. With `TSR_ELASTICSEARCH_URL` unset every kind is `unavailable` (unit tested). Request timeout 5 s; DB command timeout 15 s.
- **holy-quran.** Any signed-in member, as PHP, bounded to 200 rows.
- **SQL.** Every query is parameterised; no name or fragment is built from caller input.

## PHP looseness that was copied

- The access-log `page` filter passes `%` and `_` through to LIKE as wildcards.
- `{class_id}` of 0 or a word means "first class of the report".
- Leaderboard ranks are global; a member in two classes is listed twice; no demo-class exclusion.
- Leaderboard and access-log files hold every row (capped here at 50000; PHP had no cap). A 50000-row PDF ties up Chromium for up to 60 s, but only admins can ask for one.
- The MCQ student query silently stops at 200000 rows.

## Guards no test would catch if deleted

- `KeepAssignedAsync`: in the fixtures the coordinators' `reports:read` and `classes:read` reach the same classes (medium confidence).
- The AYD1 exclusion on the MCQ routes.
- The row caps (`MaxRows`, `MaxDownloadRows`, `MaxStudentRows`, `MaxClasses`).
- `SafeName` applied to the raw `{class_id}` in the MCQ class-download file names.
- The trailing-newline case on download-all (R1).

## Not checked by the reviewer

The full build, `db/tests` and Hurl; semgrep, gitleaks and osv-scanner; whether ClosedXML accepts a newline in a sheet name built from `from`/`to` (the MCQ class download and the leaderboard download); real Elasticsearch and Gotenberg; `/reports/pending/nudge`; the callers of `PlatformCommands.RecordAdminAccessAsync`.

## Follow-up

- R1: fixed 12 Nov 2026 (the file name trims the dates). Test `TestReports2Tests.Summary_csv_with_a_line_feed_after_a_date_..._REVIEW_R1` failed first. The test server does not refuse a control character in a header as Kestrel does, so the test asserts the file name; the 500 itself was not reproduced on a running stack.
- R2: open (a decision: re-read the guide as PHP does, or accept a stale hit until the index feeder exists).
