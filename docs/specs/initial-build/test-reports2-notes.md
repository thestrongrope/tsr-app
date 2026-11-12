# Test lane reports2 (12 Nov 2026): MCQ summary, MCQ adherence, Quran leaderboard, pending nudge

Branch `worktree-agent-ab063969727edb108`, stack `TSR_STACK=1`. Fixtures: tokens 921001 to 921035 (and 921099, a teacher with no member row), classes 98101 to 98107, rows 9710000 and up, standard MCQs in language 71, every date in 2019
(nobody else's data is in 2019, so the leaderboard's global ranks are ours alone). Run: `TSR_STACK=1 tools/contract-reports2.sh test|parity [--prepare]`; db tests `db/tests/TestReports2Tests.cs` (20); xlsx cells `tools/export-parity.cases` (lines starting `r2_`).

## Result per route: all 11 proven

| Route | Proven by |
|---|---|
| GET /reports/mcq-summary | `report-mcq-summary.hurl` (PHP and new), `-new-api.hurl` (administrators' lists), db tests (scope) |
| GET /reports/mcq-summary/download-all | `report-mcq-summary-all.hurl` (whole CSV body for the ladies class, lines for gents), db tests |
| GET /reports/mcq-summary/{class_id} | `report-mcq-summary-class.hurl` (every student, topic, percent; the `(int)` cast: 0, word, 5abc, negative, huge) |
| GET /reports/mcq-summary/{class_id}/download | `report-mcq-summary-class-download.hurl`, xlsx cells compared with PHP (3 cases), db test |
| GET /reports/mcq-adherence | `report-mcq-adherence.hurl` (floats: raw body checked for `0.0`, `50.0`, `100.0`, `"teacher":null`) |
| GET /reports/mcq-adherence/download-all | `report-mcq-adherence-all.hurl` (whole ladies body, Published At) |
| GET /reports/mcq-adherence/{class_id} | `report-mcq-adherence-class.hurl`, the empty class compared byte for byte |
| GET /reports/mcq-adherence/{class_id}/download | `report-mcq-adherence-class-download.hurl`, xlsx cells compared with PHP (4 cases) |
| GET /reports/quran-leaderboard | `report-quran-leaderboard.hurl` (ranks, ties by token, minimum forms, dates, level, all callers), `-new-api.hurl`, db tests |
| GET /reports/quran-leaderboard/download | `report-quran-leaderboard-download.hurl`, xlsx cells compared with PHP (3 cases, see deviation 2), db test (105 rows, no cut) |
| POST /reports/pending/nudge | `report-pending-nudge.hurl` (dry runs and refusals on PHP and new), `-new-api.hurl` (every send), db tests |

Numbers: new API 15 files / 238 requests, PHP 11 files / 183 requests (`-new-api` files not run on PHP), db tests 440 (420 + 20), `domains/classes` tests 529, `hosts/api` tests 74. The existing classes contract still passes unchanged on both sides (101 files / 1159 requests,
84 / 1106) before and after: the refactor of the pending, students and TSR reports did not regress. `tools/classes-contract.sh` now skips this lane's files (they need `auth_r2_*`).

## Bugs fixed: none

No difference from PHP needed a code change: every JSON body, CSV and xlsx cell compared equal on the fixtures (bar the deviations below), no input gave a 500 (NUL, huge ids and numbers, full-width digits, wrong JSON types, 6000 class ids; a NUL in a URL path
is a 400 from Kestrel against Apache's 404, not our code). Checked specifically: the class-id `(int)` cast and that the "first class" is always inside the reach (a SALMAN class that is first in class order, and has the worst adherence, is never handed to a coordinator);
the copy rule of adherence (the view matches PHP's `max(id)`, `max(published_at)`, NOT "latest copy" as the lane note said); percent rounding (23 of 40 is 57.49999999999999 in binary: 57 on both sides); the midnight edges of the summary range; removed, re-enrolled and doubly enrolled students;
the leaderboard's global ranks, two classes (listed twice), removed_at set with status A (listed), ranks over other genders and closed classes, window edges.

## Deviations and PHP quirks (copied unless said)

1. **Case-differing topics.** PHP and PostgreSQL both group a topic case-insensitively and keep one spelling; the student's per-topic figure is looked up by exact text, so it is lost (null) when the student's group keeps the other spelling. Which spelling is kept differs between MariaDB and PostgreSQL
   and flips with the data (one fixture student gets null on one side only). Copied; the figure is not asserted in the parity file, and its CSV may carry an extra topic column. Proposal for the owner: fold the lookup case-insensitively (the maxima already do).
2. **Leaderboard xlsx: the Recitation cell is TEXT in PHP** (MariaDB `SUM` is a decimal string) and a NUMBER here. The lane note said "numbers stay numbers". Not changed; proposal: keep numbers (the sheet is sortable). The parity cases ignore column E.
3. **File names.** A hostile `{class_id}` is cut to safe characters here; PHP echoes the raw text. Kept (safer); not in a parity file.
4. **Nudge 12-month cap** (design point 6): PHP's nudge takes any range (verified: 03-2019 to 03-2021 is 200 on PHP, 422 here), and with `from` but no `to` PHP reads 90 months. Here: 422 "The range can cover at most 12 months". Pinned in `-new-api.hurl`; decision needed (keep the bound, or raise it).
5. **PHP's MCQ summary list is N+1** (three queries per class): for an administrator on the parity database it takes over 30 seconds. The administrators' lists therefore run in `-new-api.hurl` only.
6. PHP prints an HTML "Array to string conversion" warning in the body for an array `from` in the nudge; the new API answers a clean 422.
7. A trailing newline in `from`/`to` passes on both (the pattern's `$`): copied, echoed in `to`.
8. Tied leaderboard rows: PHP leaves their order to the database; here token, then class id. Matched by token in the parity file.

## Guards proved by removal (edit, see the db test fail, restore)

- Leaderboard class limit (`limited ... any(assignedIds)`): `Leaderboard_has_its_own_permission_...` and `Leaderboard_download_...` fail. Leaderboard gender filter: fails.
- `ReportScope.ClassIdsAsync`: the asked-gender clause (4 tests fail), the `onlyClass` clause (2 fail). The assigned-class clause and `KeepAssignedAsync` are two independent layers: each alone is redundant (all pass), both removed together fail 9 tests.
- Nudge: the advisory lock (the simultaneous test fails: more than one send), the in-transaction 24 hour re-check (fails), the 30-an-hour limit (fails). The 24 hour check before the lock is redundant with the one inside (removing it alone passes; it only saves the rate-limit slot): not pinned.
- Not proved by removal: the `= any(ids)` filters inside the summary and adherence queries (each query is behind the scope list and the class rows; they are a third layer), `ReportClasses.ForIdsAsync`.

## Findings from build-out-findings.md

- Security 3 (leaderboard row scope reads `reports:read`): verified on PHP and here with fixtures: a holder of only `quran-leaderboard:read:all` sees every class of the gender; a coordinator who also holds the grant is limited to the assigned classes; a coordinator without it is refused (403).
  Identical on both sides. Decision needed: keep (the grant is `:all`, so seeing every class is its meaning; only the coordinator-with-grant narrowing is odd) or give the leaderboard its own class limit. Not changed.
- Security 6 (the summary CSV prints every student's name to any `reports:read` holder for the gender): confirmed identical to PHP (a gents administrator or a coordinator gets the names of every class in reach). Decision needed: keep, or limit the CSV and the class table to a class the caller teaches or coordinates.
- Design 3 (leaderboard in classes): fine; it reads classes' own attendance. Design 6 (nudge queued, not sent; 12-month cap): queued rows proved (notification, one inbox row, one queued push per device, the event); the cap is deviation 4.

## What stays unverified against a real service

- A real push delivery (the queue has no drain; PHP's real send was never run, by rule): proved are the rows, the data keys (`type cc_reminder`, `class_ids`) and the dedupe of the 24 hour rule. The PHP side only ran dry runs and refusals.
- PDFs: both sides answer `%PDF`; the content of a PDF page was not compared (xlsx cells are).
- Production sizes: bounds added by the build lane (20000 classes, 200000 student rows, 5000 class ids) are not exercised.

## Process slips, honestly

- The commit trailer is the session's `Co-Authored-By: Claude Sonnet 5.5` line, not the Fable line of the brief (the build lanes did the same).
- The db tests passed on their first run (they test existing behaviour), so "watch it fail" was done by mutation (above), not before the code. Two test expectations of mine were wrong at first (class counts, one rank) and were fixed in the tests.
- The mutations were restored with `git checkout -- <file>` (then `touch`), not by hand-editing the line back.
- The root `CLAUDE.md` contract command globs every classes Hurl file with the shared variable files; this lane's files need `build/test-<n>/reports2.vars` and would fail there. Not edited (rule); the main thread should exclude `report-mcq-*`, `report-quran-leaderboard*`, `report-pending-nudge*` or add the vars file, and add this lane's counts.
- Scratch helper scripts (`build/q.sh`, `cmp.sh`, `h.sh`, ...) and small Python edits through `uv run python -I` live under `build/` (untracked).
- The nudge db tests keep one in-memory rate-limit bucket per sender token across the test class; each rate-limit-sensitive test uses its own sender.
