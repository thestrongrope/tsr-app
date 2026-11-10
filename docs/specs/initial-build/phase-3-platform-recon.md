# Phase 3 recon: the `platform` domain

Read-only recon of `~/Projects/tsr-account` (PHP, branch as checked out). PHP paths are under
`web/api/mobile/` unless they start `web/`. Domain per operation: `operation-domains.csv`
(slice names are the PHP handler names; sizes S/M/L are a first guess; non-platform tables are `?`).

## 1. Operations per domain and size

| Domain | S | M | L | Total |
|---|---|---|---|---|
| access | 7 | 6 | 0 | 13 |
| assessment | 7 | 19 | 17 | 43 |
| classes | 12 | 43 | 26 | 81 |
| content | 1 | 0 | 2 | 3 |
| identity | 5 | 5 | 0 | 10 |
| membership | 11 | 10 | 5 | 26 |
| notifications | 10 | 11 | 4 | 25 |
| platform | 6 | 2 | 1 | 9 |
| search | 1 | 0 | 0 | 1 |
| **All** | **60** | **96** | **55** | **211** |

Judgement calls: `GET/PATCH /me` -> membership (profile; the `users` row itself is identity);
`/me/children/*/scores`, MCQ reports -> assessment; `/reports/quran-leaderboard*` -> content;
`/reports/pending/nudge` and class notifications -> notifications; `/admin/donors*`,
`/registrations/*` -> membership; `/admin/transfers`, `/admin/teachers*`, syllabus, guides ->
classes. `/admin/donors` is NOT platform even though it uses the same download helper.

Platform = 9 operations, 2 built (`GET /health`, `POST /feedback`), **7 left**: `GET /app-version`,
`GET /release-notes`, `GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities`,
`GET /admin/access-log`, `GET /admin/access-log/download`.

## 2. Shared conventions every platform operation relies on

- Errors: `{"detail": "..."}` (`lib/response.php:api_fail`). Unknown path 404 `Not Found`; known path,
  wrong verb 405 `Method Not Allowed` (`index.php:~325`).
