# PHP parity: POST /feedback

Run against tsr-account `develop` at commit `ed72cd98a1a9ed8f185ae031b6f29c9877e4cabf` (a clean
`git archive` in `build/parity-php/src/`), on synthetic data only. All PHP paths below are in that copy.
Stack, ports and rules: `tools/parity-php/README.md`.

## How to run
From the repo root. `P` is shorthand for the compose command (the env file feeds the compose variables).
```
P() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
mkdir -p build/parity-php/src && git -C ../tsr-account archive develop | tar -x -C build/parity-php/src   # first time only
P build api
P up -d --wait db firebase-emulator
P --profile load run --rm synth-build        # loads schema + synthetic members (about 1 min)
P up -d --wait api                           # PHP API on http://127.0.0.1:18091
```
Get a synthetic token (written to a gitignored file, never printed). Pick any member with token above 0,
a `.invalid` email, role 0, and no pending deletion request (the SQL gives one):
```
EMAIL=$(P exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth -N -e "select email from users u where token>0 and roleid=0 and email like \"%.invalid\" and token not in (select token from account_deletion_requests) order by token limit 1"')
tools/parity-php/mint-token.sh "$EMAIL"      # writes build/parity-php/token.vars
```
Run the file (PHP, then the new API; the new API takes its dev header):
```
hurl --test --variable base_url=http://127.0.0.1:18091 --variables-file build/parity-php/token.vars domains/platform/spec/tests/submit-feedback.hurl
hurl --test --variable base_url=http://localhost:8088 --variables-file build/dev/token.vars domains/platform/spec/tests/submit-feedback.hurl
```

## Results
| Case | PHP | New API |
|---|---|---|
| 1 No sign-in is 401 + detail | pass | pass (earlier run) |
| 2 Member gets 201 + id | pass | pass (earlier run) |
| 3 Replay returns same id | pass | pass (earlier run) |
| 4 Empty text 422 | pass | pass (earlier run) |
| 5 Whitespace text 422 | pass | pass (earlier run) |
| 6 Text over 2000 is 422 | pass | pass (earlier run) |
| 7 Missing clientId 422 + detail | pass | pass (earlier run) |
| 8 Replay with upper-case clientId returns same id | pass (2026-11-10) | pass (2026-11-10) |

PHP: 10 of 10 requests pass (8 cases), run 2026-11-10 from `submit-feedback.hurl`. New API: the same file passes
(10 of 10) on the dev stack on 2026-11-10; "earlier run" in cases 1 to 7 is the previous recorded result.
Case 8 uses a fixed clientId (Hurl has no upper-case filter), so a rerun is itself a replay. PHP treats a
clientId in other case as the same message: no difference to record.

## Confirmed differences (response bodies seen on the PHP run)
1. Auth: PHP wants `Authorization: Bearer <Firebase token>`; the new API takes `X-Dev-Token`. Hurl variables cover both.
2. Auth failures beyond 401. No token: 401 "Not authenticated" (`web/api/mobile/lib/auth.php:110`). Bad token: 401
   "Invalid auth token" (:124). Valid token, no member row: 404 "User not found" (:149). Guest (token 0):
   403 "Registration incomplete" (:159). `api.yaml` lists 401/403/422 only; no 404.
3. Missing or non-string `clientId` or `text`, or a body that is not an object: 422 "clientId and text are required"
   (`web/api/mobile/routes/feedback.php:19`). FEEDBACK-R7 and `api.yaml` say "clientId is required".
4. Malformed `clientId` (bad characters, over 36): 422 "clientId is required" (`web/models/feedback.php:27`).
5. Empty or whitespace text: 422 "text is required" (:32). Over 2000: 422 "text must be at most 2000
   characters" (:35). Exactly 2000 is accepted (201).
6. Unparseable JSON: 422 "Invalid JSON body" (`web/api/mobile/bootstrap.php:67`).
7. Earlier claim withdrawn: no permission-name difference at HTTP level. The route asks for `feedback:create`
   (routes/feedback.php:13) and the catalog holds `feedback:create:self` (`web/models/permissions.php:38`),
   which is action plus scope; a role-0 member got 201.

Not testable over HTTP: same clientId from another member, outbox events (PHP route has none). Not run on the
new API: non-string `clientId` (not yet a case) and `{"clientId": 123}` (spike-learnings suspects 400); add both once it is up.

## Suggestion
Follow PHP for status codes and the 401/403/404 set: the live app already sees them. Add 404 to `api.yaml`.
Keep the tests asserting "a non-empty detail" rather than exact wording, and make the new API's 422 detail
"clientId and text are required" if exact text matters to the app. Keep `X-Dev-Token` as dev-only.

