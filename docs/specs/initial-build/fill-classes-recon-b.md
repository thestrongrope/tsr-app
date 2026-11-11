# Fill-classes recon B: 15 classes `/admin/*` operations and 11 membership operations

Read-only recon of `~/Projects/tsr-account` (PHP, `develop`). Paths are under `web/api/mobile/` unless they start `web/`. Source only: no database, no `.env`, no container.
No member data appears here. Anything not confirmed is marked **unverified**.
Builds on `phase-3-membership-recon.md` ("MR" below, section numbers 2.x) and `phase-3-membership-design.md`; for the 11 membership operations this file adds only
what has changed since (classes now exists as a domain, the ports it must supply) and what MR missed. PHP table to new table: `schema-phase-tables.csv`.

## 0. Facts that apply to every operation

- **Auth.** All 26 handlers call `api_authenticate(true)` (`lib/auth.php:106`: 401 `Not authenticated` / `Invalid auth token` / `Email not present in token`, 404 `User not found`,
  403 `Registration incomplete` for token 0, 403 `Account deletion pending`; side effects: lastlogin/device update, Firebase claims). That is identity's concern. `operations.csv` marks 15 of the 26 `member`
  and 11 `create`; PHP is `create` (true) for **all 26** (see 6(d)-1).
- **Refusal wording.** `api_require(action, target, detail)` (`lib/response.php:232`): refusal logs `permission.refused` and answers 403 `{"detail": <detail>}`, default detail `You do not have permission to do that`. A permission store failure also refuses.
- **Body.** `api_body()` (`bootstrap.php:59`): empty body is `[]`; invalid or non-array JSON is 422 `Invalid JSON body`. Path `{x}` matches `[^/]+`; a non-numeric id is cast `(int)` to 0.
- **Casting** (`lib/response.php:28`, `api_cast`): unlisted keys dropped; `x?` nullable turns `''` into null; a **non-nullable `text` field with null or `''` becomes the number `0`** (the zero-value branch tests `str`, `bool`, `float`, else `0`), a non-nullable `str` becomes `''`;
  `text` also HTML-entity-decodes (`PhpText` in membership does this); `datetime` is `Y-m-dTH:i:s` with no zone; `date` passes through (zero date null); `int` of non-numeric is 0 or null; `bool` accepts 1, '1', true, 'true', 'Y', 'y'.
- **Permission catalog** is complete in access (`20261110114817_CatalogFromPhp`): every action named below exists. Holders (role ids): `syllabus:update`, `students:transfer`, `members:enrol-by-token`, `deactivated-classes:manage`, `teachers:lookup` all = role 1 (super admin) only (`teachers:lookup` also 3, 4, 5 with narrower scope);
  `teachers:read` = 1 (all), 3 and 4 (gender); `donors:read` = 1, 7; `registrations:reject` = 1 only in the catalog (checked 2.22 for gender).
  `students:enrol` and class targets work only once classes supplies `IClassScopes` (today `NoClasses` returns no class, so a class-target check is false).
- **Rate limiter.** PHP `rate_limit_allows` is a file per caller (`functions.php:1168`); the new one is `shared/api/MemberRateLimit` (per token, in memory). PHP's admin lookups key on `'user'.users.id`, guardians on `'member-'.token`; equivalent per caller.
- **Search touch.** `SearchOutboxModel::touch(kind, id)` queues a `person`/`teacher`/`class` id in `outbound_messages` (platform). Search is not built; translate each touch to an event (6(c)).

## 1. Index

| # | Operation | Handler (file:line) | Router (`index.php`) | Permission, in order | Size |
|---|---|---|---|---|---|
| 1 | GET `/admin/syllabus` | `syllabus.php:129` | 220 | `syllabus:update` | S |
| 2 | POST `/admin/syllabus` | `syllabus.php:168` | 221 | `syllabus:update` | M |
| 3 | PUT `/admin/syllabus/{id}` | `syllabus.php:227` | 282 | `syllabus:update` | M |
| 4 | DELETE `/admin/syllabus/{id}` | `syllabus.php:288` | 283 | `syllabus:update` | S |
| 5 | GET `/admin/transfers/classes` | `student_transfers.php:95` | 222 | `students:transfer` | M |
| 6 | GET `/admin/transfers/classes/{class_id}/students` | `student_transfers.php:115` | 223 | `students:transfer` | M |
| 7 | GET `/admin/transfers/history` | `student_transfers.php:199` | 224 | `students:transfer` | M |
| 8 | POST `/admin/transfers` | `student_transfers.php:138` | 225 | `students:transfer` | L |
| 9 | GET `/admin/members/{token}` | `member_enrol.php:89` | 242 | `members:enrol-by-token` (twice) | M |
| 10 | POST `/admin/members/{token}/enrolments` | `member_enrol.php:125` | 243 | `members:enrol-by-token`, `students:enrol`[class] | L |
| 11 | GET `/admin/deactivated-classes` | `deactivated_classes.php:29` | 244 | `deactivated-classes:manage` | M |
| 12 | GET `/admin/deactivated-classes/candidates` | `deactivated_classes.php:61` | 245 | `deactivated-classes:manage` | S |
| 13 | GET `/admin/teachers` | `teachers.php:39` | 275 | `teachers:read`[gender] | M |
| 14 | POST `/admin/teachers/training` | `teachers.php:123` | 280 | `teachers:read`, then per teacher `teachers:read`[gender] | M |
| 15 | POST `/admin/teachers/import` | `teachers.php:152` | 281 | `teachers:read`[gender] | M |
| 16 | GET `/me/children` | `children.php:23` | 47 | `children:read` | S |
| 17 | POST `/members/{child}/parent-links` | `children.php:180` (guard `:149`) | 54 | guard, MR 2.10 | M |
| 18 | GET `/members/{child}/parent-links` | `children.php:207` | 55 | guard | S |
| 19 | DELETE `/members/{child}/parent-links/{id}` | `children.php:221` | 56 | guard, then creator or `parents:manage`[gender] | S |
| 20 | GET `/members/{child}/parents/candidate/{parent}` | `children.php:350` | 57 | `parents:add-direct` + scope | S |
| 21 | POST `/members/{child}/parents` | `children.php:380` | 58 | scope, then `parents:manage`[gender] | M |
| 22 | POST `/registrations/{id}/reject` | `registrations.php:95` (guard `:20`) | 212 | `registrations:read` x2, `registrations:reject`[gender] | M |
| 23 | GET `/admin/donors` | `donors.php:31` | 264 | `donors:read` | S |
| 24 | GET `/admin/donors/download` | `donors.php:37` | 265 | `donors:read` | L |
| 25 | GET `/students/{token}` | `entity_cards.php:18` | 278 | `classes:read` + reach | M |
| 26 | GET `/subscribers/{token}` | `entity_cards.php:42` | 279 | `classes:read` + reach all | M |

