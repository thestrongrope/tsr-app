# Phase 3 recon: the `membership` domain

Read-only recon of `~/Projects/tsr-account` (PHP, branch `develop`). PHP paths are under `web/api/mobile/`
unless they start `web/`. Operations and sizes: `operation-domains.csv` (26 rows, S 11, M 10, L 5); permission
checks: `permission-map.csv`. Format follows `phase-3-platform-recon.md`. Column definitions come from
`tools/synthetic-data/schema.sql` (a schema-only dump) and `migrations/`; no database, `.env` or data file was read.
Anything not confirmed is marked **unverified**. No real member data appears here.

## 1. Operations

Auth column: all 26 are member routes (`api_authenticate(true)`, which creates a `users` row if absent; identity's
concern). None is public, none a "create route" in the identity sense except that `true` flag on every one.
Order of failures everywhere: 401/404/403 from identity, then the permission, then validation, except where noted.

| # | Method, path | PHP | Permission (target) | Size | Why |
|---|---|---|---|---|---|
| 1 | GET `/me` | `routes/users.php:34` | `profile:read` | S | one row cast to 16 fields; allowed while deletion is pending |
| 2 | PATCH `/me` | `users.php:49` | `profile:update` | M | 9 validated fields, geo checks (platform), gender lock (classes), search touch |
| 3 | GET `/me/children` | `routes/children.php:23` | `children:read` | S | links + each child's active classes (classes data) |
| 4 | GET `/me/children/links` | `children.php:313` | `children:read` | S | caller's links, one query |
| 5 | GET `/me/children/link/{code}` | `children.php:286` | `children:link` | S | rate limited, 3 states |
| 6 | POST `/me/children/link/{code}` | `children.php:238` | `children:link` | M | accept invite under a lock, 9 refusals |
| 7 | DELETE `/me/children/{child_token}/link` | `children.php:328` | `children:link` | S | one UPDATE, 204 |
| 8 | GET `/me/parents` | `children.php:435` | `parents:manage` | S | child's active parents |
| 9 | DELETE `/me/parents/{parent_token}` | `children.php:450` | `parents:manage` | S | one UPDATE, 204 |
| 10 | POST `/members/{child_token}/parent-links` | `children.php:180` | `parents:add`, or `parents:manage` when caller token = child token | M | staff scope check, 5-invite cap under lock |
| 11 | GET `/members/{child_token}/parent-links` | `children.php:207` | as 10 | M | same guard as 10 (the weight is the guard) |
| 12 | DELETE `/members/{child_token}/parent-links/{id}` | `children.php:221` | as 10, then creator or `parents:manage` (gender) | S | one SELECT, one UPDATE |
| 13 | GET `/members/{child_token}/parents/candidate/{parent_token}` | `children.php:350` | `parents:add-direct` + scope in the model | S | name lookup, rate limited |
| 14 | POST `/members/{child_token}/parents` | `children.php:380` | `parents:add-direct` + scope, then `parents:manage` (gender) | M | 9 refusals, lock |
| 15 | GET `/registration` | `routes/registration.php:20` | none (token > 0 only) | S | 4 small reads |
| 16 | POST `/registration` | `registration.php:50` | none; own row | M | 17 fields, lookups whitelists, 3 write blocks |
| 17 | GET `/reports/registrations` | `routes/reports.php:1678` (model `models/subscribers.php:584`) | `registrations:read` (gender) | L | waiting-list SQL with MAX() grouping and class joins |
| 18 | GET `/reports/registrations/download` | `reports.php:1710` | as 17 | L | 17 + xlsx/pdf export |
| 19 | GET `/reports/registrations/allocated/download` | `reports.php:1745` (model `subscribers.php:495`) | `registrations:read` (gender), reach | L | 25 columns, joins classes, levels, teachers |
| 20 | GET `/registrations/{registration_id}/classes` | `routes/registrations.php:42` | `registrations:read` (both genders probe, then registrant's) + `students:enrol` per class | M | needs the classes list and per-class permission |
| 21 | POST `/registrations/{registration_id}/place` | `registrations.php:70` | as 20, then `students:enrol` (class) | L | writes classes' enrolment table; cross-domain command |
| 22 | POST `/registrations/{registration_id}/reject` | `registrations.php:95` | `registrations:read` then `registrations:reject` (gender) | M | one UPDATE, guard is the work |
| 23 | GET `/admin/donors` | `routes/donors.php:31` | `donors:read` | S | one join |
| 24 | GET `/admin/donors/download` | `donors.php:37` | `donors:read` | L | 23 + shared xlsx/pdf export |
| 25 | GET `/students/{token}` | `routes/entity_cards.php:18` (model `models/entityaccess.php:34`) | `classes:read`; reach in model | M | needs classes and `access` reach |
| 26 | GET `/subscribers/{token}` | `entity_cards.php:42` (model `entityaccess.php:60`) | `classes:read`; reach `all` only | M | as 25 |

Router facts (`index.php:297`): `{x}` matches `[^/]+`, so a non-numeric `{token}` is accepted and `(int)` casts it to 0.
Unknown path 404 `Not Found`, wrong verb 405 `Method Not Allowed`. Route order: `/me/children/links` is listed before
`/me/children/link/{code}`; there is no clash. Not in the 26 but sharing the models: `GET /me/children/{token}/classes...`
(4 routes, classes and assessment), `memberDetails` (`entityaccess.php:112`, `members:enrol-by-token`, route in `member_enrol.php`: classes).

Shared conventions: errors `{"detail": "..."}`; JSON via `api_send` (`UNESCAPED_SLASHES|UNICODE|PRESERVE_ZERO_FRACTION`, `lib/response.php:133`);
`api_cast` rules (`response.php:28-130`): non-nullable null or `''` becomes `''` (`str`), 0 (`int`), false; **`text` non-nullable `''` becomes the integer 0**;
`int` on a non-numeric string is null (nullable) or 0; `text` decodes HTML entities; `datetime` swaps the space for `T`; `date` is the raw string.
`204` sends no body (content type still `application/json`). `api_body()` (`bootstrap.php:59`): empty body is `[]`; invalid JSON or a JSON scalar is 422 `Invalid JSON body`.
Permission refusal 403 `You do not have permission to do that` unless a route passes its own text (only `place` does).

## 2. Per operation

### 2.1 `GET /me` (`users.php:34`)
- Permission `profile:read` (member set). Allowed during a live deletion request (`API_DELETION_ALLOWED`, `auth.php:41`), the only membership route that is.
- Source: the session user row (`select *` from `users`, built by identity). Cast with `api_user_spec` (`users.php:12`), key order: `id int, token int, email str, name text, roleid int, picture str?, gender int?, age_range int?, mobile text?, country text?, state text?, city text?, language int?, zip text?, sendupdates str?, unsubscribe str?`.
- Null rules from the cast: `name` null or `''` becomes `0` (an integer), `gender` `'Male'` or any non-numeric becomes null (not 0), `language` 0 stays 0, `mobile ''` becomes null, `picture` is not entity-decoded.
- `roleid` comes from `access.user_roles` in the rebuild; `id`, `token`, `email` from identity; the rest from membership. The profile response is assembled by membership with two reads from other domains (see 4).
- Side effects: none beyond identity's per-request sign-in write.

### 2.2 `PATCH /me` (`users.php:49`)
- Permission `profile:update`. Blocked during a live deletion (403 `Account deletion pending`).
- Body fields used (only these; others ignored): `name, gender, age_range, mobile, country, state, city, language, zip`. Presence is `array_key_exists`, so an explicit `null` counts as present.
- No updatable key sent: 200 with the current profile, **no validation of anything** (`users.php:63`).
- Validation (`api_validate_profile_field`, `users.php:116`), in key order name, gender, age_range, mobile, country, state, city, language, zip; first error wins, 422; a `null` value skips validation:
  - `gender`: `(int)$value` in {1,2} else `Invalid gender value. Use 1 for Male, 2 for Female.` (`"1abc"`, `1.9`, `true` pass.)
  - `language`: `(int)` in {1,2,3} else `Invalid language value. Use 1 for English, 2 for Urdu, 3 for Gujarati.`
  - `mobile`: `''` or `/^\+?[0-9]{10,15}$/` else `Invalid mobile number`.
  - `zip`: `''` or `/^[0-9A-Za-z\s-]{3,12}$/` else `Invalid ZIP code`.
  - `name, city, state, country`: `trim` then: empty `<Field> cannot be empty` (`Name`, `City`, `State`, `Country`, via `ucfirst`); `mb_strlen < 2` `Must be at least 2 characters`; `> 50` `Must be at most 50 characters`; any control char `[\x00-\x1F\x7F]` `Contains invalid characters`. The stored value is the **untrimmed, unescaped** original. Letters, scripts and punctuation are allowed (history in the comment at `:148`).
  - `age_range`: **no validation** at all (any scalar; stored raw).
- Place rules (`users.php:74-100`, via `LocationModel` `models/location.php:136`): compared with the stored values (only a changed field is checked, trimmed). First problem in this order wins, 422: `State cannot contain numbers`, `City cannot contain numbers`, `Choose your country from the list` (only when the country list is loaded, matched `lower(name)=lower(?)` against `geo_countries`), `That does not look like a postal code. Leave it empty if you do not have one.` (zip has `@`, or 10+ digits that are neither a held postal code nor match the country's `postal_code_regex`). Then, when zip is non-empty, zip or country was sent and either changed, `fromPostalCode` (country must have `has_postal_codes`) overwrites `state` and `city` in the update with the data's non-empty values, whatever was sent.
- Gender lock (`users.php:105`, `subscribers.php:46`): if `gender` is in the body: `(int)` of it differs from the stored `(int)` gender, the stored one is 1 or 2, and the member has any `class_students` row with `removed_at is null and status='A'` (the class's own status is **not** checked) then 422 `Gender cannot be changed while you are enrolled in a class`, and `log_event('profile.gender_change_refused')`. `null` becomes 0 for this check, so `gender:null` clears the gender for a non-enrolled member.
- Write: one `UPDATE users SET <fields>` with the sent values as sent (PDO binds a bool as `'1'`, a float as text). Then, if `name` or `gender` is non-null in the update and the token is above 0, `SearchOutboxModel::touch('person', token)` queues an `outbound_messages` row (channel search, recipient `person:<token>`, dedupe `person:<token>:<unix time>`; failures swallowed).
- Response: the row re-read and cast as in 2.1. 200.
- Quirks to copy: untrimmed names; `age_range` free; `mobile:null` passes validation then hits `mobile NOT NULL` (500 in strict mode; **unverified**); `gender:"1.5"` stores `1.5`; the response `gender` uses the `int?` cast so `'Male'` reads null.

### 2.3 `GET /me/children` (`children.php:23`, model `guardians.php:705`)
- Permission `children:read`. Response is a bare list (not wrapped, not cast): `[{token:int, name:str, first_name:?str, last_name:?str, gender:int, relationship:str, classes:[{class_id:int, class_name:str, class_code:str, status:str}]}]`. Empty `[]`.
- Queries: (1) `user_guardians ug JOIN users u ON u.token = ug.child_token WHERE ug.parent_token = :caller AND ug.status='active' ORDER BY ug.id ASC` (inner join: an unknown child token drops the row; a token shared by two users doubles it); (2) per child `class_students cs JOIN classes c WHERE cs.token_no=:t AND cs.status='A' AND cs.removed_at IS NULL AND c.status='A' ORDER BY c.id`. `gender` is `(int)` of the varchar (so `'Male'` is 0). `status` is always `'A'`. Caller token 0 or less: `[]`.

### 2.4 `GET /me/children/links` (`children.php:313`, `guardians.php:618`)
- Permission `children:read`. Bare list of raw rows (PDO native types): `id, parent_token, child_token, child_name, relationship, status, source, created_at, created_by_name, activated_at, revoked_at`. Dates are `Y-m-d H:i:s` strings, nulls are null.
- SQL: `user_guardians ug LEFT JOIN users u ON u.token=ug.child_token LEFT JOIN users cb ON cb.id=ug.created_by WHERE ug.parent_token=:caller ORDER BY ug.created_at DESC` (all statuses, but pending invites have a NULL parent, so only active and revoked appear). `created_by_name` = `'Invite link'` when `source='link'`, else the creator's `name` or `'Unknown'`. Ties on `created_at` are unordered. Token 0 or less: `[]`.

### 2.5 `GET /me/children/link/{code}` (`children.php:286`, `guardians.php:312`)
- Permission `children:link`, then rate limit `parent_invite_inspect`, 60 per 3600 s per `member-<token>` (every call counts), 429 `Too many lookups; try again later` (note: not the geo wording), `log_event('parent_invite_inspect.rate_limited')`.
- SQL: `select ug.status, ug.expires_at, u.first_name from user_guardians ug LEFT JOIN users u ON u.token=ug.child_token where ug.code=:code limit 1`.
- Response 200 `{state}`: `not_found` (no row), `expired` (status not `invited`, i.e. used or cancelled, or past `expires_at`), `valid` plus `first_name` (string or null). Never reveals more. No writes.

### 2.6 `POST /me/children/link/{code}` (`children.php:238`, `guardians.php:195`)
- Permission `children:link`. Body `relationship` (string; trimmed and lower-cased; one of `father, mother, guardian`).
- Checks in this order (status text is internal; the route maps it): no row `not_found` 404 `Invite not found`; row not `invited` or expired 410 `This link has expired or has already been used`; caller token 0 or ambiguous 422; caller = child 422; caller = the invite creator's token 422; bad relationship 422; child unknown 404 `Invite not found`, child token shared 422; then under the child lock (re-reads the row, 410 again): child previously revoked this parent and the **invite creator** lacks `parents:manage` for the child's gender: 403 `This person was removed by the child; ask an admin for a new link`; active link exists: 409 `An active link already exists for this parent and child`; update matched 0 rows: 409 same text. All the 422 cases carry `Invalid relationship or self-link not allowed`.
- Write: `UPDATE user_guardians SET parent_token, relationship, status='active', activated_at=CURRENT_TIMESTAMP WHERE id=:id AND status='invited'` (the invite row becomes the link; a prior revoked row for the pair stays).
- Response 200 `{child_token:int, relationship:str, status:"active"}`. Side effects: none (no notification).
- The lock is `UPDATE users SET roleid = roleid WHERE id = <child user id>` in a transaction (`guardians.php:122`); `users.roleid` no longer exists in the rebuild, so use an advisory lock or a membership row.

### 2.7 `DELETE /me/children/{child_token}/link` (`children.php:328`, `guardians.php:487`)
- Permission `children:link`. `UPDATE user_guardians SET status='revoked', revoked_at=CURRENT_TIMESTAMP, revoked_by=<caller users.id> WHERE parent_token=:caller AND child_token=:child AND status='active'`. 0 rows: 404 `Active link not found`. Success 204, no body.

### 2.8 `GET /me/parents` (`children.php:435`, `guardians.php:650`)
- Permission `parents:manage`. Bare list of raw rows like 2.4 but `parent_name` instead of `child_name`, `WHERE child_token=:caller AND status='active' ORDER BY created_at DESC`, parent name from `LEFT JOIN users u ON u.token=ug.parent_token`. Token 0 or less: `[]`.

### 2.9 `DELETE /me/parents/{parent_token}` (`children.php:450`)
- Permission `parents:manage`. Same UPDATE as 2.7 with the caller as the child. 404 `Active parent link not found`. 204. This `revoked_by` (a users.id whose token equals the row's `child_token`) is what makes a later re-add need admin rights (2.14).

### 2.10 `POST /members/{child_token}/parent-links` (`children.php:180`, helper `:140`)
- Guard `api_require_parent_link_create` (shared by 10, 11, 12), in order: child token 0 or less 404 `Student not found` (before any permission); caller token equals child token and holds `parents:manage` allowed; `staffMayAddFor(caller, child)` allowed; else if the caller lacks `parents:add` (no target) 403 `You do not have permission to do that`; else 404 `Student not found`.
- `staffMayAddFor` (`guardians.php:568`): needs the child's `users.gender` as `(int)` (no user: false); `managedReach(action)` is `all`, or `gender` equal to the child's gender when above 0, allowed; else any of the child's active classes (`class_students` `status='A'`, `removed_at null`, `classes.status='A'`) for which `can(action, [class])` holds. Action is `parents:add`, or `parents:add-direct` when `direct`.
- Create: child must be a single registered member (`validateMemberToken`: token above 0, exactly one `users` row) else 404 `Student not found` (a shared token is also 404 here). Cap: `COUNT(*) WHERE child_token AND status='invited' AND (expires_at IS NULL OR > now)` of 5 or more: 422 `At most 5 pending invites allowed`. Under the child lock.
- Write: `INSERT user_guardians (child_token, status='invited', source='link', code, expires_at, created_by=<caller users.id>, created_at)`; `code = bin2hex(random_bytes(16))` (32 hex), `expires_at = date('Y-m-d H:i:s', time() + 7 days)` in the PHP clock, `link = public_web_base() . '/link/' . code` (`functions.php:1363`, built from env `REDIRECT_URI`; value **unverified**, empty string when unset).
- Response 201 `{code, link, url, expires_at}` (`url` equals `link`; `expires_at` `Y-m-d H:i:s`).

### 2.11 `GET /members/{child_token}/parent-links` (`children.php:207`, `guardians.php:547`)
- Guard as 2.10. `select id, created_at, expires_at from user_guardians where child_token and created_by=:caller_users_id and status='invited' and (expires_at is null or > now) order by id desc limit 5`. Bare list `[{id:int, created_at:str, expires_at:str}]`; the code is not returned. Only the caller's own invites.

### 2.12 `DELETE /members/{child_token}/parent-links/{id}` (`children.php:221`, `guardians.php:509`)
- Guard as 2.10. `cancelInvite`: `select ug.created_by, cu.gender from user_guardians ug JOIN users cu ON cu.token=ug.child_token where ug.id=:id and ug.child_token=:child and ug.status='invited'`; no row, or the caller is neither the creator nor holds `parents:manage` for gender target `(int)child gender`: 404 `Invite not found` (same answer for unknown, used, already cancelled, not yours). Else `UPDATE ... SET status='revoked', revoked_at, revoked_by=<caller> WHERE id AND status='invited'`. 204. The code stays on the row.

### 2.13 `GET /members/{child_token}/parents/candidate/{parent_token}` (`children.php:350`, `guardians.php:688`)
- Permission `parents:add-direct` (no target) first; then rate limit `parent_candidate` 30 per 3600 s per `member-<token>` (counted before the scope check), 429 `Too many lookups; try again later`. `candidateLookup`: scope check `staffMayAddFor(direct)` fails 404 `Member not found`; parent token 0, unknown: 404 `Member not found`; shared token: 422 `{"detail":"More than one member has that token number. Please contact an admin.","code":"ambiguous_token"}`; else 200 `{name}` (raw `users.name` as `str`).

### 2.14 `POST /members/{child_token}/parents` (`children.php:380`, `guardians.php:363`)
- `staffMayAddFor(direct)` false: 403 if the caller lacks `parents:add-direct` else 404 `Student not found` (no child-token-0 pre-check; the scope call returns false). Body `parent_token` (`(int)`, default 0), `relationship` (string).
- `addDirect` order: parent unknown or token 0 404 `Member or student not found`, shared 422 with `code: ambiguous_token`; child same; parent = child 422; parent = the caller's own token (staff may not become the parent) 422; bad relationship 422 (all `Invalid relationship or self-link not allowed`); under the child lock: active link exists 409 `An active link already exists for this parent and child`; the child previously revoked this parent and the caller lacks `parents:manage` for the child's gender 403 `Child previously revoked this parent; admin approval required`.
- Write: `INSERT user_guardians (parent_token, child_token, relationship, status='active', source='token_entry', created_by, created_at, activated_at)`. 201 `{id:int, parent_token:int, child_token:int, relationship:str, status:"active"}`. No notification, no audit row.

### 2.15 `GET /registration` (`registration.php:20`)
- No permission. Reads (all by the caller's token): `select * from class_registrations where token=:t` (**no ORDER BY, `fetch()` takes the first row**; the table has duplicates per token); `interest_options WHERE is_active=1 ORDER BY sort_order, name` (id, name only); `student_interests JOIN interest_options` ids (no order); `class_registrations_languages` rows (`language, skill, proficiency`, no order).
- Response: `{registration: <payload>|null, interestOptions:[{id:int,name:str}], selectedInterestIds:[int], languages:{language:{skill:proficiency}}}`; `languages` is an object, so empty is `{}`. Payload (`registration.php:119`), key order: `preferredLocation, birthYear(int|null), islamicStudyYears(int|null), linkedinUrl, residenceLocation, workLocation, education, fieldOfStudy([str], decoded JSON, `[]` when empty or invalid), fieldOfStudyOther, professionalCourses([str]), professionalCoursesOther, occupationType, fieldOfWork, yearsExperience, roleLevel, otherInterests, status`. Raw column values (not cast, not entity-decoded); `status` is `Pending|Accepted|Rejected`; no `statusReason`.

### 2.16 `POST /registration` (`registration.php:50`)
- No permission. Body camelCase: required `preferredLocation, birthYear, islamicStudyYears` (each `trim((string))`; empty `preferredLocation` or `birthYear` or `islamicStudyYears` fails) 422 `preferredLocation, birthYear and islamicStudyYears are required`. `"0"` is accepted for study years. `birthYear` and `islamicStudyYears` are `(int)` casts with **no range check** (`"abc"` becomes 0).
- Optional: `linkedinUrl` (null unless `/^https?:\/\/(www\.)?linkedin\.com\/(in|pub|company)\/[\w-]+/i`; trailing junk allowed; stored as typed), `residenceLocation, workLocation, fieldOfStudyOther, professionalCoursesOther, otherInterests` (trimmed, empty to null; **no length cap**, a too-long value is a DB error, **unverified**), dropdowns `education, occupationType, fieldOfWork, yearsExperience, roleLevel` (trimmed; must equal a `lookups` label of that type exactly (case-sensitive, strict `in_array`), else silently null), multi-selects `fieldOfStudy, professionalCourses` (array, each trimmed, kept only if in the lookup labels, stored as JSON text, null when none or not an array). `lookups` types `education, field_of_study, professional_courses, occupation_type, field_of_work, years_experience, role_level` read `WHERE is_active` (`models/lookups.php`); an unseeded type throws (500).
- Write 1: `select * from class_registrations where token` exists: `UPDATE ... WHERE token=:t` (all rows of the token) setting the 14 form columns, `for_classid = NULL`, `profession = NULL`, `interests = NULL`, `modified_at = now()` (**the update wipes `for_classid`, `profession` and the legacy `interests` set**, and does not touch `status`); else `INSERT` (`for_classid NULL`, `created_at = now()`, status default `Pending`).
- Write 2: `languages` non-empty array only: `DELETE FROM class_registrations_languages WHERE token` then one INSERT per valid entry. Valid language `Arabic English Gujarati Hindi Persian Urdu`, skill `Read Speak Understand Write`, proficiency `Beginner Fluent Learning` (`Don't Know` and anything else are skipped). **Not in a transaction**, and a non-empty map of only invalid entries still erases every saved language. `[]`, `{}` or missing: untouched.
- Write 3: `interestIds` is an array (even `[]`): validate `(int)` ids against active `interest_options`, `DELETE FROM student_interests WHERE token`, INSERT each. `[]` erases all; missing or non-array: untouched.
- Response 200 `{"success":true,"message":"Class request submitted successfully"}`. No notification, no audit, no search touch.
- Non-string array values for scalar fields (`"Array"` after `(string)`) and arrays inside `fieldOfStudy` (`trim` TypeError): **unverified**, likely 500.

### 2.17 `GET /reports/registrations` (`reports.php:1678`; guard `:57`; SQL `subscribers.php:584`)
- Gender (`api_reports_gender`, `reports.php:19`): `genderLock(user,'registrations:read')` else `?gender=2` is ladies, anything else gents. Then `api_require('registrations:read', {gender})`.
- SQL: from `(select MAX(id) id, MAX(token), MAX(for_classid), ... MAX(status), MAX(created_at) ... from class_registrations group by token) r INNER JOIN users u ON u.token=r.token LEFT JOIN (select distinct token_no from class_students cs join classes c on c.id=cs.class_id where c.status='A' and cs.removed_at is null) c ON c.token_no=r.token LEFT JOIN classes f ON f.id=r.for_classid AND f.status='A' LEFT JOIN users teacher ON teacher.token=f.teacher WHERE r.status != 'Rejected' AND c.token_no IS NULL AND u.email NOT LIKE '%@thestrongrope.com' AND u.gender = :gender ORDER BY r.created_at DESC`. No limit.
- Quirks: one row per **token**, every column is `MAX()` of that token's rows, so the row mixes values (`id` is the latest row's id); `MAX(status)` on an enum is compared as text in MariaDB (so `Rejected > Pending > Accepted`; **unverified**), which hides a token with any rejected row; `u.email NOT LIKE` drops rows whose email is NULL; `u.gender = :gender` is varchar against an integer, so `'1'` and `'2'` match and `'Male'`/`'Female'`/NULL match neither list; "waiting" = not in any active class (the `class_students.status` is **not** checked, unlike elsewhere); ties on `created_at` unordered.
- Response: `{gender:int, registrants:[...]}`; each (`reports.php:1792`, key order) `id int, token int, name str, status str, registeredOn str (first 10 chars of created_at), requestedClass str?, email str?, mobile str?, residenceLocation text?, preferredLocation text?, workLocation text?, birthYear int?, classLevel str?, classNumber str?, profession text?, islamicStudyYears str? (an int such as 5 becomes "5", 0 becomes "0"), interests text?, city str?, country str?, zip str?`. `requestedClass` = `classes.code` of `for_classid` when that class is active. Side effects: none.

### 2.18 `GET /reports/registrations/download?format=xlsx|pdf&gender` (`reports.php:1710`)
- `format` is checked **first** (422 `format must be xlsx or pdf`, even unauthenticated), then the guard and rows of 2.17. No 404 on empty (an empty file is sent).
- Heading `Waiting to be placed, <Y-m-d>`; headers `Sr. No., Token, Name, Created On, For Class, Email, Mobile, Location, Birth Year / Age, Profession, Islamic Study, City, Country, Pincode` (values: index+1, token, name, created_at, for_class, email, mobile, preferred_location, birth_year, profession, islamic_study_years, city, country, zip). Filename `Registrations-<Gents|Ladies>-<Ymd>.<fmt>`; title `Registrations: <Gents|Ladies>`. Export helper `ReportExportModel` (platform recon section 3.7: cells made spreadsheet-safe, A4 PDF).

### 2.19 `GET /reports/registrations/allocated/download` (`reports.php:1745`, SQL `subscribers.php:495`)
- Same format-first rule and gender guard. `managedReach(registrations:read)`: `seesOpen = all || gender !== null`; otherwise only registrations for a class (`for_classid > 0`) and only people placed in the caller's `ids` (empty means nobody, `AND 1 = 0`).
- SQL: registrations grouped by token (`MAX()`), `JOIN users`, `JOIN class_students cs ... removed_at IS NULL`, `JOIN classes c AND c.status='A'`, `LEFT JOIN class_levels`, `LEFT JOIN users t ON t.token=c.teacher`, `WHERE (gents: u.gender = 1 OR u.gender = 0; ladies: u.gender = :gender) [AND r.for_classid > 0] AND u.email NOT LIKE '%@thestrongrope.com' [AND c.id IN (...)] GROUP BY r.token ORDER BY MAX(r.created_at) DESC`. The gents `= 0` is a numeric compare of a varchar, so non-numeric gender text (`'Male'`, `'Female'`, `''`) also lands in the gents file (MariaDB coercion; **unverified**).
- File: heading `Placed in a class, <Y-m-d>`; 25 headers `Sr. No., Token, Name, Created On, Gender, Mobile, Email, Age Range, City, State, Country, Zip Code, Registered On, Last Modified On, Residence Location, Work Location, Class Level, Class Number, Professional Expertise, Interests, Allocated Class, Allocated Level, Allocated Teacher Code, Allocated Teacher, Extra Students`. Gender text from `['Not mentioned','Male','Female'][(int)]`, age range from `['Not mentioned','Less than 15','15 to 25','26 to 40','Above 40'][(int)]`, interests = `interests . (other_interests ? ',' . str_replace(' ,', ',', other_interests))`, extra = number of newline-separated lines in `classes.extra_students`. Filename `Registrations-placed-<Gents|Ladies>-<Ymd>.<fmt>`; title `Registrations placed in a class: <Gents|Ladies>`. No 404 on empty.

### 2.20 `GET /registrations/{registration_id}/classes` (`registrations.php:42`, guard `:20`)
- Guard `api_require_waiting_registrant`: caller must hold `registrations:read` for gents or ladies (else 403, before the id is looked up); then the registrant is looked up by `id` through the 2.17 SQL (`AND r.id = :id`, no gender filter); none (unknown id, placed, rejected, non-numeric id) 409 `This registrant is no longer waiting: they have been placed or rejected.`; then `registrations:read` for the registrant's gender 403.
- Then `ClassesModel::getAll(registrant gender)` (`models/classes.php:202`: active classes of that gender, inner join level, left join teacher name, count of non-removed `class_students`, limited to `assignedOnlyIds(classes:read)` for an assigned-only caller; ordered `c.gender, level sort_order, c.id`), keeping classes where `can(students:enrol, [class])`.
- Response `{classes:[{id:int, code:str, level:str, teacher:str?, location:text?, students:int}]}`. This is **classes' data**; membership can only produce it through a classes interface.

### 2.21 `POST /registrations/{registration_id}/place` (`registrations.php:70`)
- Guard of 2.20 first (403, 409). Body `classId` must be a JSON **integer** above 0 (a string `"5"` fails) else 422 `classId must be a class id`; class must exist and be active else 404 `Class not found`; `students:enrol` on that class else 403 `You do not have permission to place members in this class`.
- `ClassStudentsModel::addStudent(classId, token)` (`classstudents.php:156`): the member's gender (`genderOf`: `'1'`/`'Male'` is 1, `'2'`/`'Female'` is 2, else null) must be null or equal the class gender, else 422 `Could not place them: their gender does not match this class.` (logs `class.enrol_refused`). Write (`writeEnrolment`, `:312`): if the token has **no** `class_registrations` row insert one (`status 'Accepted'`); `INSERT class_students (class_id, token_no, joined_on = now())`; search `touch('person', token)`. It does not check an existing enrolment in that class and does not change the registration's status (the member leaves the waiting list because they are now in an active class).
- `log_event('registration.placed')`. Response 200 `{placed:true, registrationId:int, classId:int}`.

### 2.22 `POST /registrations/{registration_id}/reject` (`registrations.php:95`)
- Guard of 2.20, then `registrations:reject` for the registrant's gender (403). Body `reason` a string, trimmed, 1 to 500 chars (`mb_strlen`) else 422 `reason is required, at most 500 characters`.
- Write: `UPDATE class_registrations SET status='Rejected', status_reason, status_date=now(), modified_at=now(), modified_by=<caller users.id> WHERE token=:t` (**every** row of the token, `subscribers.php:818`). `log_event('registration.rejected')`. Response 200 `{rejected:true, registrationId:int}`. No message to the registrant.

### 2.23 `GET /admin/donors` (`donors.php:31`, SQL `subscribers.php:841`)
- Permission `donors:read` (role 1 and 7). SQL: `select u.name,u.email,u.mobile,u.city,u.state,u.country,u.zip from users u join class_students cs on cs.token_no=u.token join classes c on c.id=cs.class_id where cs.removed_at is null and c.status='A' order by u.name`. **No DISTINCT**: a member in two active classes is listed twice (and the `class_students.status` is not checked). Collated name order.
- Response `{donors:[{name,email,mobile,city,state,country,zip}]}`, every field `text?` (entity-decoded, `''` becomes null). Real contact details are returned (it is an admin list); the "donor" name means every enrolled student.

### 2.24 `GET /admin/donors/download?format=` (`donors.php:37`)
- `format` first (422), then the 2.23 guard; no rows: 404 `There are no donors to download`. Heading `TSR Members (Donors), <Y-m-d>`; headers `Name, Email, Mobile, City, State, Country, Zip`; title `Donors`; filename `TSR_Donors_Export_<YmdHis>.<fmt>`.

### 2.25 `GET /students/{token}` (`entity_cards.php:18`, model `entityaccess.php:34`)
- Permission `classes:read` (no target), then `reach = managedReach(classes:read)`. Token `(int)`; 0 or less, unknown, not a student, or none of the student's classes reached: 404 `Person not found` (one answer for all).
- Reads: `select name, gender from users where token` (first row if the token is shared; `gender` through `genderOf`: 1, 2 or null); the member's classes `class_students cs JOIN classes c ON c.status='A' LEFT JOIN class_levels l WHERE token_no AND removed_at IS NULL ORDER BY c.code` (the enrolment `status` is not checked). A class is kept when `reach.all`, or `reach.gender` equals the class gender, or its id is in `reach.ids`.
- Response `{token:int, name:str, gender:int?, classes:[{id:int, code:str, level:str}]}`; `level` null becomes `''`. No contact details by design (issue 316).

### 2.26 `GET /subscribers/{token}` (`entity_cards.php:42`, model `entityaccess.php:60`)
- Permission `classes:read`; the caller must have `reach.all`, else 404 `Person not found`. Token 0 or less, unknown, or **any** current class (as 2.25): 404.
- Latest registration: `select cr.created_at, c.code from class_registrations cr left join classes c on c.id=cr.for_classid where cr.token=:t order by cr.id desc limit 1`.
- Response `{token:int, name:str, gender:int?, registeredOn:date?, requestedClass:str?}`; `registeredOn` is the first 10 chars of `created_at` (null with no registration), `requestedClass` is the class code whatever the registration status (unlike `memberDetails`, which hides `Accepted`).

## 3. Tables

All in MariaDB `utf8mb4_unicode_520_ci` (case and accent-insensitive; Postgres needs the collation decision from `phase-3-collation-proof.md`).

| Table | Columns used | Keys | Proposed owner | Touched by |
|---|---|---|---|---|
| `users` (profile part) | `name, first_name, last_name, picture, gender varchar(200) null, age_range varchar(200) null, mobile varchar(100) NOT NULL default '', country, state, city, zip varchar(100), language int default 0, sendupdates char(1) default 'N', unsubscribe char(1) default 'N'`. Also present, unused here: `region, lat, lng, timezone, browser, location_details, provider_id` | PK id; **`token` plain KEY (not unique)**; unique `firebase_uid`; (email index since 2026_10_28) | profile columns: **membership**; id, token, email, provider, firebase_uid, createdon, sign-in columns: identity; `roleid`: access | 1, 2, 3, 6, 8, 10 to 14, 17 to 19, 23 to 26 (as a join) |
| `class_registrations` | `id, token, for_classid, residence_location(300), work_location(300), preferred_location(1000), class_level enum(IKP,IJP,IBP,Primary,Secondary,Advance), class_number(100), birth_year, profession(500), islamic_study_years, interests SET(12 values), other_interests(500), education(100), field_of_study json-text, field_of_study_other(200), professional_courses json-text, professional_courses_other(200), occupation_type(100), field_of_work(100), years_experience(50), role_level(100), linkedin_url(500), status enum(Pending,Accepted,Rejected) default Pending, status_date, status_reason(500), created_at, modified_at, modified_by` | PK id **only: no index on `token`, no unique per token** (duplicates exist) | membership | 15, 16, 17 to 19, 20 to 22, 25 (read by classes' `writeEnrolment` too) |
| `class_registrations_languages` | `id, token, language enum(English,Hindi,Urdu,Gujarati,Arabic,Persian), skill enum(Read,Write,Speak,Understand), proficiency enum(Don't Know,Beginner,Learning,Fluent)` | PK id only | membership | 15, 16 |
| `interest_options` | `id, name varchar(100) unique, sort_order, is_active, created_at` (12 seeded) | PK, unique name | membership | 15, 16 |
| `student_interests` | `id, token, interest_id FK ON DELETE CASCADE, created_at` | PK; unique (token, interest_id); idx token | membership | 15, 16 |
| `user_guardians` | `id, parent_token null, child_token, relationship enum(father,mother,guardian) null, status enum(invited,active,revoked), source enum(link,token_entry), code varchar(32) null, expires_at, created_by (users.id), created_at, activated_at, revoked_by (users.id), revoked_at` | PK; unique `idx_code`; idx parent_token; idx child_token. No foreign keys; "one active link per pair" and "5 invites" have **no key**, only the lock | membership | 3 to 14, and the 4 `/me/children/{t}/classes...` routes (classes, assessment) |
| `lookups` | `type, code, label, sort_order, is_active` | unique (type, code) | platform (per `domains/CLAUDE.md`), read by membership (education etc.) | 16 |
| `class_students`, `classes`, `class_levels`, `class_tags`, `tags` | enrolment (`token_no, class_id, removed_at, status, joined_on, added_by`), class (`id, code, name, gender, status, teacher, level, location, extra_students`), level name | n/a | classes | 2, 3, 10, 14, 17 to 26 |
| `outbound_messages` | search touch rows | n/a | platform | 2, 21 |
| `geo_countries`, `geo_postal_codes` | country by name, postal lookup | n/a | platform | 2 |

Profile split notes (the rebuild split `users`): `identity.users` has `id, token, gender (short, temporary), email, provider, firebase_uid, createdon, lastlogin, ...` (`domains/identity/api/IdentityContext.cs:53`); the role is `access.user_roles`. Membership must take over `name, first_name, last_name, picture, gender, age_range, mobile, country, state, city, zip, language, sendupdates, unsubscribe` (and remove `identity.users.gender`). `first_name` and `last_name` are read by the guardian ops and written by no API route in this repo (**unverified**: the web only; they hold null for most members). The identity link flow wrote `name` and `picture` on create and link in PHP (`subscribers.php:82`) and the rebuild defers it (`php-parity-feedback.md:95`); membership must receive those.
`users.gender` holds `'1'`, `'2'`, `'Male'`, `'Female'`, NULL or `''`; the ops treat it five different ways: `genderOf()` normalises (cards, placement); `(int)` casts read `'Male'` as 0 (children, guardians, gender lock, `/me` response gives null); SQL `u.gender = 1` compares numerically (waiting list); the gents allocated file also takes `= 0`. A parity-exact rebuild needs the raw text kept, or a decision (section 7). `users.token` is not unique and the guardian code refuses a shared token explicitly; keep it non-unique.
Account deletion (`models/accountdeletion.php:180`) anonymises `class_registrations` (a map of columns) and `users` profile columns; it does **not** touch `user_guardians`, `student_interests` or `class_registrations_languages` (grep found no reference): **a gap membership's erasure handler (domains rule 11) must decide on**.

## 4. Cross-domain needs

Built today: identity, access, platform (partly). Not built: classes, notifications, search.

| Need | From | Used by | Built? |
|---|---|---|---|
| The caller's `id`, `token`, `email`; a user's `id` by token; read the email of a waiting registrant (the `@thestrongrope.com` exclusion and the download) | identity (interface, e.g. `IUserDirectory`: `ByToken`, `ByIds`) | 1, 10 to 14 (`created_by` is a users.id), 17 to 19, 23, 24 | identity built; **interface not**: `CallerMiddleware`'s `MemberDirectory` is internal |
| Role id for `roleid` in `GET /me` | access (`user_roles`; `Permissions.ForUserAsync`) | 1, 2 | built |
| `CanAsync` with gender targets (`registrations:read`, `registrations:reject`, `parents:manage`), class targets (`students:enrol`, `parents:add`), no target (`profile:*`, `children:*`, `donors:read`, `classes:read`) | access | all | built; **class targets always fail until `classes` supplies `IClassScopes`** (`NoClasses`) |
| `ReachAsync` (managedReach `all/gender/ids`, genderLock, assignedOnlyIds) for `registrations:read`, `classes:read`, `parents:add`, `parents:add-direct` | access | 10, 13, 14, 17 to 19, 25, 26 | built (`Reach`); `ClassIds` empty until classes exists |
| Country list, `countryByName`, `fromPostalCode`, the personal-data regex test, `hasCountries` | platform (geo interface; tables built, no public interface) | 2 | tables built; **interface not** |
| Lookup labels by type (7 types) | platform (`lookups`; table owned, no slice) | 16 | **not built** (no migration seen; unverified) |
| Rate limiter (`rate_limit_allows` semantics, per member) for 5 and 13 | platform's in-memory geo limiter, or `shared/api` | 5, 13 | exists inside platform geo; not shared |
| xlsx and pdf export of sections (heading, headers, rows) | `shared/api` (decision open in platform recon, 3.7) | 18, 19, 24 | **not built** |
| Enrolment facts: is the member in an active class (`class_students.status`, `removed_at`, `classes.status`), their classes (id, code, name, level, teacher, gender) for a list of tokens, count by class, "member has any status-A enrolment" | classes (a port such as access's `IClassScopes`, or an event-fed copy in membership) | 2 (gender lock), 3, 10, 14 (`staffMayAddFor`), 17 to 19, 23, 25, 26 | **classes not built** |
| Active classes of a gender the caller may see, with level, teacher name, location, student count (`getAll`) | classes | 20 | not built |
| Enrol a member in a class: gender check, insert `class_students`, create an `Accepted` registration if none | classes (command), called by membership; today it also writes `class_registrations`, which membership owns | 21 | not built; **two-way dependency** (classes needs member gender/name from membership) |
| `IsActiveGuardian(parentToken, childToken)` for child performance routes; guardianship checks | membership provides, to classes and assessment | 4 routes outside the 26 | to build with this domain |
| Member name and gender by token (class rosters, teacher names, cards) | membership provides | classes, assessment | to build |
| Person changed (name, gender) so the search index follows | search via the outbox (`membership.person_changed` event, or write `outbound_messages`) | 2, 21 | search not built; the outbox table is platform's and built |
| Erasure event handler for profile, registration, languages, interests, guardian links | membership consumes `identity` deletion event (domains rule 11) | n/a | not built anywhere |
| Push, WhatsApp, email | none | none of the 26 sends anything (checked each handler and model) | n/a |
| Audit log (`admin_access_log`) | platform | none of the 26 writes it (the PHP writers are in classes, notifications, syllabus: `platform-recon` section 5) | n/a |

Dependency shape to avoid a cycle: access solved it with a port the other domain implements. Same here: membership declares a small port (e.g. `IClassEnrolments`: enrolled classes by token, is-enrolled, place member) that `classes` implements, so membership lists `access`, `identity`, `platform` and not `classes`, and classes lists `membership` for names and genders. Until classes exists the port's default would return "no classes", which changes behaviour (see 6).

## 5. What the two access-log operations need from membership

`GET /admin/access-log` and its download (platform recon 3.6, 3.7) left-join `users` for `name` and `email` by `user_id` and show them; the platform design says no domain stores a name until membership. Needs:
1. **A name by user id** (`coalesce(name,'')`) for the users list and the recent list: an interface on membership such as `IMemberNames.NamesByUserIdsAsync(ids)` returning `name` (empty when none). Platform recon open question 1 (which name wins per token) is then answered by this interface, not SQL.
2. **An email by user id** (`coalesce(email,'')`): that is identity's, not membership's. Two calls (identity for email, membership for name), or one identity interface that returns both once identity can read the profile; recommend two narrow interfaces so no domain reads another's table.
3. The role name needs no membership data (`ROLE_NAMES` map, access).
4. `admin_access_log` stores `token` and `roleid` itself, so no per-row membership read for those; the 500-row recent list and the grouped users list need the batch lookup above (at most about 500 ids; the users list is unbounded, so batch by id).
5. The **audit-write interface** (`AuditLog.RecordAsync`) is platform's and is called by classes, notifications, syllabus; membership's 26 operations never write the log, so membership has no obligation there. The log stays empty on the new side until one of those domains is built.

## 6. Suggested build slices

Each batch is proven by a Hurl file per slice on both stacks (as platform), plus NUnit for rules and `db/tests` for SQL. Synthetic seed needs: members with gender `'1'`, `'2'`, NULL (and the text forms if kept), a shared token, guardians in each status, registrations (duplicate rows per token, one rejected), a donor with two classes.

| Batch | Operations | Depends on | Reaches parity without classes? |
|---|---|---|---|
| A. Profile | 1 `GET /me`, 2 `PATCH /me` | identity `IUserDirectory`, platform geo interface; migration moves the profile columns and removes `identity.users.gender` | Mostly. The gender lock (needs "enrolled in any class") cannot be proven until `classes`; ship with the port's default and a failing-first test marked pending, or hold item 2 |
| B. Guardian self-service | 4, 5, 6, 7, 8, 9 | identity (caller, user id lookups), platform rate limiter, access `parents:manage`, `children:*` | Yes except 3 |
| C. Children list | 3 `GET /me/children` | classes port (active classes of the child) | **No**: the `classes` array is empty without classes (a visible difference); do after `classes` |
| D. Staff guardian ops | 10, 11, 12, 13, 14 | access `ReachAsync` + class targets (`parents:add:own/assigned/taught` need classes), identity | Partly: `all` and `gender` scopes work now; the own, taught and assigned scopes need `classes` |
| E. Registration form | 15, 16 | platform lookups (seed `lookups` first, it is not built), interest data | Yes |
| F. Waiting list | 17, 20 | access `ReachAsync`, classes port (active classes, enrolled-in-active-class filter) | **No**: the "waiting" definition and 20 need classes |
| G. Place and reject | 22 `reject`, 21 `place` | F; classes enrol command (21) | 22 needs only 17's lookup; **21 cannot** reach parity before classes |
| H. Reports and donors | 18, 19, 23, 24 | shared xlsx/pdf export, classes port (19, 23, 24 join classes) | **No** for 19, 23, 24; 18 follows F |
| I. Cards | 25, 26 | access reach, classes port | **No** (a student is defined by a class) |

Recommended order: E, B, A (with the lock pending), then wait for `classes`; D partial; then C, F, G, H, I. Items 1, 2, 4 to 9, 15, 16 and the `all`-scope half of 10 to 14 (about 14 of the 26) can be proven now. Realistically the second half of this domain is built alongside `classes`; an alternative is to build `classes` read models first (the port) so F, H, I land together.

## 7. Open questions for the owner

1. **Where do the 4 operations that read or write classes' data live?** (20 `registrations/{id}/classes`, 21 `place`, 19 allocated download, 25 and 26 cards.) Options: (a) keep in membership behind a `classes`-implemented port, (b) move 20 and 21 to `classes` (the CSV's own rule: a command writes only its domain's tables; 21 writes `class_students`), leaving membership with the waiting list and reject. Recommend (b) for 20 and 21, (a) for the rest; confirm before the `classes` design.
2. **`users.gender` handling.** Keep the raw text (`'1','2','Male','Female',NULL`) in membership for exact parity of the five behaviours in section 3, or normalise to a small int on import and accept that rows with `'Male'` change behaviour (they would now appear in the right waiting list and children list)? Recommend keeping a nullable short plus a one-off data check that counts the legacy text rows (read-only query by the owner); decide parity vs fix after seeing the count. Needs a count of such rows: **unverified**.
3. **Profile table keying.** `membership.member_profiles` keyed by identity user id (plain int, no foreign key) with the row created by event when identity creates a user, or created lazily on first write. Recommend: key by user id, create on first read or write inside membership (GET /me must show a default row: mobile `''`, language 0, sendupdates `'N'`), no event needed.
4. **Who writes `name` and `picture` on sign-in/link?** PHP does it in the identity call. Options: (a) identity depends on membership (a write interface), (b) `identity.user_linked` event handled by membership (async: `GET /me` straight after sign-in may show an empty name), (c) membership keeps the profile row but identity passes name and picture in the same transaction through a shared port. Recommend (a) with one narrow interface, because parity needs the name in the same request.
5. **Row lock for the guardian ops** (`UPDATE users SET roleid = roleid`, no `roleid` column any more): use `pg_advisory_xact_lock(child_user_id)` (recommended), or a unique partial index per pair for the one-active-link rule plus the lock for the 5-invite cap. The index is stricter than PHP (PHP only guards in code); say whether stricter is allowed (a duplicate active pair from old data may exist: **unverified**).
6. **`user_guardians` keyed by token** (non-unique, no foreign keys) is kept as is, and `created_by`/`revoked_by` are user ids. Keep (parity), recommend yes.
7. **Duplicates in `class_registrations`.** `GET /registration` takes an arbitrary first row; update/reject touch all rows of a token; the list mixes rows with `MAX()`. Recommend: copy the SQL semantics exactly and add an index on `token` (there is none), and import duplicates unchanged; a unique key is a later fix (separate change). Confirm.
8. **`MAX(status)` on the enum and the numeric gender comparison** (2.17, 2.19): need a read-only check by someone with database access, or a small PHP test with the parity stack (synthetic rows) to confirm what MariaDB does before copying. Recommend running the check on the parity stack, which holds only synthetic data.
9. **Erasure of guardian links, interests and languages** (section 3): PHP leaves them. Recommend the new handler erases them (the privacy policy's promise), recorded as a deliberate difference.
10. **`first_name`/`last_name`**: confirm whether to keep them (used for the invite page and `/me/children`).
11. **Shared helpers**: xlsx/pdf export (also platform question 9) and the per-member rate limiter. Recommend both in `shared/api`, built with the first batch that needs them (limiter in B, export in H).
12. **Rate-limit wording differs** between geo (`Too many lookups; try again in a minute`) and guardians (`Too many lookups; try again later`): copy each as is.
13. **`public_web_base()`** (`REDIRECT_URI` env) builds the invite link: which setting name does the rebuild use, and is the empty-string behaviour (`/link/<code>` relative) wanted? Recommend a `TSR_PUBLIC_WEB_BASE` setting that fails closed in production.
14. **Web pages that also write these tables** (`tsr_class_save.php`, `manage_*_registrations.php`, `save_profile.php`, `link.php`, `donors.php`) are outside the 26. How data flows while PHP web and the new API coexist is unverified here; same question as platform's `admin_access_log` (expand-only changes).