---

# PHP parity: sign-in (identity, task 2b)

Contract: `domains/identity/spec/tests/link-account.hurl` (12 cases, 34 requests). Run on both sides, 2026-11-10:
PHP parity stack 34 of 34 pass; new API (dev stack, Auth emulator) 34 of 34 pass. Commands: `tools/identity-contract.sh dev` and `... parity`.

## Confirmed: PHP matched the recon
Every row of the recon's failure table that Hurl can reach behaved as written (status and `detail`): no header and non-Bearer 401
`Not authenticated`; bad token 401 `Invalid auth token`; no email 401 `Email not present in token`; no row 404; unverified email
404 on lookup and create routes; token 0 403 `Registration incomplete`; pending deletion 403 `Account deletion pending` with
`deletion_status`, while `/auth/link` stays reachable; completed deletion inside 2 hours 403 with the deleted message on a create
route; verified email claims a member with no Firebase id; first sign-in creates a member and the second finds it.

## Differences found
1. None in status or body against the recon.
2. Not testable through Hurl on either side (covered by .NET tests only): expired, not-yet-valid, wrong issuer, wrong audience,
   missing subject, keys unavailable, `Authorization: Bearer<TAB>x`.
3. `POST /auth/link` with no body and no `Content-Length`: PHP answers normally; behind the new gateway (nginx to Kestrel over
   HTTP/1.0) it answered 400. The Hurl file sends `Content-Length: 0`, which both accept. Check what the app's HTTP client sends before the gateway moves `/auth/link`.

## Deliberate small differences in the new API (not PHP bugs)
- Sign-in write: values longer than the column are cut to fit; PHP's strict database would reject the whole update (swallowed).
  A failed write is logged at warning level (PHP: `error_log`), and the request goes on.
- Token for a new member is max + 1 under a transaction lock; PHP has no lock (two first sign-ins at once can share a token).
- `/auth/link` returns `me` with `id`, `token`, `email` only; PHP's `me` also has profile and role fields.
- On first create or link PHP also writes `name` and `picture` from the token; those are profile columns (membership, phase 3) and are not stored yet.
- Emulator mode: copied as PHP does (email and verified flag from the emulator's `accounts:lookup`, 2 s timeout, uid must match).

---

# PHP parity: access (task 2a)

Contract: `domains/access/spec/tests/{me-permissions,me-permission,user-permissions}.hurl` (77 requests). Run 2026-11-10:
PHP parity stack 77 of 77 pass; new API (dev stack) 77 of 77 pass. Command: `tools/access-contract.sh dev|parity`.

## Differences found (PHP's real behaviour wins)
1. **The parity database has 101 permissions, not 102.** Its reference seed (exported from PHP) predates
   `2026_10_22_quiz_reset_permission.sql`. The recon was right about the code. `tools/access-contract.sh parity` applies PHP's own
   idempotent migration so both sides hold 102. No fixture holds `quiz:reset:all`, so no body changed.
2. **Catalog order is ordinal.** MariaDB `ORDER BY name` equals byte order for these names (`children-performance:...` before
   `children:link:...`); the new API sorts ordinally in code instead of trusting a Postgres locale.
3. Role 6 (class teacher) holds nothing in `role_permissions`, as the recon says; confirmed over HTTP (fixture `teacherrole`).
4. The guest never reaches `forUser` over HTTP: 403 `Registration incomplete` from sign-in. Covered in unit and db tests.
5. Recon match otherwise: member set 21 names, role 1 = 38 grants, 3 and 4 = 18, 5 = 13, 7 = 1.

## Open difference: accent-insensitive rule matching (found in review, settle when `classes` is built)
PHP matches class access rule text (city, country, tag) with `LOWER(a) = LOWER(b)` under MariaDB's `utf8mb4_unicode_520_ci`, which is
also accent-insensitive (`Zürich` equals `Zurich`). The new API compares with ordinal ignore-case, which is not. Not built now: it
needs real class fixtures to decide (a collation, `unaccent`, or folding in code). It must be settled when `classes` is built.

## Identity: `users.email` is not unique in PHP
`migrations/2026_10_28_users_email_index.sql` adds a deliberately non-unique index (the column is nullable and may repeat), and
`api_update_login_info` updates every row with the email. The new `identity.users.email` index is non-unique and the sign-in write
updates every row with that email, as PHP does. No unique index.

## Identity: sign-in write and token time (found in review, fixed)
- `lastlogin` is written only when the request carries at least one tracking value (`api/mobile/lib/auth.php:280-283`, early return).
- A signed Firebase token with `iat` in the future and no `nbf` is refused (php-jwt, leeway 0). With an `nbf` in the past it is
  accepted, and PHP's emulator decoder never checks `iat` against the clock; both are copied.

## Access: `assigned` can list a class twice
PHP's `class_access` view has one row per (rule, class), so two rules reaching class 5 give `assigned: [5,5]` in
`GET /me/permissions`; `assigned_genders` and `searchReach` stay unique. Copied (`Quirk` test).

## Platform batch A and B (phase 3a): app version, release notes, geo

Run on the same parity stack (PHP 8.5.12 in the image), synthetic data only. Both sides answer the Hurl files in
`domains/platform/spec/tests/` (`tools/platform-contract.sh parity|dev`). The two catalog responses were also compared
byte for byte (`cmp`): identical. Where the recon (`phase-3-platform-recon.md`) and the PHP source differ, PHP won:

1. **Recon 3.4: `"  AB  "` is 6 characters, not 5.** The rule (length before trim) is right; the example count was not.
2. **Recon 3.1: "not a JSON object gives the fallback".** PHP's `is_array` also accepts a JSON LIST (`[]`, `[1,2]`, a list
   with a `releases` key is impossible), so a list is a "usable catalog" that gives the fallback blocks. Same output
   either way; copied (`APPVER-D2`).
