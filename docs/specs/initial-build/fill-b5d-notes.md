# Fill batch B5d notes (11 Nov 2026): xlsx and PDF report downloads

Work in progress record, appended per route. See the end for what is left.

## Plumbing (stage 1), proved on the test stack and on PHP

- **Where it lives:** platform, `domains/platform/api/ReportExport.cs` (public: `ReportExport`, `ReportFormat`, `ReportSection`; added to `PublicSurfaceTests`). Internals in `domain/`: `ReportXlsx` (ClosedXML), `ReportHtml` (the page PHP gave Dompdf), `ReportCell` (number or text), `IPdfRenderer` (the one external-boundary interface) and `GotenbergRenderer`, `GotenbergSettings`. No second layer. Platform is already in `Dependencies` of classes and membership, so no dependency list changed. `InternalsVisibleTo Tsr.Db.Tests` lets db tests swap `IPdfRenderer` for a fake.
- **A route** calls `ReportExport.TryGetFormat`, then `export.DownloadAsync(format, title, sections, filenameBase, ct)`; the `?format=` 422 comes BEFORE the sign-in through a new `precheck:` argument of `RequireMember` (`shared/api/MemberRoute.cs`, run by identity's `CallerMiddleware` before it authenticates). Headers as PHP `api_send_file`: `attachment; filename="X.xlsx"`, `Content-Length`.
- **ClosedXML 0.105.1** (latest stable, MIT), only in `Tsr.Platform.Api.csproj`; version in `Directory.Packages.props`. Transitive: ClosedXML.Parser 2.0.0, DocumentFormat.OpenXml 3.1.1 (+ .Framework), ExcelNumberFormat 1.1.0, RBush.Signed 4.0.0, SixLabors.Fonts 1.0.0, System.IO.Packaging 8.0.1. Build 0 warnings; `dotnet list package --vulnerable --include-transitive` clean.
- **Layout kept from PHP:** title bold 14, per section a bold heading, a bold header row, rows, a blank row; ints and floats are numbers, everything else text (so a leading `=` is text, never a formula); null and "" leave no cell; sheet name = title with `[]:*?/\` turned to spaces, cut to 31 (deviations: characters not bytes, an apostrophe at either end becomes a space, an empty name is "Report"). Autosized columns.
- **Deviations found by a failing test:** ClosedXML throws on text over 32767 characters (PhpSpreadsheet cuts it): cut to 32767. Control characters that XML 1.0 cannot carry are dropped (PHP's writer escapes them). A file name is cut to letters, digits, space, `.`, `_`, `-` (`ReportExport.SafeName`), because a name may come from the path.
- **PDF:** HTML as PHP's, every value `WebUtility.HtmlEncode`d, no external resource (tests: script, img, link, iframe, quotes, RTL text through). Gotenberg `POST /forms/chromium/convert/html`, one multipart file `index.html`, A4 landscape. **Landscape finding:** Gotenberg swapped a landscape 11.69 x 8.27 request to portrait (MediaBox 595 x 841); it now sends 8.27 x 11.69 with `landscape=true` and the PDF is 842 x 596. Timeout 60 s, response cap 50 MB, answer must start `%PDF`.
- **Renderer down:** 503 `{"detail": "The PDF could not be made right now. Try again later"}` (PHP has no such answer: Dompdf ran in the request). The renderer's own text goes to the log only.
- **`TSR_GOTENBERG_URL` is required:** like `TSR_DB` and `TSR_FIREBASE_PROJECT_ID`, the host refuses to start without an http(s) URL (`ValidateOnStart`, tested in `hosts/api/tests/GotenbergSettingTests.cs`); the `--migrate` job never starts the host and needs none. `TestApi` and `ApiHost` set a dummy.
- **Compose:** `gotenberg` service in `docker-compose.dev.yml` (image `gotenberg/gotenberg:8`, no published port). `docker run --rm --entrypoint sh gotenberg/gotenberg:8 -c 'command -v curl wget'` printed `/usr/bin/curl` only, so the healthcheck is `curl -fsS --max-time 3 http://127.0.0.1:3000/health`. `api` has `TSR_GOTENBERG_URL: http://gotenberg:3000` (no `depends_on`: the API starts anyway and a PDF is 503 until Gotenberg is up). The test stack showed it healthy.
- **Tools:** `tools/export-parity.sh` (+ `tools/export_parity.py`, standard library only, run with `uv run python -I`; cases in `tools/export-parity.cases`) downloads one export from PHP :18091 and the new API :8089 and compares sheet names and each cell's kind and text. Cases use fixture-only callers (a coordinator): an administrator also sees each side's own seed data, which differs.

## Routes
| # | Route | Slice | Hurl (PHP / new) | Parity |
|---|---|---|---|---|
| 1 | /reports/active-teachers/download | `report-active-teachers-download` (query moved to `domain/ActiveTeachers.cs`) | `report-active-teachers-download.hurl` 11 requests, pass / pass | SAME, 21 cells |
| 2 | /reports/class-sessions/{class_id}/download | `report-class-session-history-download` (query moved to `domain/ClassSessionHistory.cs`) | `report-class-session-history-download.hurl` 9 requests, pass / pass | SAME, 37 cells |

db tests (`db/tests/ReportsB5dTests.cs`, partial class of `ReportsB5bTests`): scope per caller by reading the xlsx back; a formula-looking and a markup-looking name; unsigned bad format 422; renderer down 503; PDF headers. Mutations proved: dropping the id filter of active teachers failed the scope test; dropping the reach test of the session history failed its test.

## Process slips (honest)
- Ran `docker compose -p tsr-app-test ... ps` and `docker logs tsr-app-test-api-1` directly (read-only, test stack only) to see why `test-stack.sh up` answered 502, and `tools/test-stack.sh down` then `up` (allowed script, keeps the volume) because nginx kept the old API address. After each `up` that recreates the API the gateway can answer 502 for a while.
- The platform unit tests for `GotenbergRenderer` were written after the code (they passed first time). The db scope tests were written after the code; the mutations above show they can fail.

### Classes routes 3 to 9 (appended as each finished; every one: Hurl file passes on PHP then on the new API, parity SAME, db scope test proven by a mutation)
| # | Route | Slice (shared code moved to `domain/`) | Hurl file (requests) | Parity cases |
|---|---|---|---|---|
| 3 | /reports/conduction/download | `report-conduction-download` (`ConductionReport.Shape`) | `report-conduction-download.hurl` (12) | 2, rows compared as a set (see below) |
| 4 | /reports/weekly/download | `report-weekly-download` (`WeeklyReport`) | `report-weekly-download.hurl` (11) | 2 |
| 5 | /reports/summary/download | `report-summary-download` (`SummaryReport`, `SummaryFigures` moved) | `report-summary-download.hurl` (11) | 2 |
| 6 | /reports/subject-conduction/download | `report-subject-conduction-download` (`SubjectConductionReport`, `SubjectWeeks` moved) | `report-subject-conduction-download.hurl` (13) | 2 |
| 7 | /reports/pending/download | `report-pending-download` (`PendingReport`, `PendingRules` moved) | `report-pending-download.hurl` (11) | 2 |
| 8 | /reports/tsr/download | `report-tsr-download` (`TsrReport`, `TsrRules` moved) | `report-tsr-download.hurl` (10) | 2, strict order |
| 9 | /reports/students/download | `report-students-download` (`StudentsReport`, `StudentRules` moved) | `report-students-download.hurl` (12) | 3, strict order |

- Each read slice is now thin (route, caller, JSON); the query and the rules sit in one `domain/<Report>.cs` that the screen and the download both call (`OpenAsync` returns the report or PHP's refusal in PHP's order), so a file cannot hold a row the screen would not show that caller.
- Conduction parity: PHP leaves two sessions of one class in one week in no defined order (it showed 13 Nov before 10 Nov, the new API shows the day order), so the two conduction cases are compared as a set of rows (`--unordered`); every other case is compared cell by cell in order.
- Cell kinds copied from PHP's own xlsx: ids and counts are numbers, percentages of the TSR level rows are floats, the students' token is text, a missing teacher or reason leaves no cell.

### Membership routes 10 to 12
| # | Route | Slice (shared code in `domain/`) | Hurl file (requests; PDF cases in `*-new-api.hurl`) | Parity cases |
|---|---|---|---|---|
| 10 | /reports/registrations/download | `report-registrations-download` (`WaitingRegistrations`: query and guard moved out of `report-registrations`; the row also carries the full creation time) | `report-registrations-download.hurl` (8) | 2, fixture rows only |
| 11 | /reports/registrations/allocated/download | `report-registrations-allocated-download` (`AllocatedRegistrations`: query, labels, interests, extra students; rules unit tested first) | `report-registrations-allocated-download.hurl` (9) | 4, fixture rows only |
| 12 | /admin/donors/download | `admin-donors-download` (`DonorList`: query moved out of `admin-donors`) | `admin-donors-download.hurl` (5) | 1, fixture rows only |

- **Reach copied exactly (the ones that carry email, mobile and addresses).** Waiting list: registrations:read for the gender, no row scope beyond the gender (as PHP and as the screen). Placed file: a super or gender administrator gets every placed person of the gender including open registrations; any other registrations:read holder (a coordinator) gets only registrations that name a class, of people placed in THEIR assigned classes, and nobody with no assigned class (db test `Placed_registrations_download_gives_an_administrator...`, mutation-proved; Hurl with `b5d_coord`). Donors: every member in an active class, one row per enrolment, no limit (PHP has none; flagged, copied; 404 `There are no donors to download` when empty, db test).
- **New fixtures:** `db/synthetic/membership-b5d-fixtures.sql` and `tools/parity-php/membership-b5d-fixtures.sql` (tokens 902101 to 902199, registrations and enrolments 952101 and up, coordinator `b5d_coord` assigned class 9561), loaded by `tools/membership-contract.sh`. They set `extra_students` on the B4B class 9561.
- **New view column:** `classes.v_classes.extra_students` (migration `20261111170000_ClassViewExtraStudents`, hand-written like `ClassViewLevelName`, no designer file: `dotnet ef` is not installed). Needed by the placed file (PHP counts the extra students of the class). Listed in `domains/classes/CLAUDE.md`.
- **Gender of the placed file:** PHP compares the stored text with an integer (`u.gender = 1 OR u.gender = 0` for gents, `= 2` for ladies), so "Male", "Female", empty and "0" read as 0 (gents). Copied with a numeric-prefix reading of the text in SQL; a member with no gender is in neither list. Proved by the fixtures 902116 (Male) and 902118 (none) on both sides.
- **PHP's PDF cannot be compared for these three:** PHP's Dompdf ran out of its 256 MB memory on the parity database's waiting list (fatal error). Their PDF cases are `*-new-api.hurl` files; the real PDF renders fine through Gotenberg.
- **Planned surface:** `hosts/api/spec/planned-surface.hurl` pointed at `/reports/registrations/download` for membership; membership has no placeholder left (`api/Planned.cs` deleted, call removed from the module), so its check is dropped. The other domains' checks stay.

## Whole-batch numbers (test stack, last run)
- Build 0 warnings. Unit tests: access 64, assessment 1, classes 511, identity 63, membership 257, notifications 1, platform 248, host api 167, host site 12, shared 93. db tests 390 (new: 33 in `ReportsB5dTests`, plus the shared kit).
- `tools/identity-contract.sh test` pass; `membership-contract.sh test --prepare` and `classes-contract.sh test --prepare`; all-files Hurl: 140 files, 1581 requests, all pass.
- `tools/classes-contract.sh parity`: 84 files, 1105 requests pass on PHP. `tools/membership-contract.sh parity`: 24 files, 232 requests pass on PHP.
- `tools/export-parity.sh`: 26 cases, all SAME (two conduction cases and the unfiltered students case compared as a set of rows, see above).

## Deferred, flagged
- **xlsx edge cases not proved against PHP:** control characters (PHP escapes them, we drop them), text over 32767 characters, sheet names of non-ASCII titles (PHP cuts bytes, we cut characters). No route puts such text in a title today except a class code in none of them.
- **A text MAX uses the "C" collation** in the waiting list and the placed file (MariaDB's is case-insensitive): only matters when one token has two registrations (or two classes) differing in case only. Not seen in fixtures.
- **A member in two classes** shows PHP's independent MAX of each column in the placed file (code, level, teacher, extra); copied, but the fixtures hold no such member (the collation caveat above applies).
- **Dompdf on the parity stack** runs out of memory on large lists (registrations, donors): a PHP weakness, the reason for Gotenberg; not fixed there.
- **Not run:** the dev stack, `~/Projects/tsr-account`, any other vendor's model (as required). Package installs: ClosedXML and the Gotenberg image only.
- **Gateway:** nginx caches the API's address, so after the API container is recreated the gateway may answer 502 until it is recreated too (`tools/test-stack.sh down` then `up` did it); not changed.

## Process slips (added to those above)
- A `perl -0pi` edit with a replacement containing `$1` mangled `ReportConduction.cs` once; the file was rewritten from the slice's known content before anything ran on it.
- Several `perl` and `sed -i ''` edits instead of the editor tools (shell only mode); `build/dump.py` (standard library, run with `uv run python -I`) was a throwaway to read PHP's xlsx cell kinds.
- `export-parity.sh` first compared stale files after a `403` (a membership reset clears the classes fixtures): fixed (it now removes old files and fails on a non-200), and the cases file says to prepare membership first, then classes.
- The first run of `export-parity.sh` with unquoted arguments ran every case three times (noise only).
- Several db and platform tests were written after the code, not before (the Gotenberg client tests, the scope tests of the download routes); each scope test was then shown red by removing the row filter it guards (listed per route above, restored and re-run). The pure rules (`ReportXlsx`, `ReportHtml`, `ReportExport`, `AllocatedRegistrations`) were test first and seen red.

## Review and fixes (main thread, 11 Nov 2026)

- Review verdict: no authentication, row-scope, data-exposure, HTML/PDF injection or SSRF hole. The `precheck:` on `RequireMember` can only refuse before sign-in and changes no other endpoint; every value in the PDF HTML is encoded and the page loads nothing external; the moved queries are unchanged.
- Fixed (db test red first): the allocated-registrations export filtered `email not ilike '%.com'` where PHP has `NOT LIKE '%@thestrongrope.com'`, so every member with a .com address was dropped; no fixture had such an address. Test: `ReportsB5dTests.The_allocated_download_keeps_a_member_with_a_dot_com_address_and_leaves_out_only_placeholder_members` (uses the reserved domain example.com, since the rule needs a .com ending).
- Hardened: the gotenberg service sets `CHROMIUM_DENY_PRIVATE_IPS` and `CHROMIUM_DENY_PUBLIC_IPS` (Chromium may fetch no address; the report HTML needs none).
- Docs: the compose comment and the root `CLAUDE.md` now say `TSR_GOTENBERG_URL` is required at startup; `domains/identity/CLAUDE.md` describes the precheck; `__pycache__/` is ignored.
- Recorded, not changed: a token shared by two users gives two rows in the allocated file (PHP groups to one); no `Cache-Control: no-store` on exports with personal data (PHP sends none); no limit on concurrent PDF renders per caller (each up to 60 s); a 50000-row donors PDF will likely time out into the 503; the xlsx is built in memory; the image tag `gotenberg/gotenberg:8` is not pinned to a version or digest; the precheck is proven over HTTP by the Hurl files (an unsigned bad format is 422), not by a unit test of the middleware; PHP cannot produce the registrations and donors PDFs (Dompdf runs out of memory), so those cases are new-API only.

## Decisions applied after B5 (Asif, 11 Nov 2026; both stricter than PHP, each test seen failing first)

- Waiting list scope: `GET /reports/registrations` and its download show a caller who reaches only assigned classes just the people who asked for one of those classes (PHP: every waiting person of the gender). Callers who reach all classes or a whole gender are unchanged. `WaitingRegistrations.GuardAsync` now returns the class limit; the allocated export uses the same value. Proof: `ReportsB5bTests.Registrations_lists_only_...` and `ReportsB5dTests.Registrations_download_holds_...`.
- Caller address: one reading for the whole API, `shared/api/ClientAddress.cs` (moved from classes on its third user): the peer's address, or, when the peer is our own proxy (loopback or a private range), the last hop of X-Forwarded-For that is a valid address and not itself a proxy. A `Client-IP` header is never read. The sign-in record (`identity` `LoginTracking`) and the admin access log (`platform`) used to believe `Client-IP` and `X-Forwarded-For` as sent, as PHP does, so any caller could write any address into both. Proof: `LoginTracking.Tests.cs`, `ClientAddress.Tests.cs`, `SignInTests.Every_request_records_the_sign_in_as_the_limited_role`. The gateway appends the peer to X-Forwarded-For (`$proxy_add_x_forwarded_for`), which this rule relies on; a production edge in a PUBLIC address range in front of the gateway would be recorded as the caller.
