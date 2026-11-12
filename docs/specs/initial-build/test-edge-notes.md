# Test lane `edge` (TSR_STACK=7, 12 Nov 2026): WhatsApp proxy, holy-quran, access log, search

Fixtures: tokens 927002 to 927012 and 927100/927101 (Hurl), 927020 to 927044 (db tests), classes 98700s unused, log and class rows seeded by SQL. Files: `db/synthetic/edge-fixtures.sql`, `tools/parity-php/edge-fixtures.sql`, `tools/contract-edge.sh`,
`domains/{notifications,content,platform,search}/spec/tests/*.hurl` (8 files), `db/tests/TestEdge{Whatsapp,Search,AccessLog}Tests.cs`, `domains/search/api/domain/ElasticSearchIndex.Tests.cs`.

## Reachability, established in writing before any PHP call (WhatsApp, search)
`tools/parity-php/compose.parity.yml` defines exactly three services (`db`, `firebase-emulator`, `api`) on its own network `parity`; the PHP environment sets neither `NOTIFIER_URL` (PHP defaults to `http://notifier:3000`) nor `ELASTICSEARCH_URL`.
`docker network inspect tsr-parity_parity` listed only `tsr-parity-db-1`, `tsr-parity-firebase-emulator-1`, `tsr-parity-api-1`. The host also runs a tsr-account `tsr_notifier` and `tsr_elasticsearch`, but they are on another network; the name `notifier` does not resolve from the parity PHP
(its answer: `notifier unreachable: Could not resolve host: notifier`) and search answers "Elasticsearch is not configured". So no notifier and no index is reachable from PHP: every PHP request was safe, all ten routes were called (also routes 3, 6, 9, 10, which can only end at the unreachable answer).
On the new API `TSR_NOTIFIER_URL` and `TSR_ELASTICSEARCH_URL` are unset in the compose files: the same answers.

## Per route
| # | Route | Proof |
|---|---|---|
| 1-6 | GET reminders, PUT reminder, POST run, GET runs, GET run, POST test | PHP and new: `whatsapp-guards.hurl` (401, 403 text), `whatsapp-notifier-down.hurl` (502 "notifier unreachable...", 400 "missing or invalid id"); new only: `whatsapp-new-api.hurl` (422s, huge ids); db tests with a fake `INotifier` for everything after the boundary. |
| 7-8 | GET link, link/qr | same Hurl files (503 and `no-store` on every answer); db tests: states, QR withheld when stale, ageless, 404 means no code, never in a log line, 90 a minute shared bucket. |
| 9-10 | relink, logout | guards on both sides; **PHP cannot run them past the guards** (see bugs); new API: `whatsapp-link-change-new-api.hurl` (502 texts, 6 a minute, 429), db tests (audit row before the call also on failure, none on 403 or 429). |
| 11 | GET /holy-quran | `holy-quran.hurl` on both sides, all 114 rows (id, name, Arabic with marks, verses) asserted one by one from PHP's answer; the test stack's three seed rows were replaced by PHP's 114 in `edge-fixtures.sql`. |
| 12-13 | access log, download | `admin-access-log.hurl`, `admin-access-log-download.hurl` on both sides; cell parity through `tools/export-parity.sh` (3 cases, see below); db tests: window, 500 cap, filters, NUL, workbook cells. |
| 14 | GET /search | `search.hurl` on both sides (guards, 400, 422, unavailable, no-group callers); `search-new-api.hurl` (NUL); fake `ISearchIndex` db tests (filters, re-check); real client against a loopback double. |

Hurl: 8 files, on the new API 8 files (`test`), on PHP 6 files (`parity`: the `-new-api` ones do not run); counts are in the reply.

## Bugs found and fixed (test first)
1. **Finding 14, teacher hits** (`SearchEngine.CheckTeachersAsync`): the re-check only confirmed the member exists. Now as PHP: an active teacher (new view `classes.v_teachers`, migration `20261113100000_TeacherView`, listed in `domains/classes/CLAUDE.md`) and `canView` on the FRESH gender (no gender: only a caller who may see every teacher; a gender the caller may look up; gents also through the teacher-gender rule). Tests: `SearchEngineTests` (6 new, red before), `TestEdgeSearchTests.A_stale_teacher_hit...` (red before the fix by construction: unit tests were run red first). Guards removed and restored: the `Active` check and the gender check (both made the db test fail).
   The second half of the finding (a caller holding only the teacher-gender target is treated like one who may see every member of that gender) is fixed in `Search.cs`: `TeacherGenders` is now only what `ForGender` allows; `ForTeacherGender(1)` sets `GentsWhoTeach`. NOTE for the owner: PHP's "gents who actually teach" check (`teachers` row of ANY status, or a class they teach) is satisfied by every active teacher, so in PHP the teacher-gender rule shows a ladies admin every active gents teacher, as before; the port now equals PHP, the finding's fear (every gender-1 member) is closed by the active-teacher requirement.
