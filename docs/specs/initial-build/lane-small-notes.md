# Lane "small": notes for the test phase

Five routes, build-out mode (port first, prove later). No Hurl, fixtures or db tests were written; the gate was build (0 warnings) plus the unit suites of `hosts/api`, platform and classes.
PHP files are under `build/parity-php/src/web/` (not in git).

## Routes

| Route | PHP | Slice | Queries |
|---|---|---|---|
| GET /holy-quran | `api/mobile/routes/conduction.php:227`, `models/holyquran.php` | `domains/content/api/features/holy-quran/HolyQuran.cs` | 1: `content.holy_quran` ordered by id (EF, at most 200). Classes already reads the same rows through `content.v_quran` (`ConductionData.HolyQuranAsync`); nothing duplicated. |
| GET /admin/access-log | `api/mobile/routes/access_log.php:35`, `models/auditlog.php` | `domains/platform/api/features/admin-access-log/` | 3 in `domain/AccessLog.cs`: summary by member (30 days), by page (30 days), recent 500 (no window) |
| GET /admin/access-log/download | `access_log.php:84` | `.../admin-access-log-download/` | 1: every access in the 30 days (at most 50000), shared helper; `ReportExport` |
| GET /reports/quran-leaderboard | `routes/reports.php:1629` (guard `:1588`), `models/quranrecitation.php:17` | `domains/classes/api/features/report-quran-leaderboard/` | 2: levels, ranked rows (`domain/QuranLeaderboard.cs`, also used by `StudentsReport`) |
| GET /reports/quran-leaderboard/download | `reports.php:1649` | `.../report-quran-leaderboard-download/` | same, no top-100 cut (at most 50000) |

Platform now lists `membership` and `identity` in `Dependencies` (views only: `membership.v_members` for names, `identity.v_users` for emails; reader lists updated in their CLAUDE.md files). Content's and platform's `Planned.cs` are gone (nothing left to place).

## Assumptions

1. The brief's description of the access log (rows with the member name, a 30-day window) is thinner than PHP: PHP answers `{users, pages, recent}` with `token` and `page` filters. I ported PHP.
2. The two leaderboard routes are built in `classes`, domain column in `operations.csv` changed to `classes` (the main thread's assumption, by the same reasoning as the eight MCQ reports; Asif has not decided this one).
3. Auth column of all five is `create` (PHP `api_authenticate(true)`), not `member` as the catalog said for the leaderboard.
4. Times of the access log are text `YYYY-MM-DD HH:MM:SS` in UTC (PHP: the server's local time as MariaDB stored it); active days count UTC dates.
5. `token` filter: digits only (else 422 "token must be a member number"); a number past int64 saturates and matches nothing. A `page` filter containing a NUL byte matches nothing (PHP/MariaDB would too; PostgreSQL would 500 on a NUL), so no 500.
6. A summary row of PHP's member grouping takes `max(name)` and `max(email)` per token (MariaDB picked any row; names are the same per token).
7. A null token reads 0 (PHP `(int) null`).
8. Default `from` = one year before `to` with PHP `strtotime('-1 year')`: 29 February becomes 1 March of the year before. Range check at most 5 x 366 days apart, message "The range can cover at most five years".
9. The level is matched by exact name (ordinal), first in sort order; the level names come in sort order (`levels[]`).
10. Bounds added where PHP has none: access-log summaries and downloads at most 50000 rows; leaderboard download at most 50000 rows. A real log or leaderboard beyond that is silently cut (no flag in the response).
11. Tie order within the same rank is by token then class id (PHP: unspecified).

## Looks like a hole (copied, flagged)

- The leaderboard's row scope uses the **`reports:read`** assigned-only list, not `quran-leaderboard:read`. A caller who holds only the leaderboard permission and no `reports:read` gets whatever `AssignedOnlyIds` returns for an action they lack (probably null, so every class). Check what the engine returns and whether PHP does the same.
- The leaderboard lists every member of every reached class by name and token; the gender lock only narrows by the member's own gender text. No demo-class exclusion, a removed enrolment is only excluded through `cs.status = 'A'` (removed_at is not checked), so a member removed but with status still 'A' would appear: confirm the two columns agree in the data.
- The access log exposes name, email, role, IP address, user agent and referrer of every admin access to any holder of `audit-log:read` (role 1 only in the catalog). Download adds IP, device, referrer. Personal data by design; confirm the holder set.
- `l.page LIKE '%' || page || '%'`: `%` and `_` in the filter are wildcards, as in PHP (a cost, not a leak).

## The test phase must prove

- [ ] GET /holy-quran: 401 without a token, 200 with a list of 114 in id order, `arabic` is "" when null; a first sign-in creates the member row.
- [ ] Access log: 401, 403 without `audit-log:read`, 422 for `token=abc` and `token=1.5`, token and page filters narrow all three lists; `users` and `pages` exclude rows older than 30 days, `recent` does not; at most 500 recent; `role` names (including "Role n" and ""); NUL in `page` gives empty lists, not 500.
- [ ] Download: bad `format` is 422 BEFORE a 401; 403; 404 "No accesses match"; xlsx and pdf; formula-like values get an apostrophe; file name and heading; compare against PHP (parity) for column order and text.
- [ ] Leaderboard: 403 without `quran-leaderboard:read` for the gender, gender lock wins over `?gender`; dates (default year, 422s, five-year limit 1830 days, 29 February); `level` unknown is 422, known narrows the rows but NOT the ranks; `minimum` forms (`0`, `+5`, `-1`, `007`, `2.5`, `abc`, huge); ranks are global and equal for ties; a member in two active classes appears twice with the same rank; top 100 with `total` counting all; no demo-class exclusion; assigned-only caller limited to their classes.
- [ ] Students report (`/reports/students`) is unchanged: its recitation column now comes from `QuranLeaderboard.RankedAsync` (same query, minimum 0, level 0, 1000 rows); run its existing Hurl and db tests.
- [ ] Leaderboard download: numbers stay numbers; file name `Quran-leaderboard-<Gents|Ladies>-<from>-to-<to>`; empty result is a file with headers only.
- [ ] Parity with PHP for all five (`tools/export-parity.sh` cases for the two downloads).