**Counts: S 8 (rows 1, 4, 12, 16, 18, 19, 20, 23), M 15, L 3 (rows 8, 10, 24).**
Sizes differ from `operation-domains.csv` for: 10 (csv M, here L: roster payload, cross-domain write, lock), 11 (csv S, here M: JSON details with fallbacks, latest-audit tie-break), 13 (csv S, here M: INNER JOIN quirk, name and gender from membership), 15 (csv L, here M: one SELECT and one batch), 18 (csv M, here S: the guard is shared with 17).

## 2. Classes `/admin` operations

Tables below are PHP; new names are in `classes.*` unless prefixed. New `classes.syllabus`, `class_levels`, `classes`, `class_students`, `student_transfers`, `class_audit_log`, `teachers`, `teachers_history` exist in `ClassesEntities.cs`.

### 2.1 GET `/admin/syllabus` (S)
- **Guard** `api_require_super_admin` (`syllabus.php:63`): `api_authenticate(true)`; `api_require('syllabus:update', [], 'Only super admins can access this resource')` (403); then `api_log_admin_action` (audit, see 2.1 side effects); then input.
- **Input** `include_inactive` (query): true/1/yes/on, false/0/no/off (case-insensitive, trimmed); `''` or absent false; else 422 `Invalid include_inactive`.
- **Reads** `class_levels` (`id, code, name, sort_order`, order `sort_order, id`) and `syllabus` where `deleted_at is null` [and `is_active = 1` unless included], order `sort_order, subject_name`. All classes-owned. No cross-domain read.
- **Response** 200 bare list, one entry per level (empty ones too): `{level_id:int, level_name:str, level_code:str, items:[{id:int, level_id:int, subject_name:str, description:str|null, link_type:"pdf"|"external", url:str, sort_order:int (null becomes 0), is_active:bool, created_at:datetime, modified_at:datetime|null}]}`.
- **Side effects** audit: one `admin_access_log` row (platform table) for a caller whose role is privileged (roles 1, 3, 4, 5, 7), page = request path, method, IP, user agent, referer, session null. Fire and forget (errors swallowed).
- **Size S.** Trap: `order by sort_order` puts NULL **first** in MariaDB, last in PostgreSQL: use `NULLS FIRST`.

### 2.2 POST `/admin/syllabus` (M)
- **Guard** as 2.1.
- **Input, in order** (all 422 unless noted): `level_id` missing or not `is_numeric` `level_id is required`; `subject_name` not a string or blank after trim `subject_name is required`; `url` same `url is required`; `link_type` default `pdf`, must be `pdf`/`external` `link_type must be 'pdf' or 'external'`; `sort_order` default 0 must be numeric `sort_order must be an integer`; `description` null or string `description must be a string`; then level must exist 400 `Invalid level_id`.
  Values stored **untrimmed** (trim only decides emptiness); numerics `(int)`-cast (`"3"`, `2.9` accepted).
- **Write** `INSERT syllabus (level_id, subject_name, description, link_type, url, sort_order, created_by)`; `created_by` = caller **token**. DB supplies `is_active=1`, `created_at=now`, `modified_at` null: the command must set `is_active`, `created_at`.
- **Response** 201, the new row as 2.1 item (`modified_at` null).
- **Reads** `class_levels` (same domain).

### 2.3 PUT `/admin/syllabus/{syllabus_id}` (M)
- **Guard** as 2.1; then `api_body()` (422 invalid JSON) **before** the existence check; row must exist and not be soft-deleted else 404 `Syllabus item not found`.
- **Input** partial; a field counts as given when present and not null (so `sort_order:0`, `is_active:false`, `description:''` are given). Checks in order: `subject_name` string; `description` string; `link_type` in pdf/external; `url` string; `sort_order` numeric; `is_active` any value, stored `truthy ? 1 : 0` (PHP truthiness: `"0"`, `""`, `[]`, `0`, `false` are 0; `"false"` is 1). Failures 422 `<field> must be a string` etc. (same texts as create). **`level_id` is not updatable.** Nothing given 400 `No fields to update`. An empty `subject_name` or `url` string is accepted here (create refuses it).
- **Write** `UPDATE syllabus SET <given>, modified_at = now(), modified_by = <caller token> WHERE id`.
- **Response** 200, the row as 2.1 item. `description:''` reads back as null.