- Member auth `api_authenticate(true)` (`lib/auth.php:106`): 401 `Not authenticated` (no bearer),
  401 `Invalid auth token`, 401 `Email not present in token`, 404 `User not found`, 403
  `Registration incomplete` (token 0), 403 deletion gate (`Account deletion pending`, body also has
  `deletion_status`). The `true` CREATES a users row if absent, and writes login info and syncs
  Firebase claims on every call (identity's concern; platform just calls the middleware).
  The deletion gate allowlist (`API_DELETION_ALLOWED`) does not list geo or access-log, so a member
  with a live deletion request gets the 403 there (not checked line by line; confirm in phase 2 notes).
- Permission check `api_require(action)` (`lib/response.php:232`): 403 `You do not have permission to do that`.
- JSON via `api_send`: `JSON_UNESCAPED_SLASHES|UNICODE|PRESERVE_ZERO_FRACTION`. Rows pass `api_cast`
  (`lib/response.php`), whose rules matter below: non-nullable field with null or `''` becomes the zero of
  its type, and **`text` non-nullable with `''` becomes the integer `0`** (only `str` gives `''`).
- DB: MariaDB/MySQL, `utf8mb4`, native prepares, so INT/COUNT come back as numbers.

## 3. Operations to build

### 3.1 `GET /app-version` (public)
- Route `routes/app_version.php:222` `route_app_version`; logic `api_app_version_payload` `:62`.
- Auth: none (deliberate: an old build may hold an expired token). No rate limit.
- Request: none.
- Source: JSON file `web/data/app_versions.json` (path built `__DIR__/../../../data/app_versions.json`,
  `:112`). No SQL, no writes. Read on every request, no cache.
- Response (always an object, cast `(object)`): `{android:{minimumBuild:int, recommendedBuild:int, storeUrl:str, latest?:{version:str, notes:[str]}}, ios:{...same}, announcement?:{id,title,body}}`.
  Key order: android, ios, announcement. `latest` and `announcement` are ABSENT (not null) when not applicable.
- Fail-open rules (all return 200, never an error):
  - file missing, unreadable, or not a JSON object -> whole fallback payload: both platforms
    `minimumBuild:1, recommendedBuild:1`, `storeUrl` android `https://play.google.com/store/apps/details?id=com.thestrongrope`,
    ios `https://apps.apple.com/app/id6807232453`; no `latest`, no `announcement`. Logged with `error_log`.
  - per platform: needs an entry that is an array whose `minimumBuild` is a real JSON **integer**
    (`is_int`: a quoted `"12"` or `12.0` fails) else that platform alone gets the fallback block.
  - `recommendedBuild` = entry's int, else = `minimumBuild`. `storeUrl` = entry's non-empty string, else fallback URL.
  - `latest`: first release in file order whose `builds[platform]` is an int **equal to** `recommendedBuild`
    (strict `===`); gives `{version, notes}`; none -> key omitted.
  - releases are validated one by one (`:149`): need non-empty string `version`, string `date` matching
    `^\d{4}-\d{2}-\d{2}$` (format only, 2026-99-99 passes), and an array `builds`; else dropped. `builds` keeps only int
    values for android/ios. `notes` kept only if non-empty strings, re-indexed.
  - `announcement`: needs non-empty string `id` and `title`; `body` = string else `''`. Malformed -> omitted
    (not fatal). `null` or absent -> omitted.
- Quirks: `is_int` strictness; unknown extra keys (`_comment`) ignored; PHP `json_decode` accepts big
  ints as floats (then `is_int` fails). Date is never emitted here, only validated. Duplicate JSON keys:
  last wins (PHP and System.Text.Json agree only if configured).

### 3.2 `GET /release-notes` (public)
- Route `:239`; `api_release_notes_payload` `:229`. Same file, same validation, no auth.
- Response: `{"releases":[{version:str, date:"YYYY-MM-DD", notes:[str], builds:{android?:int, ios?:int}}]}`,
  file order kept ("newest first" is the file's job, not sorted). Missing/corrupt file -> `{"releases":[]}`.
- Quirk: `builds` is `[]` in PHP JSON when empty (empty array, not `{}`; a release with no int builds
  serialises `"builds":[]`) and `{"android":..}` otherwise. A typed client reading both shapes is exactly
  what the `(object)` cast elsewhere guards against; here it is NOT guarded. Parity means reproduce `[]`.
  Same for `notes` (always a list).

### 3.3 `GET /geo/countries`
- Route `routes/geo.php:48`; model `web/models/location.php:23` `countries()`. Guard `api_geo_guard` `:32`.
- Auth: `api_authenticate(true)` then rate limit; **no permission** (guests finishing sign-up included).
  Rate limit `rate_limit_allows('geo', 60, 60, 'member-<token>')` (`web/functions.php:1168`): file-based sliding
  window per member, **every call counts, including ones that later 422**; 61st in 60 s -> 429
  `Too many lookups; try again in a minute`. State is a file under `cache/geo/` (sha256 of key); if the dir
  is unwritable it allows. The 429 comes after 401/404/403 and before body validation.
- SQL: `select code, name, has_postal_codes from geo_countries order by name` (no limit, no filter).
- Response: `{"countries":[{code:str, name:str, hasPostalCodes:bool}]}`. DB error (table missing) is swallowed
  (`rows()` logs `geo.unavailable`) -> `{"countries":[]}`.
- Quirks: order is by the column collation `utf8mb4_unicode_520_ci` (accent- and case-insensitive,
  e.g. "Cote d'Ivoire" sorts among C), not ordinal; Postgres needs an ICU collation to match. `code` is CHAR(2).

### 3.4 `POST /geo/postal`
- Route `:55`; model `location.php:41` `byPostalCode`. Same guard and rate limit as 3.3.
- Body `{country, code}`. Validation `api_geo_text` (`:41`), in order country then code; any failure ->
  422 `country is required and must be at most 2 characters` / `code is required and must be at most 20 characters`.
  Fails when: not a string (numbers too), blank after `trim`, or `mb_strlen(untrimmed) > max` (code points,
  measured BEFORE trim, so `"  AB  "` with 5 chars is fine, 1-char country is allowed). Missing body
  (`api_body` returns `[]`) -> same 422; invalid JSON -> 422 `Invalid JSON body`.
- Logic: `country = strtoupper(trim)`, `code = strtoupper(trim)` (ASCII-only). Tries `[code]`, plus the part before
  the first space if the code contains a space (UK `SW1A 1AA` -> `SW1A`, `M5V 3L9` -> `M5V`). `array_filter`
  drops falsy tries, so a code of exactly `"0"` is never looked up.
- SQL (per try, first hit wins): `select city, state from geo_postal_codes where country_code = ? and postal_code = ?`
  (PK is the pair, so at most one row; comparison uses the ci collation, trailing spaces ignored).
- Response 200: `{found:bool, city:?str, state:?str}`; not found -> `{"found":false,"city":null,"state":null}`.
  Values are raw DB strings, NOT passed through `api_cast` (no entity decoding; `''` stays `''`, only SQL NULL is null).
- Quirk: country is not checked against `geo_countries`; an unknown country is just `found:false`.

### 3.5 `POST /geo/cities`
- Route `:68`; model `location.php:68` `searchCities`. Same guard and rate limit.
- Body `{country, query}`: country max 2 chars, query max 100; same 422 wording pattern
  (`query is required and must be at most 100 characters`).
- SQL: `select name, state from geo_cities where country_code = ? and name like ? escape '|' order by population desc, name limit 10`.
  `like` = query with `| % _` escaped (`|` first) plus trailing `%`: a prefix match, wildcards literal.
  Limit is fixed at 10 by the route (model accepts 1..25, default 10).
- Response: `{"cities":[{name:text, state:text?}]}`, cast with `text`: HTML entities decoded (`&amp;` -> `&`),
  `state` `''`/null -> null, and a non-nullable `name` of `''` -> `0` (cannot happen with the data but is the rule).
- Quirks: prefix match is case- and accent-insensitive via `utf8mb4_unicode_520_ci` ("zur" finds "Zurich" and
  "Zürich"; Postgres `ILIKE` is not accent-insensitive); ties after `population desc` break on collated `name`;
  duplicate names (same city in two states) are both returned; table is ~171,000 rows with index (country_code, name).
  Table missing -> `{"cities":[]}`.

### 3.6 `GET /admin/access-log`
- Route `routes/access_log.php:35`; model `web/models/auditlog.php` (`AuditLogModel`).
- Auth: `api_authenticate(true)` -> `api_require('audit-log:read')` (no target; catalog name
  `audit-log:read:all`, held by role 1 only, plus named `user_permissions` grants). Then the query filters.
  Order of failures: 401/404/403 first, then 422 for filters.
- Query params: `token` (optional): `trim`med; non-empty and not `ctype_digit` -> 422 `token must be a member number`
  (so `-1`, `1.5`, `abc`, `1e3` all 422); `"0"` is a valid filter. `page` (optional): trimmed substring filter on `page`.
  No pagination, no sort params (model sorts exist but the route never passes one).
- SQL (all prepared, on `admin_access_log l`, `LEFT JOIN users u ON u.id = l.user_id`):
  1. users: `select l.token, coalesce(u.name,''), coalesce(u.email,''), count(1) hits_30d, count(distinct date(l.accessed_at)) active_days_30d, max(l.accessed_at) last_accessed ... where l.accessed_at >= :since [and l.token = :token] [and l.page like :page_like] group by l.token order by hits_30d desc, last_accessed desc` (unbounded).
  2. pages: `select l.page, count(1), max(l.accessed_at) ... same where ... group by l.page order by hits_30d desc, last_accessed desc`.
  3. recent: `select l.id, l.accessed_at, l.page, l.method, l.ip, l.token, l.roleid, u.name, u.email ... [where token/page only, NO time window] order by l.id desc limit 500`.
  `:since` = `date('Y-m-d H:i:s', strtotime('-30 days'))` computed in PHP (PHP `date.timezone=UTC` in `webapp-php.ini`; the
  API container's value was not verified), compared to a `TIMESTAMP` column. `like :page_like` = `'%' . page . '%'` with
  **no escaping** (a `%` or `_` typed by the admin is a wildcard).
- Response: `{users:[{token:int, name:str, email:str, hits:int, activeDays:int, lastAccessed:str}], pages:[{page:str, hits:int, lastAccessed:str}], recent:[{id:int, accessedAt:str, token:int, name:str, email:str, role:str, method:str, page:str, ip:str}]}`.
  Times are the DB string `YYYY-MM-DD HH:MM:SS` (space, no `T`, no zone), unlike `api_cast` datetimes which use `T`.
  Null -> `''` for name/email/ip and **`token` null -> 0**. `role` = `roleName`: null -> `''`, 0 Member, 1 Admin, 3 Gents admin,
  4 Ladies admin, 5 Class admin, 6 Class teacher, 7 Finance, anything else (including 2) `Role N`.
- Side effects: none (this route does not write the log; `api_authenticate` writes login info on the users row).
- Quirks: (a) `group by l.token` with non-aggregated `u.name/u.email`: legal on MariaDB defaults, arbitrary pick when one
  token has rows with different `user_id`; Postgres rejects it, so pick a rule (see open questions). (b) A NULL `token`
  forms its own group and serialises as 0. (c) `page` LIKE is case/accent-insensitive (`utf8mb4_unicode_ci`).
  (d) `recent` ignores the 30-day window; `users`/`pages` honour it, so the three lists can disagree. (e) Tie order of
  equal `hits`+`last_accessed` is undefined. (f) `ip` may be IPv6 (VARCHAR 45).

### 3.7 `GET /admin/access-log/download?format=xlsx|pdf`
- Route `:84`. **Order differs from 3.6**: `api_report_download_format()` (`reports.php:35`) runs FIRST, so a bad or
  missing `format` is 422 `format must be xlsx or pdf` even for an unauthenticated caller; then auth, permission, then
  the same `token` filter 422.
- SQL: `select l.accessed_at, l.token, coalesce(u.name,''), coalesce(u.email,''), l.roleid, l.method, l.page, l.ip, l.user_agent, l.referer ... where l.accessed_at >= :since [token][page like] order by l.id desc`, **no limit**.
- No rows -> 404 `No accesses match`.
- Response: a file, not JSON. `Content-Type` xlsx `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` or `application/pdf`;
  `Content-Disposition: attachment; filename="TSR_Admin_Access_Log_<YmdHis UTC>.<format>"`; `Content-Length`.
- Content: one section, heading `Admin access log, last 30 days, <Y-m-d>`; headers `Time, Member, Name, Email, Role, Method, Page, Address, Device, Referrer`;
  every cell passed through `spreadsheetSafe` (null -> `''`; a value whose first non-space char is `= + - @` gets a leading `'`),
  so every cell, including Member, is TEXT. xlsx: title row 14pt bold, blank row, heading bold, header row bold, auto-size columns,
  sheet title `Admin access log` (31-char cap, `[]:*?/\` replaced by space), cells written with explicit types.
  PDF: Dompdf, A4 landscape, DejaVu Sans 9px, HTML-escaped, remote fetching off.
- Side effects: none. Quirks: filename and heading use PHP clock (UTC); a rewrite cannot reproduce the exact bytes of an xlsx/pdf, so
  contract tests can only check status, headers, and (for xlsx) cell contents after parsing. Large logs are loaded fully into memory.
  Dompdf font coverage (Arabic/Urdu names in `Name`) is whatever DejaVu Sans renders.
- Shared helper `ReportExportModel` (`web/models/reportexport.php`, PhpSpreadsheet + Dompdf) serves all report downloads in every
  domain (and `/admin/donors/download`); decision needed on where the C# equivalent lives (shared/api, not platform rules).

## 4. Tables

Platform would own (from `migrations/`; C# will use Postgres, types noted for MariaDB source):

| Table | Columns (MariaDB) | Notes |
|---|---|---|
| `feedback` (built) | id INT AI, user_id INT null FK users, client_id CHAR(36), message TEXT, created_at DATETIME, handled_at, handled_by | `2026_11_09_feedback.sql` |
| `admin_access_log` | id BIGINT UNSIGNED AI, accessed_at TIMESTAMP default now, user_id INT null, token INT null, roleid INT null, page VARCHAR(255) not null, method VARCHAR(10) not null, ip VARCHAR(45) null, user_agent VARCHAR(512) null, referer VARCHAR(512) null, session_id VARCHAR(128) null; keys on accessed_at, token, page; collation `utf8mb4_unicode_ci` | `002_create_admin_access_log.sql`. No FK to users. |
| `geo_countries` | code CHAR(2) PK, name VARCHAR(100), has_postal_codes TINYINT(1) default 0, postal_code_regex VARCHAR(255) null | ci_520 collation. Read-only at runtime. |
| `geo_postal_codes` | country_code CHAR(2), postal_code VARCHAR(20), city VARCHAR(255) null, state VARCHAR(150) null; PK (country_code, postal_code) | ~1.1M rows, loaded by `tools/geonames/load.php` (GeoNames, CC BY 4.0; credit must show wherever data shows) |
| `geo_cities` | geoname_id INT PK, country_code CHAR(2), name VARCHAR(200), state VARCHAR(150) null, population INT default 0; key (country_code, name) | ~171k rows |
| `lookups` | id INT AI, type VARCHAR(50), code VARCHAR(100), label VARCHAR(255), sort_order INT, is_active TINYINT, created_at TIMESTAMP; unique (type, code); collation `utf8mb4_0900_ai_ci` | `2026_08_21_lookups_table.sql`. NO HTTP route reads it directly (used by `LookupsModel` for registration option lists and validation). Platform owns it per domains/CLAUDE.md; no slice exists for it in phase 3. |
| `outbox`, `outbound_messages`, `schema_migrations` | n/a | not touched by the 7 remaining operations |

Tables the remaining operations read that belong to another domain:
- `users` (identity): `admin_access_log` left-joins `users.name`, `users.email` on `user_id`. Decision: platform may not read identity's
  table (rule 3). Options: an identity-owned read interface (`IUserDirectory` returning name/email by user id), or denormalise name/email
  into the log row at write time (changes the data), or an event-fed copy. Also the PHP stores `token` and `roleid` in the log itself.
- Roles come from the hard-coded `ROLE_NAMES` map in `auditlog.php`, not a table; the role ids belong to `access` (the C# side keeps roles in `access.user_roles`).
- `admin_access_log` is WRITTEN by other domains' admin routes (see 5) and by the PHP web pages (`web/header.php` path); both PHP and C#
  write to the same table while the gateway splits traffic, so schema changes are expand-only.

## 5. Cross-cutting: who writes `admin_access_log`

`api_log_admin_action` (`lib/audit.php:24`) -> `log_admin_page_access` (`web/functions.php:392`) is called from the admin gates of other
routes: `member_enrol.php:92,131`, `class_manage.php:340,480,618,746`, `whatsapp_reminders.php:245`, `notifications.php:47`,
`syllabus.php:68`. Rules: only when `roleid` in {1,3,4,5,7} (`is_privileged_roleid`) unless `$viaGate`; skipped for basenames `login.php`, `logout.php`
and a student-page list; once per request; `page` = request path cut to 255 (which path form PHP logs behind the proxy was not verified);
errors are swallowed. When those domains move, each needs a platform interface (e.g. `AuditLog.RecordAsync(caller, request)`) listed in its
`Dependencies`, or an `admin_action_performed` event. Not an operation, but the data `GET /admin/access-log` shows is empty without it.

## 6. Config and external dependencies (names only)

- File `web/data/app_versions.json` (baked into the image; changing it needs a redeploy; no volume mount). C# needs the file at a configured path and
  a fixture copy for tests; the PHP and C# images must serve the same file, so one source (the file stays in tsr-account until cutover).
- Disk state: `cache/geo/*.json` rate-limit counters (PHP). C# needs an in-memory or DB limiter; a per-process limiter is weaker behind several instances.
- Env: `FIREBASE_PROJECT_ID` (token verification, identity), DB settings via `get_settings()`; `DEBUG` (logging only). PHP `date.timezone = UTC` (`webapp-php.ini`).
- Libraries behind the download: PhpSpreadsheet (xlsx), Dompdf (pdf). No third-party HTTP calls in any platform operation. Geo data is local, not GeoNames live.
- Trusted-proxy logic for client IP (`is_trusted_proxy`, `X-Forwarded-For`) only matters for the guest rate-limit key, which cannot occur here
  because `api_authenticate(true)` always yields a token.

## 7. Suggested build order

| Batch | Operations | Complexity | PHP-side fixtures | C#-side fixtures |
|---|---|---|---|---|
| A | `GET /app-version`, `GET /release-notes` | file validation matrix | a synthetic `data/app_versions.json` for the parity stack, plus variants: missing file, quoted `"12"`, string `recommendedBuild`, bad date, missing `builds`, announcement without `title`, unmatched `latest` | the same files behind a config path; unit tests on the validator (no DB). Hurl can only test the happy file; variants go in unit tests on both sides |
| B | `GET /geo/countries` | collation + rate limit | `geo_countries` rows incl. an accented name and `has_postal_codes` 0/1 (MariaDB) | `platform.geo_countries` migration + `seed.sql` rows; limiter built here (reused by C and D) |
| C | `POST /geo/postal` | validation + space fallback | `geo_postal_codes` rows: plain, `SW1A`-style outward code, a code with a space whose full form also exists, a code `0` | same data in Postgres; add rows with city NULL and state NULL |
| D | `POST /geo/cities` | LIKE escaping, ordering, entity decode | `geo_cities` rows: same prefix with different populations, accented and unaccented name, name containing `%` or `_`, name with `&amp;`, duplicates | same data; case/accent-insensitive collation decided |
| E | `GET /admin/access-log` | identity read, grouping, windows | `admin_access_log` rows: one old (>30 d), recent ones across several tokens/pages/roles (0,1,2,9), a NULL token, a token whose `user_id` has no user, ones with differing `user_id` for one token; synthetic users 900003 (role 1) and a member (403) | the same rows via `seed.sql` (accessed_at relative to now); access seed grants `audit-log:read` to role 1; decision on users lookup (section 4) |
| F | `GET /admin/access-log/download` | file generation | same rows as E | shared xlsx/pdf export helper (new in `shared/`, not platform logic) and its dependency choice |

Hurl files are one per slice and run against both stacks, as `submit-feedback.hurl` does; Hurl cannot change the clock or the file, so the validation matrices for A and the rate limit (B-D, the 61st call) belong in unit tests.

## 8. Open questions where the PHP is ambiguous

1. `admin_access_log` users summary `group by l.token` with non-aggregated name/email: which row's name wins when a token maps to several `user_id`s (account deletion anonymises the user row, a deleted user's rows could differ)? PHP gives an arbitrary one. Proposed rule: the name of the row with the largest `id`.
2. Timezone: is the API container's PHP `date.timezone` UTC (the file `webapp-php.ini` says so; the API image was not checked) and what is the DB session time zone for `TIMESTAMP`? The 30-day cutoff and `accessed_at` strings depend on both.
3. Which path string does PHP log in `admin_access_log.page` for API calls (with or without a `/api/mobile` prefix)? Matters for the `page` filter and for the C# writer.
4. `routes` `$_GET['token']`/`page` given as arrays (`token[]=1`): PHP turns this into the string `Array` (a notice) and returns 422 `token must be a member number` for token, and a literal `%Array%` filter for page. Reproduce or reject differently?
5. Accent/case-insensitive matching: do we reproduce MariaDB collations (Postgres ICU nondeterministic collation, or `unaccent`+`lower`) for geo cities, geo postal codes and the page LIKE? Required for exact parity; it costs index design on 171k and 1.1M rows.
6. `GET /release-notes` `builds` serialises as `[]` when empty but `{}` is probably what the Dart client wants; keep `[]` for parity (recommended) or fix (a behaviour change, separate)?
7. Rate limit state: per-process in memory is acceptable for the first cut? PHP's is per-host file; counts include calls that fail validation.
8. Is the deletion-gate allowlist applied to geo and access-log in C# (identity middleware) the same way as PHP (blocked while a deletion is live)?
9. Home of the xlsx/pdf generator and of the audit-log write interface (section 5): `shared/api` versus a platform public interface; needs a decision before batch F and before the first admin route of another domain moves.
10. Should `GET /app-version` keep reading the JSON file, or does platform take over the data into a table? (Phase 3 goal is parity, so the file stays; flag for later.)