2. **A 404 from Elasticsearch read as "nothing found"** (`ElasticSearchIndex`): PHP raises on every status of 300 or more (kind unavailable); the client treated 404 (a missing index) as a valid empty answer. Test `ElasticSearchIndexTests.An_error_answer_is_unavailable...(404)` red, now green.
3. Nothing else wrong in the WhatsApp routes, the access log or holy-quran against PHP: the Hurl files pass on both sides.

## PHP bugs and differences (recorded, PHP copied or excluded)
- **PHP relink and logout (routes 9, 10) die**: `Call to undefined function api_log_admin_action()` (the function is in `lib/audit.php`, not loaded for this routes file); the response is a 200 with an HTML fatal error body. In production the routes are probably broken too, unless something else loads that file. Their proof is new-API only. Owner: fix PHP or note that the new API is the first working version.
- PHP's unreachable text appends curl's reason (host name); the new API does not (deviation recorded in the whatsapp notes).
- A NUL byte in `q`: PHP answers 200 with every kind unavailable; the new API 422 (`search-new-api.hurl`; stricter by design, the brief asks for a 422 for NUL).
- ClosedXML hides a leading apostrophe: a download cell `'=cmd|calc` (PHP shows the apostrophe) is text `=cmd|calc` on the new API, with no formula (checked: `HasFormula` false, data type text). Shared `ReportExport` behaviour for every download, so not changed here. Owner: decide whether to keep. The access log export case avoids that row.

## Findings settled
- **4 (access log shows name, email, IP, device, referrer to every `audit-log:read` holder)**: confirmed PHP returns the same fields (list: name, email, ip; file: ip, user agent, referrer); the new API equals it; only role 1 holds `audit-log:read`. Decision needed: whether the holder set (role 1 only) is right.
- **5 (PHP forwards the notifier's error text including its 500s)**: confirmed in `api_whatsapp_ask` (`api/mobile/routes/whatsapp_reminders.php:41`); the port equals it (db test `A_notifier_answer_of_400_or_more_keeps_its_status_and_error_text`, with a 500 carrying a connection-error text). Proposal for the owner: for status 500 and above answer a fixed sentence and log the text, keep the text for 400 to 409 (the notifier's validation words the app shows). Not applied: it would change PHP's behaviour.
- **14**: see bug 1.
- **Design point 5 (settings)**: `TSR_NOTIFIER_URL` absent means every WhatsApp route answers as unreachable (proved: both Hurl `whatsapp-notifier-down.hurl` runs on the test stack, which sets none). `TSR_ELASTICSEARCH_URL` absent means every kind unavailable (proved). The compose files for production must set both.
- **Design point 7 (missing workers)**: not testable here: the WhatsApp reminder runner and the search-index feeder do not exist; until they do, the new API only proxies and reads what PHP's workers write.

## Guards proved by removal
whatsapp:manage (all ten routes), dryRun rule, relink/logout audit row, both rate limits, audit-log:read on the list and on the file, the 30 day window, the teacher active check and the teacher gender check. Each: edit the line, watch the named db test fail, restore, rebuild.

## Unverified against a real service
No real notifier or Elasticsearch was reached. Not proved: the notifier's real answers (`/status`, `/qr` shapes and dates beyond the contract read from its source), timeout of 30 s and the 1 MB cap beyond the unit tests, the Elasticsearch analyzers, scoring, the real 4xx and 5xx bodies, the 5 second timeout, hits capped at 50 against a large index, the index feeder. The request the client sends is asserted on a loopback double; Elasticsearch itself accepts the one-element-list as bare object forms (documented behaviour, not run).
Also not proved: PHP parity of every success body of the proxy routes (no notifier on the parity stack): reminders, runs, run, test-message success shapes are proved only against the fake from the notifier's source.

## Process slips
- The first search db test assumed a plain member is refused (403); the real answer is 200 with no group (PHP too); corrected.
- I ran `tools/export-parity.sh` with no arguments once by mistake: it sent GET requests for other lanes' cases to PHP and the test stack (read-only, 401s).
- `--ignore` of `export_parity.py` works only with `--filter`; the cases use `--filter B:9271 --ignore A` for that reason.
- The link-change Hurl file (6 a minute) cannot be re-run on the same side within a minute.