### 2.4 DELETE `/admin/syllabus/{syllabus_id}` (S)
- Guard as 2.1; no body read. Missing or soft-deleted 404 `Syllabus not found` (differs from PUT's text).
- **Write** `UPDATE syllabus SET deleted_at = now(), deleted_by = <token>`. **Trigger:** the column `modified_at` is `ON UPDATE current_timestamp()` in MariaDB (`schema.sql:1081`), so this soft delete also stamps `modified_at`; the new command must set it on every update **and** the delete.
- **Response** 200 `{"success": true}` (the code comment says 204; the code sends 200 with a body).

### 2.5 GET `/admin/transfers/classes` (M)
- **Guard** `api_require_transfers` (`student_transfers.php:64`): `api_require('students:transfer', [], 'Only administrators can transfer students')`. No audit log.
- **Reads** `ClassesModel::getAll(0, true)` (`models/classes.php:202`): every class incl. inactive, `classes c INNER JOIN class_levels` (a class with no level is dropped) `LEFT JOIN users` for `teacher_name` (**membership name by teacher token**), live student count `class_students where class_id and removed_at is null` (status not checked), group_concat tags (unused here). Ordered `c.gender, level.sort_order, c.id`. It also applies `assignedOnlyIds(classes:read)` to the **caller**; harmless today because only the super admin passes the guard (**unverified** if a grant is ever widened).
- **Response** 200 `{classes:[{id:int, code:str, name:text (0 if empty), level:str (level NAME), gender:int, teacher:text|null, city:text|null, country:text|null, students:int, active:bool (status = 'A')}], levels:[str]}`; `levels` = distinct level names in order of first appearance.
- **Cross-domain** membership: teacher name by token (batch). Size M (one list plus the name read).

### 2.6 GET `/admin/transfers/classes/{class_id}/students` (M)
- Guard as 2.5. Class (any status) not found, incl. non-numeric id: 404 `Class not found`.
- **Reads** `transferSourceRoster(classId, classActive)` (`classstudents.php:789`): active students `class_students cs JOIN users` where `removed_at is null and status='A'`, grouped by user, ordered `u.name`: `name, token, email, mobile` (**membership + identity**), **`joined_on = MIN(cs.created_at)` as a date (not the `joined_on` column)**. If empty **and the class is inactive**, fall back to the deactivation cohort (`getDeactivatedStudents`, `:78`): `cs.status='I' and removed_at not null and removed_reason like 'Class deactivated:%'` and no active enrolment anywhere (`not exists`), `removed_on = MAX(removed_at)` date, `joinedOn` null, flag `fromDeactivation`.
- **Response** 200 `{students:[{token:int, name:text (0 if empty), email:str|null, mobile:str|null, joinedOn:str|null, removedOn:str|null, fromDeactivation:bool}]}`. Contact details are returned (admin only).
- **Quirks** a token shared by two users doubles the row (`group by u.id`); the cohort query leaves out anyone active in any class.

### 2.7 GET `/admin/transfers/history` (M)
- Guard as 2.5. Query: `page` `max(1, (int))`; `pageSize` `min(100, max(1, (int)))` default 50 (**camelCase**); `q` string. No 4xx for them.
- **Reads** `searchTransferHistory` (`classstudents.php:809`): `student_transfers st INNER JOIN users u (student) INNER JOIN classes fc, tc INNER JOIN users ab (operator)`; with `q`: `u.name LIKE %q% OR CAST(token_no AS CHAR) = q OR fc.code LIKE OR tc.code LIKE OR st.reason LIKE OR ab.name LIKE` (`%` and `_` in `q` are **live wildcards**, not escaped). `ORDER BY transferred_at DESC, id DESC LIMIT/OFFSET`; separate `COUNT(*)`.
- **Response** 200 `{total:int, page:int, pageSize:int, items:[{id:int, studentToken:int, studentName:text, type:str, fromCode:str, toCode:str, reason:text|null, transferredBy:text, transferredAt:datetime}]}`.
- **Cross-domain (the hard part):** the search matches **member names** (student and operator), which live in membership, while the paging and ordering live in classes. Options for the design: membership read `TokensByNameAsync(q)` then `IN (...)`; or fetch names after paging and accept that name search needs the first step. Shared-token users duplicate rows and inflate `total` (INNER JOIN on a non-unique token); a transfer whose operator or student has no user row disappears from the list **and** the count.
- Size M (L if the name search is built to PHP parity with a very common `q`).

### 2.8 POST `/admin/transfers` (L)
- Guard as 2.5, then `api_body()`.
- **Input, in order** (422): `fromClassId` and `toClassId` both JSON **integers** (a float `5.0` or string fails) `Source and destination classes are required`; equal `Source and destination classes must be different`; `type` in transfer/promotion/demotion `type must be transfer, promotion or demotion`; `reason` (trimmed, `(string)` of anything) over 500 chars `reason must be at most 500 characters`; `tokens` non-empty array `Choose at least one student`; each token an int above 0 `tokens must be member tokens`. Then: either class unknown 404 `Class not found`; destination not active 422 `The destination class is not active`; genders differ 422 `A student can only move to a class of the same gender`. (The source may be inactive.)
- **Per student** (`transferMany`, `classstudents.php:761`): `array_unique` of the int-cast tokens, each in its **own transaction**, no member lock, no cross-request guard:
  1. active in source (`class_id, token_no, removed_at null, status 'A'`)? If not: allowed only for the deactivation cohort (`status 'I'`, `removed_at` set, `removed_reason like 'Class deactivated:%'`); else fail `Student {t} is not active in source class #{from}`. Cohort members who hold **any** active enrolment anywhere fail `Student {t} already has an active class; skipped`. (An active student with other active classes is not checked.)
  2. active in destination: fail `Student {t} is already enrolled in destination class #{to}`.
  3. unless cohort: `UPDATE class_students SET removed_at=now(), removed_by=<admin token>, status='I', removed_reason = ucfirst(type)+' to class #'+to [+ ': '+reason] WHERE class_id=from AND token_no AND removed_at IS NULL` (all matching rows; **`mcq_admin` is not reset**, unlike `removeStudent`).
  4. `INSERT class_students (class_id=to, token_no, joined_on=now())` (status default 'A', `added_by` null, no `class_registrations` row).
  5. `INSERT student_transfers (token_no, from, to, type, reason, transferred_by=<admin token>)`; `reason` is `''` when empty; `transferred_at` DB default (command must set).
  6. after commit `searchoutbox->touch('person', token)`.
  A database error is recorded as `Could not be moved`; any other exception message goes to the admin verbatim. A reason of about 480+ characters makes step 3's `removed_reason` (varchar 500) overflow; in MariaDB strict mode every student then fails `Could not be moved` (**unverified**: non-strict mode truncates silently); the new schema's length check would fail it.
- **Response** 200 always, even if all failed: `{moved:[{token:int, name:str|null}], failed:[{token:int, name:str|null, reason:str}]}`. `name` comes from the **source class roster** (2.6, so contact-free, entity not decoded), null when the token is not on it.
- **Cross-domain** reads: member names (membership) for the roster. Writes are all classes. **Contract in text:** the removed_reason prefixes `Transfer to class #`, `Promotion to class #`, `Demotion to class #` and `Class deactivated:` are read back by the roster (`getRemovedStudents` excludes the first three) and the cohort query: keep the exact strings.
- **Size L:** per-student transactions with 4 refusal paths, text contracts, events, and no lock in PHP (the port must decide whether to add one).

### 2.9 GET `/admin/members/{token}` (M)
- **Guard** `api_require_member_enrol` (`member_enrol.php:43`): `api_require('members:enrol-by-token')` 403 default text; then `api_log_admin_action` (audit); then rate limit bucket `member_lookup` 30 per 3600 s per user, 429 `Too many lookups. Please wait a while and try again.` (counts every call, found or not); then the model re-checks the permission (null result becomes 403 `You do not have permission to do that`); any throwable 500 `Something went wrong. Try again.`.
- **Input** token from the path: `^\d{1,18}$` else treated as 0. 0 or no user: 404 `No registered member has this token`; more than one user holds it: 422 `{"detail":"More than one member has that token number. Please contact an admin.","code":"ambiguous_token"}`.
- **Reads** (`entityaccess.php:99`): `users` (`name, gender, email, mobile, city, country, createdon`: **identity + membership**; gender through `genderOf`: '1'/'Male' is 1, '2'/'Female' is 2, else null); latest `class_registrations` row by `id desc` with class code/name (**membership**, class from classes, **no status filter on the class**), hidden when `for_classid <= 0`, the class is gone, or status is `Accepted`; `classesNow` (**classes**): distinct active-enrolment (`removed_at null, status 'A'`) in active classes, `order by code limit 50`, with level name; `classesLeft` (classes): latest enrolment row per class that is not currently active in an active class, `order by cs.id desc limit 50`, `leftOn` = date of `removed_at`.
- **Response** 200 `{token:int, name:text, gender:int|null, email:str|null, mobile:str|null, city:text|null, country:text|null, registeredOn:date|null (first 10 chars of createdon), requestedClass:{id,code,name}|null, classesNow:[{id,code,name,level:text|null}], classesLeft:[{id,code,name,leftOn:date|null}]}`.
- **Cross-domain:** identity (`createdon`: `UserRef` has no CreatedOn, extend it), membership (name, gender, mobile, city, country; latest registration), classes own the rest.

### 2.10 POST `/admin/members/{token}/enrolments` (L)
- **Order:** guard (`members:enrol-by-token` 403) -> body `classId` must be a JSON int above 0 else 422 `classId must be a class id` -> class must **exist and be active** else 404 `Class not found` (so the `class_inactive` answer below is unreachable except in a race) -> `api_require('students:enrol', ['class'=>id], "You do not have permission to change this class's students")` 403 -> audit -> rate limit bucket `member_enrol` 30 per hour per user, 429 same text as 2.9 (counts failures).
- **Model** `enrolByToken` (`classstudents.php:197`): class row (gender, status); token <= 0 `not_found`; `select id from users where token limit 2` (0 rows `not_found`, 2 `ambiguous`); transaction whose **first statement locks the member's `users` row** (`UPDATE users SET roleid = roleid`); re-read the class (inactive: `class_inactive`); `users.gender`; already actively enrolled in this class (`status 'A', removed_at null`): `already_enrolled`; member gender known and different from the class's: `other_gender` (unknown gender is allowed); else **restore the latest removed or non-A row of that class** (`status 'A', removed_at/by/reason null, joined_on=now(), mcq_admin=0, added_by=<operator token>`) or `writeEnrolment`: **if the token has no `class_registrations` row at all, insert one (`for_classid`, `status 'Accepted'`)**, then `INSERT class_students (class_id, token_no, joined_on=now(), added_by)`. Commit only on `enrolled`; search touch `person`. Any throwable: 500 `Nothing was changed`.
- **Refusals:** `not_found` 404 `No registered member has this token`; `ambiguous` 422 (as 2.9, code `ambiguous_token`); `already_enrolled` 409 `This member is already in this class` + `code`; `other_gender` 422 `This class is for the other gender` + `code`; `class_inactive` 409 `This class is not active` + `code`; anything else 500 `Nothing was changed`.
- **Response** 200 `{saved:true, students:[{token,name,email,mobile,joinedOn,notes,mcqAdmin}], removedStudents:[{token,name,email,mobile,removedAt,removedReason,removedByName}], mcqStudents:[{token,name,email,mobile}], transferHistory:[{studentToken,studentName,fromClassId,fromClassCode,toClassId,toClassCode,type,reason,transferredBy,transferredAt}]|null}`: the manage-roster builder `api_manage_roster_for` (`class_manage.php:691`), shared with `POST /classes/{id}/students` and the manage payload. Super admin: contacts present and `transferHistory` an array (it holds `students:transfer`). If the roster build throws after commit: 200 `{saved:true, roster:null}`.
- **Cross-domain:** WRITE to membership's `class_registrations` (the insert above: **classes may not write it**; needs a membership command or an event consumed there, see 6(d)-5); member row lock (identity table: use an advisory lock in classes' own lock class, as membership does with 3001); gender (membership); roster names and contacts (membership + identity); `mcqStudents` reads **assessment** (`spot_quiz_responses` joined to `spot_quizzes` by `class_id`: tokens who took the class's quizzes) through a port.
- **Size L:** 9 outcomes, a lock, a cross-domain write, the roster payload (also needed by 6 other classes operations), an assessment read.

### 2.11 GET `/admin/deactivated-classes` (M)
- Guard: `api_require('deactivated-classes:manage')` (default 403 text). No audit.
- **Reads** `ClassesModel::deactivatedClasses(0)` (`classes.php:1870`, SQL `getDeactivated` `:1958`): `classes where status='I'` `INNER JOIN class_levels`, `LEFT JOIN users` for teacher, deleter and performer names (**membership**), and the **latest** `class_audit_log` row with `action='deactivated'` per class (max `performed_at`, then max `id`). Order `COALESCE(performed_at, deleted_at) DESC, id DESC`. `details` is JSON `{type, effective_date, reason}`: `type` falls back to `completed` (if `completed_on`) / `shutdown` (if `shutdown_on`); `effective_date` falls back to those dates; `reason` falls back to `classes.comments`; `performed_by` falls back to the deleter's name, then `#<deleted_by>`. Log: `deactivationLog(500)`: every `deactivated` audit row, newest first, `LIMIT 500`, `LEFT JOIN` classes (`code` falls back to `#<class_id>`).
- **Response** 200 `{deactivated:[{id:int, code:str, level:str, gender:int, teacher:str ('' if none), type:str, effectiveDate:str, reason:text|null, performedBy:str, performedAt:str|null}], log:[same minus teacher, + performedAt]}`; `performedAt` = stored UTC value as `YYYY-MM-DDTHH:MM:SSZ` (**with Z**, unlike the other datetimes), null for a zero date.
- **Cross-domain:** names only (membership). **Writer of the log is `POST /classes/{id}/deactivate`** (`classes.php:1727`), not in this scope but it fixes the `details` contract above.

### 2.12 GET `/admin/deactivated-classes/candidates` (S)
- Same guard. `activeClassesForDeactivation()` = `getAll(0, false)` (active classes, as 2.5).
- **Response** 200 `{classes:[{id:int, code:str, level:str, gender:int, teacher:str ('' if none), city:str ('' if none), students:int}]}`. Teacher name = membership.

### 2.13 GET `/admin/teachers` (M)
- **Order:** `api_authenticate(true)` -> gender: `genderLock(user, 'teachers:read')` (gender admin or single-gender coordinator: their own gender) else the query `gender`: exactly `2` is ladies, **anything else is gents** (no 422) -> `api_require('teachers:read', ['gender'=>g])` 403 default text. No audit.
- **Reads** `TeachersModel::getAll(gender)` (`teachers.php:39`): `teachers t INNER JOIN users u` where **`u.gender = :gender`** (varchar against number: only '1' / '2' match; 'Male', 'Female', null never) and `t.status = 'A'`, `INNER JOIN` a derived table of **the teacher's own active enrolment as a student** (`class_students` status 'A', removed null, class active; `MIN(class id)`, `MIN(class_level_id)`, `MIN(cl.code)`): **a teacher who is not currently a student in an active class is absent from the list**; `LEFT JOIN` active classes they teach (`c.teacher = t.token`) for `count(c.id)` and `group_concat(code order by level sort_order, id separator ', ')`. Group by teacher, `ORDER BY u.name`.
- **Response** 200 `{gender:int, levels:[{key,code,name}] (salman SM, abuzar AG, miqdad MK, ammar AY, bilal BL; name = ucfirst(key)), teachers:[{token:int, name:str, level:str (MIN of the level **code string**, so alphabetical, not by sort order), classes:int, flags:{salman,abuzar,miqdad,ammar,bilal: bool}, conducting:[str]}]}`. `conducting` is the group_concat split on `', '` (breaks on a code containing that).
- **Cross-domain:** `users.name` and `users.gender` (membership) per teacher token (about 180 rows), plus the genderLock from access. No contact details are returned.

### 2.14 POST `/admin/teachers/training` (M)
- **Guard** `api_authenticate(true)`, `api_require('teachers:read')` (no target; 403 default text) **before** reading the body.
- **Body** `changes` (array, else `[]`), `comments` (string, else `''`). Model `changeTrainingLevels` (`teachers.php:666`), all refusals are `TeacherChangeRefused` with a status:
  1. `comments` trimmed empty 422 `A comment is required`; over 500 chars 422 `The comment must be 500 characters or fewer`; no changes 422 `There is nothing to change`.
  2. **per change, sequentially** (an early 404/403 can precede a later shape error): must be an array with `token` (numeric), `level` (one of the 5 keys), `action` (`added`/`removed`), all `isset` (null fails) else 422 `Each change needs a teacher, a level and added or removed`; then the teacher's `users.gender` **`(int)`-cast**: no user 404 `Teacher #{t} not found`; gender not 1 or 2 (so 'Male'/'Female' text, empty) or `can(teachers:read, [gender])` false 403 `You do not have permission to change teacher #{t}`.
  3. then one transaction (`addOrRemove`/`writeBatch`, `teachers.php:287`): per teacher, current flags (all 0 if no `teachers` row; `get` joins `users`), the batch of changes applied per level, then `INSERT teachers` (new) or `UPDATE teachers SET five flags, status='A', comments, updated_by=<token>, updated_at=now()`; `INSERT teachers_history (token, five flags, status 'A', comments, created_by, created_at=now())`. `comments` format: `UPDATE: <text> - Batch ID: <uniqid()> - +SM, -AG` (only flipped levels, ` - ` then empty list if none) or `ADD: <text> - Batch ID: <uniqid()> - +SM,...` for a new teacher; `teachers.comments` is varchar(1000). After commit `touch('teacher', token)` for each. Reactivates a teacher whose status was not 'A'.
- **Response** 200 `{changed:int}` = number of **distinct tokens** in the request. Unknown throwable: 500 `The training could not be changed, and nothing was changed. Please try again.`.
- **Cross-domain:** gender by token (membership); `teachers:read` per-teacher check (access). Writes classes only.

### 2.15 POST `/admin/teachers/import` (M)
- Gender as 2.13 but from **body** `gender` (`2` ladies else gents); `api_require('teachers:read', ['gender'=>g])`.
- **Reads** active classes grouped by `classes.teacher` joined to `users` with **`u.gender = :gender`** (string-equal '1'/'2'), `MIN(class_level_id)`, left join `teachers` where no record exists. Flags from the minimum level id L: `salman = (L == 1)`, `abuzar = (L <= 2)`, `miqdad = (L <= 3)`, `ammar = (L <= 4)`, `bilal = (L <= 5)` (**salman uses `==`, the rest `<=`**; copy it).
- **Write** `add(rows, 'Imported from Active Classes')` in one transaction: `INSERT teachers` and `teachers_history` per row, comments `ADD: Imported from Active Classes - Batch ID: <uniqid> - +AG, ...`; `touch('teacher')` per row after commit.
- **Response** 200 `{added:int}`; failure 500 `The teachers could not be imported, and nothing was changed. Please try again.`. Idempotent: a second call finds nobody without a record.
- **Cross-domain:** teacher gender by token (membership), class level (classes). Size M (the csv's L is not earned: one SELECT and one batch).

## 3. Membership operations (deltas on MR)

For each, MR already records the PHP behaviour (section in brackets). This adds the classes-era needs and anything MR got wrong or left out.

| # | Op | MR | Classes-era dependency now needed | Delta, new facts |
|---|---|---|---|---|
| 16 | GET `/me/children` | 2.3 | per child active classes `(class_id, name, code)`, predicate **cs.status='A' AND removed_at null AND c.status='A'**, order `c.id`; port to classes | `status` is the literal `'A'`; `name` is the raw column (not entity-decoded, not cast); the response is not `api_cast`ed so `gender` is `(int)` of the varchar. No new fact beyond MR |
| 17 | POST `/members/{c}/parent-links` | 2.10 | `staffMayAddFor` needs the child's **active classes** (predicate as 16) and per-class `CanAsync(parents:add, class)` | `expires_at` is written with PHP `date()` in the server zone (UTC); response `expires_at` is `Y-m-d H:i:s`, not ISO. `invalid_creator` and an ambiguous child token both fall to 404 `Student not found`. The invite lock is on the child's `users` row; built code uses `GuardianLock` |
| 18 | GET `.../parent-links` | 2.11 | as 17 | MR complete |
| 19 | DELETE `.../parent-links/{id}` | 2.12 | as 17 | cancel is checked on **child token + invite id** only; `parents:manage` gender is `(int)` of the child's gender text |
| 20 | GET `.../candidate/{parent}` | 2.13 | `staffMayAddFor(direct)` as 17 | rate limit counted before scope (confirmed `children.php:354`) |
| 21 | POST `.../parents` | 2.14 | as 17 | confirmed; `insertDirect` also takes the child lock; `source='token_entry'` |
| 22 | POST `/registrations/{id}/reject` | 2.22 | the waiting-list query needs "token is in an active class" (classes port, predicate **c.status='A' AND cs.removed_at null; cs.status not checked**) and `users.email` (identity) and `users.gender` (profile) | permission order verified (see 4.22); **the UPDATE has no `status` filter, so it also turns `Accepted` and `Pending` rows of that token into `Rejected`, with `status_reason`**; `modified_by` is the caller's **users.id**, while enrolment code elsewhere writes tokens |
| 23 | GET `/admin/donors` | 2.23 | tokens of every **enrolment row** with `removed_at null` in an active class (`cs.status` not checked), with repeats | one output row per enrolment row x user row: duplicates by design. Order `u.name` (collation of names, now in membership) |
| 24 | GET `/admin/donors/download` | 2.24 | as 23 | `format` is checked **before** sign-in (`donors.php:39` runs `api_report_download_format()` first): a bad format with no token is 422, not 401. The xlsx/pdf generator does not exist yet: platform owns it (`domains/CLAUDE.md` row `reportexport.php`) |
| 25 | GET `/students/{t}` | 2.25 | member's current classes (id, code, gender, level name): predicate **c.status='A' AND removed_at null (cs.status not checked)**, order `code` | reach filter uses access `Reach` (`All`, `Gender`, `ClassIds`) |
| 26 | GET `/subscribers/{t}` | 2.26 | "has no current class" (same predicate) and the code of the registration's class (any class status) | reach `All` only |

## 4. Auth and failure order, membership rows not fully in MR

- **22 reject** (`registrations.php:95`): `api_authenticate(true)` -> caller must hold `registrations:read` for gents **or** ladies, else `api_require('registrations:read', gents)` 403 default text, **before** the id is looked up -> pending registrant by id (`pendingRegistrant`, `subscribers.php:578`; MAX-grouped per token) none: 409 `This registrant is no longer waiting: they have been placed or rejected.` -> `registrations:read`[registrant gender] 403 -> `registrations:reject`[registrant gender] 403 -> body `reason` string trimmed, 1 to 500 chars (`mb_strlen`) else 422 `reason is required, at most 500 characters` -> `rejectRegistration(token, reason)` -> `log_event('registration.rejected')` -> 200 `{rejected:true, registrationId:int}`. The registrant's `gender` is `(int)` of the text, so 'Male'/'Female'/null is gender 0 and no gender-scoped grant reaches them.
  Waiting-list SQL (reused by reports and place, other scopes): per token MAX of every column, `status != 'Rejected'`, not in an active class, `email NOT LIKE '%@thestrongrope.com'`, optional `r.id = :id`, order `created_at DESC`. MR 2.17 holds the quirks.
- **16, 23, 25, 26**: no failure beyond the permission (403) and, for cards, 404 `Person not found`.
- **24**: `format` 422 `format must be xlsx or pdf` first; then sign-in; `donors:read`; no rows 404 `There are no donors to download`.

## 5. Table map (PHP to new, with owner)

| PHP table | New | Owner | Read by | Written by |
|---|---|---|---|---|
| `syllabus` | `classes.syllabus` | classes | 1-4 | 2-4 |
| `class_levels` | `classes.class_levels` | classes | 1, 2, 5, 11, 12 | none |
| `classes` | `classes.classes` | classes | 5, 6, 8-12, 13, 15 | none here |
| `class_students` | `classes.class_students` | classes | 5, 6, 8, 9, 10, 13, 16, 17, 21, 22, 23, 25, 26 | 8, 10 |
| `student_transfers` | `classes.student_transfers` | classes | 7, 10 (history) | 8 |
| `class_audit_log` | `classes.class_audit_log` | classes | 11 | none here (deactivate writes) |
| `teachers`, `teachers_history` | `classes.teachers`, `classes.teachers_history` | classes | 13 | 14, 15 |
| `users` (id, token, email, createdon) | `identity.users` | identity | 9, 22, 25, 26, parent ops | none |
| `users` (name, gender, mobile, city, state, country, zip, first/last name) | `membership.member_profiles` (key `user_id`) | membership | 5-7, 9, 10, 11-15, 16, 20, 22-26 | none |
| `users.roleid` | `access.user_roles` | access | via `CanAsync` | none |
| `class_registrations` | `membership.class_registrations` | membership | 9, 22, 26 | 22 (UPDATE), **10 (INSERT by classes: cross-domain)** |
| `user_guardians` | `membership.user_guardians` | membership | 16-21 | 17, 19, 21 |
| `spot_quiz_responses`, `spot_quizzes` | `assessment.*` | assessment | 10 (roster candidates) | none |
| `admin_access_log` | `platform.admin_access_log` | platform | none | 1-4, 9, 10 (audit) |
| `outbound_messages` (search touch) | `platform.outbound_messages` | platform | none | 8, 10, 14, 15 (touch) |

## 6. Closing

### (a) Helpers shared by several handlers

| Helper | PHP | Used by | Note |
|---|---|---|---|
| `api_require_super_admin` + audit | `syllabus.php:63`, `lib/audit.php` | 1-4 (and 9, 10 via `api_log_admin_action`) | audit write needs a platform interface (platform design says it is built "together with the interface other domains use to write the log") |
| `api_require_transfers` | `student_transfers.php:64` | 5-8 | one permission, one wording |
| `ClassesModel::getAll` (list with level, teacher name, student count, assigned-only scope) | `classes.php:202` | 5, 12 (and `/registrations/{id}/classes`, other scopes) | classes-owned; teacher name from membership |
| `transferSourceRoster`, `getStudents`, `getDeactivatedStudents` | `classstudents.php` | 6, 8 | roster with names and contacts |
| `api_manage_roster_for` (+ `getRemovedStudents`, `getStudentsFromMCQs`, `getTransferHistory`) | `class_manage.php:691` | 10 (and 6 other manage operations) | needs assessment and membership reads |
| Member lock + enrolment write (`enrolByToken`, `restoreLatestRemoved`, `writeEnrolment`) | `classstudents.php:197-340` | 10 (and `place`, `POST /classes/{id}/students`, `bulk`) | one command in classes |
| `staffMayAddFor`, `validateMemberToken`, invite/direct insert | `guardians.php` | 17-21 | built partly: `GuardianLock`, `GuardianRules`, `MemberRateLimit`, `LinkLister` |
| `pendingRegistrant` / `waitingRegistrations` | `subscribers.php:578` | 22 (and reports, place, classes picker) | MR 2.17 |
| `genderOf` ('1'/'Male' is 1, '2'/'Female' is 2) vs `(int)` cast | `entityaccess.php:279` | 9, 10, 25, 26 use `genderOf`; 13, 14, 15, 17-22 use `(int)` or varchar equality | two readings exist: keep both (`PhpValue.IntOfText` covers the cast) |
| `TeachersModel` flags, `LEVELS` constant, writeBatch | `teachers.php` | 13-15 | |
| `api_cast`/`text` decoding | `lib/response.php` | all | `PhpText`, `PhpValue` in membership; classes needs the same rules (including the 0-for-empty-`text` quirk): decide a shared place (`shared/api`) rather than copy |
| `rate_limit_allows` | `functions.php:1168` | 9, 10, 20 | `MemberRateLimit` exists |
| Report export xlsx/pdf | `reportexport.php` | 24 | not in repo; platform owns |

### (b) Cross-domain reads, by owning domain

**identity** (`UserDirectory`: `ByTokenAsync`, `ByTokensAsync`, `ByIdsAsync` return `UserRef(Id, Token, Email)`)
- covered: user id by token for guardian ops (17-21, built slices already do), email for the `@thestrongrope.com` filter (22), existence of a token (9, 10 `not_found`/`ambiguous` via `ByTokenAsync` count; max 50 matches, use count of 2).
- **gap:** `createdon` for `registeredOn` (9). Extend `UserRef` or add a method.

**membership** (`MemberNames.ByUserIdsAsync` returns names only, by user id, max 500)
- needed by classes: name by **token** (5, 6, 7 (search and display), 8 (names), 9, 10 roster, 11, 12, 13), gender text by token (13, 14, 15; (int) vs '1'/'2' reading), contact (`email`, `mobile`, `city`, `state`, `country`, `zip`) by token (6, 9, 10), `first_name`/`last_name` (16, built side), latest `class_registrations` row (9), a name search returning tokens (7: `u.name LIKE`, `ab.name LIKE`), a batch of tokens by gender (13, 15 if the filter is pushed down).
  `MemberNames` covers only the name by user id and needs a token-to-user-id hop through `UserDirectory`; **a new public read (for example `MemberDirectory`) is needed** with batch by token, name search, gender, contact. Classes then lists `membership` in `Dependencies` (no cycle: membership reaches classes only through ports).
- needed by classes, **write:** insert of the `Accepted` registration when none exists (10): a membership command or an event.

**classes** (needed by membership; port `IClassEnrolments` today has one method, `IsEnrolledAsync(token)`: status 'A', removed null, **any class status**)
- the predicates actually used, all different:
  | Predicate | Used by |
  |---|---|
  | cs.status='A' AND removed null (class status ignored) | existing gender lock (`PATCH /me`) |
  | cs.status='A' AND removed null AND c.status='A' | 16, 17-21 (`staffMayAddFor`) |
  | removed null AND c.status='A' (cs.status ignored) | 22 (waiting list), 23, 25, 26 |
- shapes: active classes per token batch `(classId, name, code)` (16); classes per token `(id, code, gender, levelName)` (17-21 only ids + class ids, 25); `bool has any current class` (26); **enrolment tokens, with repeats** (23); `class code by id`, any status (9 for membership's registration side, 26).

**access** (`Permissions.CanAsync`, `ReachAsync` with `All, Gender, ClassIds, AssignedOnlyIds, GenderLock`): covered for all actions above; class-target checks (`students:enrol`, `parents:add`, `parents:add-direct`) work only after classes supplies `IClassScopes`. `teachers:read` with a gender target and `genderLock` (13, 15) come from `ReachAsync(...).GenderLock`.

**assessment:** tokens who answered a quiz of class X (`spot_quiz_responses` join `spot_quizzes.class_id`) for `mcqStudents` (10; and the other manage operations).

**platform:** admin audit write (1-4, 9, 10), report export (24), outbox/outbound_messages (events, search touch). `MemberRateLimit` and `Outbox` are in `shared/api` and ready.

**search, notifications:** no reads. Events only (c).

### (c) State changes that deserve an event (past tense, id, fields)

| Event | Op | Id | Fields |
|---|---|---|---|
| `StudentTransferred` | 8 | `student_transfers.id` | tokenNo, fromClassId, toClassId, type, reason, transferredBy, fromDeactivation |
| `EnrolmentEnded` (reason `transfer`) | 8 | class_students row id | classId, tokenNo, removedBy, removedReason |
| `StudentEnrolled` | 8, 10 | class_students row id | classId, tokenNo, addedBy, restored (bool) |
| `MemberRegistrationRecorded` (auto Accepted row) | 10 | class_registrations id | token, forClassId (consumed by membership if it owns the insert) |
| `TeacherTrainingChanged` | 14, 15 | teacher token | flags before and after (five), batchId, comments, changedBy, created (bool) |
| `TeachersImported` | 15 | none | gender, tokens |
| `SyllabusItemCreated` / `SyllabusItemChanged` / `SyllabusItemDeleted` | 2, 3, 4 | syllabus id | levelId; changed field names; deletedBy (low value: nobody consumes; optional) |
| `RegistrationRejected` | 22 | registration id (the token's rows) | token, reason, rejectedBy (users id), affected row count |
| `GuardianInviteCreated`, `GuardianInviteCancelled`, `GuardianLinkAdded` | 17, 19, 21 | user_guardians id | childToken, parentToken, relationship, createdBy (users id), expiresAt |
| search touches | 8, 10, 14, 15 | token | derived from the events above (person on enrolment change, teacher on training change) |

### (d) Quirks and suspected PHP bugs

1. **Auth kind in `operations.csv`**: 15 rows are `member` though PHP calls `api_authenticate(true)`: syllabus x4, transfers x4, members x2, donors x2, parent-links x3. The 11 `create` rows are right. `RouteSurfaceTests` expects a creating sign-in only for built `create` rows, so decide the kind per row when each slice is built (PHP behaviour is create for all).
2. **Non-nullable `text` casts to the integer 0** when empty (`api_cast_value`): `name` in 5, 6, 9; `studentName`, `transferredBy` in 7. A member without a name shows `0`.
3. **Syllabus**: `modified_at` is `ON UPDATE` (soft delete also stamps it); DELETE returns 200 `{"success":true}`, not 204; PUT accepts empty `subject_name`/`url` but POST refuses them; `is_active` uses PHP truthiness (`"false"` is active); PUT 404 text differs from DELETE's; `sort_order` NULL ordering.
4. **Transfers**: no lock and no all-or-nothing, a concurrent double submit can enrol twice (duplicates are possible: no unique key on `class_students`); `mcq_admin` not cleared on transfer-out (cleared by remove/restore/rejoin/enrol-restore); a long reason overflows `removed_reason`; a transfer-in clears nothing and adds no `class_registrations`; the response name comes from the source roster only; `joinedOn` in the roster is `MIN(created_at)`, not `joined_on`; history search wildcards live; INNER JOINs on non-unique `users.token` duplicate rows.
5. **Enrol (10)**: `students:enrol` precedes the throttle but the class active check (`api_find_class`) makes `class_inactive` unreachable; PHP writes `class_registrations` from the classes model (cross-domain write in the target design); the rate limit counts failures; roster failure after commit is still 200.
6. **Teachers**: list only shows teachers who are *students* of an active class (INNER JOIN on `class_students`); `level` is MIN of the code string; `u.gender = :gender` (varchar vs number) excludes 'Male'/'Female'/null from list and import, while training uses the `(int)` cast and refuses them with 403; `conducting` split on `', '`; training validation is interleaved per change; import flags use `==` for salman and `<=` for the rest; `changed` counts distinct tokens; a teacher with status other than 'A' is reactivated by any training change; there is no way to remove a teacher (status 'I' is written by `remove()`, which no route calls).
7. **Donors**: duplicates by design (one row per enrolment row, `cs.status` unchecked); download checks `format` before auth.
8. **Reject**: updates **all** rows of the token regardless of status (see section 3 row 22); `modified_by` is users.id; uses MAX-grouped waiting rows where `MAX(status)` on the enum may hide a token with any `Rejected` row (MR, unverified).
9. **Deactivation reads**: effective date, type and reason fall back to class columns when the audit JSON is missing; `performedAt` has `Z`, other datetimes do not; the cohort rule depends on the prefix `Class deactivated:` (set by `deactivate()`, `classes.php:1793`, truncated to 300).
10. **`getAll` scope**: `students:transfer`, `deactivated-classes:manage` and `registrations:*` lists go through `assignedOnlyIds(classes:read)` of the caller (`classes.php:205`), an unstated second filter; irrelevant for the super admin.
11. **Non-unique `users.token` multiplies rows in more joins than 2.7**: `getAll` (teacher name), `getDeactivated` (teacher, deleter, performer) and `deactivationLog` (performer). 2.5 and 2.6 re-key classes by id (`api_transfer_classes_by_id`), which hides duplicates; 2.11 and 2.12 iterate rows, so a class repeats for a shared teacher token (1,729 times if `classes.teacher = 0`). A C# name lookup keyed by token removes duplicates silently: a parity decision.
12. 24: PHP checks `format` before sign-in; an endpoint-level `RequireMember()` answers 401 first, so the builder must order it explicitly.
13. 13 and 15 bind `:gender` through `execute([...])`, so MariaDB compares it as a string (`'1'`, `'2'`), not a number.
14. Guardians: createInvite refusals other than the cap all read 404 `Student not found`; `expires_at` format; unchanged from MR.

### (e) Not determined

- Production values: `REDIRECT_URI` for `public_web_base()` (link text of 17); whether any `class_students` row has `status<>'A'` with `removed_at` null (affects 23, 25, 26 predicates); how MariaDB compares `users.gender` (varchar) to an integer for strings like `'1 '` or `'01'` in 13 and 15 (**unverified**; no DB read).
- What `page` the audit row records for an API call (PHP logs `REQUEST_URI`'s path, which may carry a gateway prefix), and whether calls whose basename is `index.php` are skipped by `should_log_admin_page_access`: **unverified**, so it is unknown whether API calls are logged at all behind the gateway.
- Whether any `classes.teacher = 0` (or a shared teacher token) exists in production: decides whether 2.11 and 2.12 repeat classes.
- Client behaviour: the Flutter screens that call these routes were not read; response field names are from PHP specs only (`tools/api-contract/contract.json` has 19 matches for transfers and syllabus paths, not compared).
- Whether `teachers` and `teachers_history` carry `comments` over 1000 characters in production data (affects the new CHECK on load).
- `students:transfer` etc. are role-1 only in the catalog; whether a hand grant (`permission_grants`) gives another member these actions in production is unknown, which would make the `getAll` assigned-only filter (d)-10 live.
- Behaviour of the unread parts of `class_manage.php` (roster payload helpers `api_manage_*`) was read for shape only.