3. **`releases` and `notes` given as JSON objects** are walked as their values in file order (PHP `foreach`). Copied.
4. **`-0` is an integer** in PHP 8.5 (`json_decode('-0')` is `int(0)`), `12.0`, `1e2` and a number above 64 bits are floats.
   Copied: an integer is a JSON number with no fraction or exponent that fits 64 bits.
5. **The release `date` regex has no `D` flag**, so `"2030-01-01\n"` passes; `\d` is ASCII only. Copied (the date is returned as written).
6. **A byte order mark makes the whole file unusable** (`json_decode` fails): fallback. Copied. Duplicate keys: last wins. Copied.
7. **PHP's `trim` strips only space, tab, newline, carriage return, NUL and vertical tab**; `strtoupper` is ASCII only;
   `mb_strlen` counts code points, before the trim. Copied with `PhpText` (.NET's `Trim()` would also strip a no-break space).
8. **A postal code of exactly `"0"` is never looked up** (`array_filter`), and only an ASCII space splits a code. Copied.
9. **`rate_limit_allows` is a sliding window of whole seconds** (its own doc comment says "fixed-window": the code is not).
   A refused call is not recorded. 61 calls with bodies that fail validation still give 60 x 422 then 429, on both sides
   (checked with curl on both). The 429 detail is `Too many lookups; try again in a minute`.
10. **The deletion gate applies to the geo routes** (recon open question 8): a member with a pending deletion gets 403
    `Account deletion pending` with `deletion_status`, on PHP and on the new API (checked on both).
11. **`api_cast` rules for geo:** countries `code` and `name` are plain strings, `hasPostalCodes` is a boolean; postal values are raw
    (an empty string stays `""`, only SQL NULL is `null`); city `name` is entity-decoded and an empty name would be the number `0`;
    an empty or NULL `state` is `null`.
12. **A guest (token 0) never reaches geo:** `api_authenticate` answers 403 `Registration incomplete` first, so the "per address
    for a guest" rate limit key in the PHP comments cannot occur.
13. **PHP swallows every database error in `LocationModel::rows()`** and answers empty. The new API keeps only the missing-table
    case (logged); any other database error is an error (a deliberate difference, `GEO-D3`).

Deliberate differences, none visible to a normal client: a catalog file over 1 MiB is unusable (PHP reads any size); a geo body over
16 KiB is 413 (PHP reads any size); a trailing space in a stored postal code is not ignored (MariaDB's PAD SPACE ignored it; input is
trimmed so it cannot be reached); HTML5-only entity names beyond the common ones (`&AMP;` `&LT;` `&GT;` `&QUOT;` `&COPY;` `&REG;` and
the HTML 4 set are decoded) stay as written; JSON escaping of `<`, `>`, `&`, U+2028 may differ in bytes, never in meaning.

## Membership batch 3b-2: profile, class request form, guardian self-service (ten operations)

Read from tsr-account's code and probed on the parity stack (synthetic members only). Each quirk below is copied, with the test that
proves it; the capability documents (`domains/membership/capabilities/`) hold the requirement IDs.

**Where the recon and the PHP source differ (the source won)**

1. **`mobile: null` is a 500** (recon: "unverified"): it passes validation and `users.mobile` is NOT NULL. Copied (`PROF-Q5`).
2. **A language that is not entirely a number is a 500** (`"2abc"`: `(int)` is 2, so it validates, then MariaDB refuses the text), and **a decimal rounds**: `2.5` and `"2.5"` store 3. Copied (`PROF-Q4`).
3. **A non-scalar value for a text column is stored as `"Array"`** (`name: ["x"]` validates as the 5-letter string "Array"). PHP also prints a warning into the response body on the parity stack (its `display_errors`); the warning is not copied (`PROF-Q3`).
4. **A duplicate id in `interestIds` is a 500 after the old choices were deleted** and the first copy was inserted (unique key `unique_student_interest`). The recon did not mention it. Copied (`REG-Q2`).
5. **The accept route maps the model's status, not its http_code**: a child nobody holds is 404 `Invite not found` (the model says 422 for the parent check but 404 for the child check); a shared-token caller is 422. Copied (`GRD-Q2`).
6. **`GET /registration` takes the lowest id** of a token's rows (no ORDER BY in PHP; observed: the Pending row of the duplicate pair).
7. **`selectedInterestIds` has no ORDER BY in PHP**; the new API orders by interest id.
8. **PHP's 500s answer HTTP 200 with an HTML error** on the parity stack, so a 500 is never asserted in Hurl; `db/tests` proves each one.
9. **Hurl runs files in parallel** (`--test`): two files changing the same member race. Every fixture member a file changes is used by that file only (`registrant.update` is a copy of `registrant.duplicates` for that reason).

**Quirks copied** (profile): untrimmed stored text; `gender` stored as the text of what was sent ("1abc" validates, stores, reads back null; 1.9 and `true` read back 1); `age_range` never validated; a mobile or zip ending in a newline passes (PCRE `$`); a name longer than 50 only counts after trim; the place rules compare trimmed values and check only a changed field; the postal code's state and city win over what was sent unless empty or "0"; `GET /me` shows an empty name as the integer 0; `Male`, `Female`, empty and null gender read as null, never 0; the gender lock treats a null gender as 0 (a clear is a change) and does not look at the class's own status.

**Quirks copied** (class request): the update changes every row of a token and wipes `for_classid`, `profession` and the legacy `interests`; the three writes are separate and unguarded; a non-empty `languages` map of only invalid entries erases the saved languages; an empty array or `{}` leaves them; an `interestIds` array (even empty) replaces the choices; `birthYear` "abc" is 0 with no range check; a dropdown value must equal a label exactly, else null; multi-select duplicates are kept; an array inside a multi-select is a `TypeError` (500); an object is an array (its values are used).

**Quirks copied** (guardians): every accept 422 carries one text; the 403 rule asks about the invite's creator, with the child's `(int)` gender; a revoke ends every active row of a duplicate pair; a revoked row stays when the pair is linked again; a token in the path is `(int)` cast ("abc" is 0); `created_by_name` is `Invite link` for source `link`, else the creator's name or `Unknown`; the list joins users by token so a shared token doubles the row; the inspect call counts toward 60 an hour even when it answers not_found.

**Deliberate differences, none visible to a normal client**
- A body over 1 MiB is 413 `Request body too large` (PHP reads any size).
- The two guardian lists are capped at 200 rows (PHP has no cap); ties on `created_at` break by id.
- The gender lock reads the caller's own profile by user id; PHP reads `users` by token, the first row (differs only for a token two members share).
- Entity decoding uses .NET's table (HTML 4 plus `&apos;`); PHP knows every HTML5 name, so an obscure name stays as written here.
- A float in a text field is formatted with 14 significant digits; PHP's exponent form (`1.0E+25`) formats differently.
- The postal regex from the database runs on .NET's engine with a 250 ms timeout (PHP: PCRE); a broken or slow pattern is "no match", as PHP's `@preg_match` false is.
- The log lines (`profile.gender_change_refused`, `parent_invite_inspect.rate_limited`) carry no member token.
- The 403 text is PHP's (`You do not have permission to do that`); the shared `Problem.Forbidden` says `Not allowed` and is not used here.
- The inspect rate limit is per API process (like the geo one).

**Not proven end to end**: the permission 403 (the member set gives every member these permissions and nothing can deny them); the gender lock against real enrolments (no classes yet: proven with a fake port in NUnit and a host-level fake in `db/tests`); the 500s above (db/tests only).
