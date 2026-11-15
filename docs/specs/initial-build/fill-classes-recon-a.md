# Fill recon A: the `classes` domain, member-facing routes (47 operations)

Read-only recon of `~/Projects/tsr-account` (PHP, `develop`), source only: no database, no container, no `.env`. PHP paths are under `web/`
(`api/mobile/index.php` = router, `api/mobile/routes/*.php` = handlers, `models/*.php` = SQL). Scope: the 47 `planned` rows of
`operations.csv` (domain `classes`) whose path starts `/classes`, `/class-levels`, `/join`, `/registrations`, `/teachers`, `/syllabus`, `/guides`,
`/me` (the three `/me/children/{child_token}/classes...` routes and `/me/guides*`). Not `/admin`, not `/reports`, not class notifications (not in the catalog's 47).
Format follows `phase-3-membership-recon.md`; the `api_cast` rules are stated there (section 1, "Shared conventions") and are not repeated, except where this file
adds to them. No real member data appears here. Anything not confirmed is marked **unverified**.

Sizes: **S 22, M 17, L 8**.

## 0. Conventions and shorthands (defined once)

**Router** (`index.php:297-318`): `{x}` matches `[^/]+`; handlers cast with `(int)`, so `/classes/5abc` is class 5 and `/classes/abc` is class 0 (404). Unknown path 404 `Not Found`,
wrong verb 405 `Method Not Allowed`. Literal routes (`/classes/join`, `/classes/create-options`, `/classes/teachers`) are listed before `/classes/{class_id}` (`index.php:72-143`).

**PDO** (`functions.php:554-556`): `ERRMODE_EXCEPTION`, `FETCH_ASSOC`, **`EMULATE_PREPARES = false`**. Native prepares return integer columns as PHP ints, so `===`
comparisons on ids work (`getValidTagIds`, the schedule diff in `update()`, `add()`'s `cnt !== 0`). `AVG`/`SUM`/division give strings, so every float needs `api_cast`.
A named placeholder may be used only once per statement (hence `student_token2`...). Responses that skip `api_cast` (marked **raw**) take whatever PDO gave.

**Shorthands used in the guard chains:**

| Code | Meaning (PHP) | Refusal |
|---|---|---|
| AUTH | `api_authenticate(true)` (`lib/auth.php:106`): bearer, Firebase verify, get-or-create member, deletion gate, login tracking, claim sync. Identity's job (already built). | 401 `Not authenticated` / `Invalid auth token` / `Email not present in token`; 403 `Registration incomplete` (token 0); 403 `Account deletion pending` (+`deletion_status`); 404 `User not found` |
| P(a, tgt, "msg") | `api_require(a, tgt, msg)` (`response.php:232`): `Permissions.CanAsync`; target `[class=id]`, `[gender=g]` or none; logs `permission.refused` | 403 `You do not have permission to do that` unless "msg" is given. Unknown action throws (500) |
| GI | `api_require_identity` (`classes.php:124`): users.gender must be numeric | 400 `User gender not set; update profile first` |
| GC | `api_find_class` (`response.php:247`): `ClassesModel::get()`: class active (`status='A'`) AND INNER JOIN `genders`, `class_levels`, `users`(teacher); also loads roster and tags (cost only) | 404 `Class not found`. A class missing any of the three joined rows is a 404 everywhere (quirk, see (d)) |
| BODY | `api_body()`: empty body `[]`; invalid JSON or scalar | 422 `Invalid JSON body` |
| LOGADM | `api_log_admin_action` (`lib/audit.php`): inserts `admin_access_log` (platform) only for privileged role ids (1,3,4,5,7), once per request; never fails the request | none |

**Member permission set** (`permissions.php:31-53`): every member holds `classes:join:self, classes:read:enrolled, sessions:read:enrolled, attendance:read:self, performance:read:self,
syllabus:read:all, children-performance:read:self, ...`; teachers/MCQ-flagged members also hold `classes:read:own, sessions:create:own, sessions:update:own, class-students:read:own,
classes:schedule:own, mcqs:manage:own, notifications:send:own`; teachers also `class-students:update:taught`. Admin roles add `all`/`gender`/`assigned` scopes
(`role_permissions`, `user_permissions`). New API: `Permissions.CanAsync(caller, action, AccessTarget)` and `ReachAsync` (= `managedReach`: `{all, gender, ids}`) in access.

**Not repeated per operation:** every op writes no `updated_at` unless stated (PHP has no `ON UPDATE CURRENT_TIMESTAMP` on any table these ops write: swept `tools/synthetic-data/schema.sql` and
`migrations/`; the only `ON UPDATE` hits are `syllabus.modified_at`, `notifier_*`, `user_devices`, `class_scheduled_notifications`; the only triggers are `classes_before_create` and
`spot_quizzes_before_insert`, see section (a) item 12). Dates in responses are DB strings (`Y-m-d`, `Y-m-d\TH:i:s` without offset): the new API must emit the same naive form.

## 1. Master table

Handler = `file:line` of the `route_*` function under `api/mobile/routes/`; Rt = router line in `index.php`.

| # | Method path | Handler | Rt | Guard chain (PHP order) | Sz |
|---|---|---|---|---|---|
| 1 | GET `/me/children/{child_token}/classes` | children.php:39 | 59 | AUTH, P(children-performance:read), guardian link 404 | S |
| 2 | GET `/me/children/{child_token}/classes/{class_id}/attendance` | children.php:59 | 60 | same, + enrolled (any row) 404 | M |
| 3 | GET `/me/children/{child_token}/classes/{class_id}/performance` | children.php:88 | 61 | same as 2 | M |
| 4 | GET `/class-levels` | classes.php:159 | 71 | AUTH | S |
| 5 | GET `/classes` | classes.php:178 | 72 | AUTH, P(classes:read) | M |
| 6 | POST `/classes/join` | classes.php:260 | 73 | AUTH, P(classes:join), GI, BODY 422, 404, 403, 403 | M |
| 7 | GET `/join/{code}` | classes.php:101 | 75 | none; IP rate limit 429; 404 | S |
| 8 | POST `/classes` | class_manage.php:608 | 78 | AUTH, BODY, 422 gender, P(classes:create,gender), LOGADM, 422s, 409 | L |
| 9 | GET `/classes/create-options` | class_manage.php:564 | 79 | AUTH, P(classes:create) | S |
| 10 | GET `/classes/teachers` | class_manage.php:577 | 80 | AUTH, P(classes:create,gender) | M |
| 11 | GET `/classes/{class_id}/sessions` | classes.php:337 | 81 | AUTH, GI, GC, P(classes:read,class) | S |
| 12 | GET `/classes/{class_id}/syllabus-topics` | classes.php:376 | 82 | AUTH, GI, GC, P(syllabus:read), P(classes:read,class) | S |
| 13 | GET `/classes/{class_id}/guide` | classes.php:408 | 83 | AUTH, GI, GC, P(classes:read,class) | S |
| 14 | GET `/guides` | guides.php:29 | 86 | AUTH, P(guides:manage) | S |
| 15 | GET `/guides/{level_id}` | guides.php:45 | 87 | AUTH, P(guides:manage), 404 level | S |
| 16 | PUT `/guides/{level_id}` | guides.php:56 | 88 | AUTH, P(guides:manage), 404 level, BODY, 422 x2 | S |
| 17 | GET `/me/guides` | guides.php:96 | 90 | AUTH, P(syllabus:read), student-or-teacher 403 | S |
| 18 | GET `/me/guides/{slug}` | guides.php:112 | 91 | as 17, 404 | S |
| 19 | GET `/classes/{class_id}/my-attendance` | classes.php:433 | 92 | AUTH, P(attendance:read), GI, enrolled-or-teacher 404 | S |
| 20 | GET `/classes/{class_id}/my-performance` | classes.php:477 | 93 | AUTH, P(performance:read), GI, enrolled-or-teacher 404 | M |
| 21 | GET `/classes/{class_id}/conduction` | conduction.php:235 | 104 | AUTH, GC, P(sessions:create,class) | M |
| 22 | GET `/classes/{class_id}/conduction/new` | conduction.php:331 | 105 | AUTH, GC, P(sessions:create,class) | M |
| 23 | GET `/classes/{class_id}/conduction/check` | conduction.php:374 | 106 | AUTH, GC, P(sessions:create,class), 422 | S |
| 24 | POST `/classes/{class_id}/conduction` | conduction.php:445 | 107 | AUTH, GC, P(sessions:create,class), BODY, 422s, 409 | L |
| 25 | GET `/classes/{class_id}/conduction/{session_id}` | conduction.php:398 | 108 | AUTH, GC, P(sessions:update,class), 404 | M |
| 26 | PUT `/classes/{class_id}/conduction/{session_id}` | conduction.php:501 | 109 | AUTH, GC, P(sessions:update,class), 404, 403, BODY, 422s, 409 | M |
| 27 | GET `/classes/{class_id}` | classes.php:223 | 143 | AUTH, active-class 404, P(classes:read,class), reach branch, 400/404 | M |
| 28 | PUT `/classes/{class_id}` | class_manage.php:475 | 147 | AUTH, GC, P(classes:update,class,"...manage this class"), LOGADM, BODY, 422s | L |
| 29 | GET `/classes/{class_id}/manage` | class_manage.php:335 | 148 | AUTH, GC, P(classes:update,class), LOGADM | L |
| 30 | GET `/classes/{class_id}/students` | class_manage.php:279 | 149 | AUTH, GC, P(class-students:read,class) | S |
| 31 | GET `/classes/{class_id}/students/performance` | class_manage.php:303 | 150 | AUTH, GC, P(mcqs:manage,class), 422 | L |
| 32 | GET `/classes/{class_id}/teachers` | class_manage.php:346 | 151 | AUTH, GC, P(classes:update,class) | S |
| 33 | GET `/classes/{class_id}/schedule` | class_manage.php:519 | 152 | AUTH, GC, P(classes:update) or P(classes:schedule) | S |
| 34 | PUT `/classes/{class_id}/schedule` | class_manage.php:532 | 153 | AUTH, GC, same, BODY, 422s | M |
| 35 | POST `/classes/{class_id}/students` | class_manage.php:709 | 154 | AUTH, GC, P(students:enrol,class), 422 x2 | M |
| 36 | POST `/classes/{class_id}/students/bulk` | class_manage.php:740 | 155 | AUTH, GC, P(students:enrol), LOGADM, 429, BODY, 422s, 500 | L |
| 37 | PUT `/classes/{class_id}/students/{token}` | class_manage.php:798 | 156 | AUTH, GC, P(classes:update), 404 student, BODY, 422s | M |
| 38 | POST `/classes/{class_id}/students/{token}/remove` | class_manage.php:831 | 157 | AUTH, GC, P(students:enrol), 404, 422 | S |
| 39 | POST `/classes/{class_id}/students/{token}/restore` | class_manage.php:848 | 158 | AUTH, GC, P(students:enrol), 404 | S |
| 40 | PUT `/classes/{class_id}/students/{token}/class-admin` | class_manage.php:861 | 159 | AUTH, GC, P(class-students:update), 404, 422 | S |
| 41 | POST `/classes/{class_id}/students/{token}/transfer` | class_manage.php:878 | 160 | AUTH, GC, P(students:transfer), 404, BODY, 422s, 404 dest | M |
| 42 | GET `/registrations/{registration_id}/classes` | registrations.php:42 | 210 | AUTH, P(registrations:read x2 probe), 409, P(registrations:read,gender) | M |
| 43 | POST `/registrations/{registration_id}/place` | registrations.php:70 | 211 | as 42, BODY 422, GC, P(students:enrol,class,"...place members in this class"), 422 | M |
| 44 | GET `/syllabus/levels` | syllabus.php:86 | 218 | AUTH, P(syllabus:read) | S |
| 45 | GET `/syllabus/level/{level_id}` | syllabus.php:100 | 219 | AUTH, P(syllabus:read), 404 | S |
| 46 | POST `/classes/{class_id}/deactivate` | deactivated_classes.php:85 | 246 | AUTH, P(deactivated-classes:manage), BODY, model refusals 403/404/409/422 | L |
| 47 | GET `/teachers/{token}` | teachers.php:80 | 276 | AUTH, P(teachers:lookup), `canView` 404 | L |

Catalog note: `operations.csv` lists #17 and #18 (`/me/guides*`) as auth `member`; PHP uses `api_authenticate(true)` (create). All the others agree (`create`, #7 `public`).

Size reasons for L: #8 code/name/link generation, three tables, teacher-pool rule, rate limit; #24 replay, 10 validations, attendance sync, silent drops; #28 non-atomic schedule/topic/tag diff;
#29 payload of 9 reads incl. assessment and transfers; #31 three aggregate reads, two cross-domain; #36 all-or-nothing import writing three domains; #46 six-table transaction plus fan-out; #47 four reads and a visibility rule.

## 2. Per operation

Format: In (inputs and failures in PHP order), Reads/Writes (PHP table to new table; **X-DOM** = other domain), Out (shape), Side (effects).
New-schema names: `classes.*` tables as in `ClassesEntities.cs`. Identity data is split in the new API: `users.token/email/firebase_uid` = identity `users`;
`users.name/mobile/gender/state/city/country/zip` = membership `member_profiles` (keyed by user id, `gender` raw text); `users.roleid` = access. Access
for an `X-DOM users` read below means: token to user id via identity `UserDirectory`, then membership profile.

### 2.1 Children (membership guard, classes data)

**#1 GET `/me/children/{child_token}/classes`**
- In: none. Guard: `isActiveGuardian(me.token, (int)child_token)` else 404 `Child not found` (a non-numeric token is 0, so 404).
- Reads: `class_students cs JOIN classes c LEFT JOIN users tu(c.teacher)` where `cs.token_no = child`, order `c.id`. **No** status, removed or class-status filter (every enrolment ever, one element per row, so a re-enrolled class appears twice).
  X-DOM: `user_guardians` (membership: the guard), teacher name from `users` (membership `member_profiles`).
- Out (**raw**, bare array, `[]` if none): `[{class_id int, class_name str, class_code str, gender int (0 if null), teacher_name str ('' if none), started_on str ('' if null, else Y-m-d), enrolment_status str ('A'|'I')}]`.
- Side: none. Link (`classes.link`) is deliberately not exposed.

**#2 GET `.../classes/{class_id}/attendance?start_date&end_date`**
- In: dates are raw strings, '' = no bound, **not validated** (MariaDB coerces junk; Postgres throws, decide). Guard: guardian link AND `isChildEnrolled` (any `class_students` row, removed or not) else 404 `Child or class not found`.
- Reads: `class_sessions` (+`class_attendance` left join on session and child token) of the class, `conducted = 1`, `conducted_on` bounds inclusive, order `conducted_on desc`. X-DOM: guardian (membership).
- Out (**raw**): `{summary:{total_sessions int, attended_sessions int, attendance_percentage float (round 1, 0.0 when no sessions), total_recitation int}, history:[{date str, duration int (0 if null), present bool, recitation int}]}`.
  `total_sessions` = all conducted sessions in range (not limited to ones after the child joined).
- Side: none.

**#3 GET `.../classes/{class_id}/performance`**
- In/guard as #2. Reads: attendance summary as #2; X-DOM assessment: `spot_quizzes` + `spot_quiz_responses` (`getStudentQuizSummary`): distinct quizzes of the class the child answered, mean of per-quiz percent correct.
  The date bounds there filter `spot_quiz_responses.created_at` (`>= start`, `<= end`): `end_date` as `Y-m-d` means midnight, so the end day's answers are **excluded**.
- Out (**raw**): `{attendance:{total_sessions, attended_sessions, attendance_percentage (round 1), total_recitation}, quizzes:{quizzes_attempted int, quiz_average_score float (round 2 inside, round 1 here)}}`.
- Side: none.

### 2.2 Own classes, levels, join

**#4 GET `/class-levels`**: no permission. Reads `class_levels` order `sort_order, id`. Out `[{id int, code str, name str}]` (no `sort_order`; `/syllabus/levels` has it). S.

**#5 GET `/classes?include=&level=&language=&q=`**
- In: `include=managed` adds `reach = ReachAsync(classes:read)`. `level`/`language` `(int)` when non-empty; `q` is `LIKE %q%` on `code` or `name` (case-insensitive collation; `%`/`_` not escaped). No validation failures.
- Reads: `classes c LEFT JOIN class_students cs (token_no=me, status A, removed_at null) LEFT JOIN class_levels LEFT JOIN users t(teacher)`, `c.status='A'` and (`cs` row or `c.teacher=me` or reach: all / `c.gender=reach.gender` / `c.id in reach.ids`), `DISTINCT`, order conducting first then `c.id desc`.
  Then `class_schedules` (not deleted, order class, day, hour, minute), `listingDetails` (city, country, `class_tags`/`tags` names ordered by name, count of `class_students` with `removed_at is null` regardless of `status`, plus the number of `extra_students` lines
  (`count(explode("\n"))`, blank lines included)). X-DOM: teacher name and mobile (`users` to `member_profiles`).
- Out: array of `{id int, code str, name str, level int (class_level_id), levelName str?, language int?, gender int, status str, location str?, teacherName text?, teacherMobile text?, format str?, startedOn date?, role str?, joinUrl str?}` plus
  `city str?`, `country str?` (**raw**), `tags [str]`, `studentCount int|null` (only when `role='managing'`, i.e. a manager who neither teaches nor attends), `schedules [{day,hour,minute int, timezone str?}]`.
  `role`: `conducting` (teacher = me) / `attending` / `managing` (only distinguished when `include=managed` gave a reach; otherwise always `attending`). `joinUrl`: only for the teacher or someone the reach covers, `public_web_base()/join/<link>`, else null;
  null when `REDIRECT_URI` is unset or `link` is blank. `teacherMobile` is shown to every enrolled student (by design).
- Side: none. M (reach union SQL, three extra reads).

**#6 POST `/classes/join {link}`**
- In (order): P(classes:join); GI; `link = trim(body.link)`, '' gives 422 `link is required`. `getByLink`: `classes INNER JOIN users(teacher)` by `link`, no `deleted_at` and no status in SQL; not found or `status != 'A'` is 404 `Invalid class link or class not active`
  (so a class whose teacher row is missing is "not found"). Gender: `class.gender` not null and != member gender is 403 `This class is not available for your gender`.
- Then `getEnrolmentRow(class, me)` (`select id, removed_at, removed_by ... fetch()`: **an arbitrary first row** when several): 
  - row with `removed_at` null: **200** `{success:false, message:'You are already enrolled in this class', classId, className}`;
  - removed and `removed_by` not null and != me: 403 `You were removed from this class. Please contact the class coordinator.` (`log_event class.rejoin_refused`);
  - else `rejoin`: `UPDATE class_students SET status='A', removed_at=null, removed_reason=null, joined_on=now(), mcq_admin=0 WHERE class_id AND token_no` (**every row** of the pair; `removed_by` is NOT cleared; no search touch) then 200 `Welcome back! You have re-joined the class`;
  - no row: `addStudent(class, me)` (return value ignored; it returns false, writing nothing, when the class `gender` is NULL and the member has gender 1 or 2, because `(int) null` is 0 and differs: the member still gets the 200 success below) = `writeEnrolment`: insert **X-DOM membership `class_registrations`** `(token, for_classid, status 'Accepted')` only if the member has no registration row at all, then `class_students (class_id, token_no, joined_on = now())`, `added_by` null; outbox touch `person:<token>`. 200 `Successfully joined the class!`.
- Out `{success bool, message str, classId int?, className str?}` (cast; `className` not entity-decoded). Always 200 on these three outcomes.
- Side: search outbox (`person`); membership registration row. No lock or unique key, so two concurrent joins can create two rows.

**#7 GET `/join/{code}`** (public)
- In: rate limit `rate_limit_allows('join_preview', 30, 60)` per client IP (file counter under `cache/`; fails open if unwritable): 429 `Too many requests; try again later`. Code must match `^[A-Za-z0-9]{1,32}$`, else 404 `Not Found`.
- Reads: `classes c LEFT JOIN class_levels LEFT JOIN genders` where `link = code AND deleted_at IS NULL`. X-DOM platform `genders.name`; language name comes from the constant `ClassesModel::LANGUAGES` `{1 English, 2 Urdu, 3 Gujarati}` by `language_id` (else '').
- Out (cast): `{name text (a blank name becomes integer 0), level str, language str, gender str, open bool (status 'A')}`. No teacher, counts or ids. `outOfDate` is computed and dropped by the cast.
- Quirk: deactivating a class sets `deleted_at`, so a deactivated class answers 404, never `closed`. Link match is case-insensitive in MariaDB (ci collation).

### 2.3 Creating a class

**#8 POST `/classes`** (201 `{classId}`)
- In, in order: `gender` must be int 1 or 2 (strict; `"1"` fails): 422 `gender must be 1 (gents) or 2 (ladies)`; P(classes:create, [gender], `You do not have permission to create a class`); LOGADM;
  `levelId` int > 0 else 422 `levelId is required` (**never checked against `class_levels`**); `location`, `city`, `country` each string, not blank (422 `<f> is required`), `mb_strlen <= 300` (422 `<f> must be at most 300 characters`), trimmed, in that order;
  `teacher` int > 0 (422 `teacher is required`) and `isTeacherCandidate(teacher, gender)` (422 `teacher is not a member who can be assigned`; pool rule in (a)); `tags` list of ints (422 `tags must be a list of tag ids`);
  `schedules` per **S-rules** below, and at least one (422 `schedules needs at least one weekly slot`); rate limit `class_create` 1 per 60 s keyed by `lower(gender|levelId|location|city|country)`: 409 `This class was just created` (counter is consumed even if the insert later fails).
- **S-rules** (`api_manage_schedules_input`, reused by #28/#34): list of at most 21 else 422 `schedules must be a list of at most 21 entries`; each `{day int 1..7, hour int 0..23, minute int 0..59, timezone string}` else 422
  `each schedule needs a day (1-7), hour (0-23), minute (0-59) and timezone`; `Calcutta` is replaced by `Kolkata`, then the zone must be in the 143-entry static list (`ClassesModel::getTimezones`, 121 distinct zones; includes old names such as `Asia/Rangoon`, `Asia/Chongqing`)
  else 422 `timezone is not one of the supported timezones`; each topic `{id?, topicId int in topics.id (not deleted)}` else 422 `each topic needs a topicId from the topics list`.
- Writes (`ClassesModel::create`, one transaction): `select count(*) from classes where class_level_id and gender` (all statuses, no lock) `+1 = n`; `code = level_code(level, gents) . n`, `name = level_name . n` (code letters from hardcoded arrays, name from `class_levels.name`; an unknown level gives `''.n` and `Unknown`.n);
  `INSERT classes (code, class_level_id, name, gender, location, city, country, teacher, created_by)`; **trigger `classes_before_create` sets `link`** (10 chars, base36 of a random number, left-padded with 0, retried until unique): the C# command must generate it;
  `class_tags` for the tag ids that exist and are not deleted (`ON DUPLICATE KEY` clears `deleted_at/by`); `class_schedules (class_id, day, hour, minute, timezone, created_by)`. After commit: outbox touch `class:<id>`.
  Defaults used: `format 'Offline'`, `status 'A'`, `created_at now()`. `language_id`, `started_on`, `address`, `lat`, `lng` stay null.
- Out: 201 `{classId int}`. Side: search outbox; **no `class_audit_log` row** (only deactivate writes one); no notification.

**#9 GET `/classes/create-options`**
- P(classes:create) with no target (any scope), message `You do not have permission to create a class`. Out `{genders:[int] (each of 1,2 for which can(classes:create,[gender=g])), tags:[{id int, name text}] (tags not deleted, by name), timezones:[{timezone str, label str}]}`.
  `timezones`: the 143 static pairs, first label kept per zone, HTML entities decoded (`api_manage_timezones`). Reads `tags` only. S.

**#10 GET `/classes/teachers?gender=&q=`**
- `gender = (string)$_GET['gender'] === '2' ? 2 : 1`. P(classes:create, [gender]) with the same message. `q` trimmed; empty gives `{"teachers":[]}`.
- Pool (`searchTeachers`): `users u where (u.name LIKE %q% (escaped) or u.token = digits(q))` and (a hard-coded member token constant (holder unverified), `classes.php:1329`, or `u.token in (token_no of any active class_students row, any class))` and, for a gents class, `(that constant or u.gender in ('1','Male'))`; order name; limit 20.
  X-DOM identity+membership: name, token, gender text; scans every member.
- Out `{teachers:[{token int, name text}]}`. M.

### 2.4 Class reads (sessions, syllabus, guide, my-*)

**#11 GET `/classes/{id}/sessions?page&pageSize`**: GI first (400 even for a teacher without gender), then GC (404), then P(classes:read, class). `page = max(1,(int))`, `pageSize = min(100, max(1,(int)))` default 20.
Reads `class_sessions where class_id order by conducted_on desc limit` (**no `deleted_at` filter, `conducted=0` rows included**). Out: **bare array** (no totals) of
`{id int, conductedOn date, conducted bool, duration int?, attendance int?, arabicConducted..otherConducted bool (5), arabicTopic..otherTopic str? (5), nonConductionReason str?}`. Bool rule: `'1','Y','y','true',1` true; `'0','N','',null` false.

**#12 GET `/classes/{id}/syllabus-topics`**: out is the `data/syllabus_topics.json` object for `strtoupper(trim(class level name))`, else `{}` (`(object)` cast). The file holds **only `MIQDAD`**:
`{arabic:{<topic>:[lessons]}, aqaed:{...}, ahkam:{...}}` (2, 7 and 9 topics; lessons are strings like `Lesson 1`). **Data file, not a table.** Reads `class_levels.name` only.

**#13 GET `/classes/{id}/guide`**: slug from `GuidesModel::SLUGS` by `class_level_id` (2 abuzar, 3 miqdad, 4 ammar, 5 bilal); row `guides(level_id, language_id=1)`. Blank or no row or no slug gives 200 `{guide:null, share_url:null, level_name}`.
Else `{guide str (raw, untrimmed), share_url str? (public_web_base()/guide.php?guide=<slug>; null when REDIRECT_URI unset), level_name str?}` (snake_case keys). Level 1 (Salman) has no guide.

**#19 GET `/classes/{id}/my-attendance?start_date&end_date`**: order P(attendance:read) (no target), GI, then `canViewClass` (class active AND (enrolled with `status A`, `removed_at null`, OR `classes.teacher = me`)) else 404 `Class not found or not enrolled`.
Out: **bare array** `[{sessionId int, conductedOn date, present bool, recitation int}]`, conducted sessions only, `conducted_on desc`; sessions with no attendance row show `present=false, recitation=0`. A teacher gets all sessions as absent.
Not filtered by `extra_student`.

**#20 GET `/classes/{id}/my-performance`**: same guards with P(performance:read). Reads attendance summary (`class_sessions` + `class_attendance`, conducted only) and X-DOM assessment quiz summary (as #3).
Out (cast, all floats via `api_cast`): `{totalSessions int, attendedSessions int, attendancePercent float (round 2; 0.0), totalRecitation int, averageRecitation float (total/attended, round 2), quizzesAttempted int, quizAverageScore float (round 2)}`.

### 2.5 Conduction (teacher records)

Common: class from GC; list header `class` = `{id int, code str, name str, level int, levelName str?, gender int, status str, teacherName str?, students:[{token,name,present false,recitation 0,extra false}], extraStudents:[...extra true], totalStudents int}`.
`students` = active roster (`getStudents`); `extraStudents` = `classes.extra_students` split on `\n`, name = text before the first comma, token = running index 1..n (blank lines skipped), so extra-student attendance rows carry index tokens.

**Session spec** (cast): `{id, conductedOn date, conducted bool, duration int?, attendance int?, quranRecitationSurah int?, quranRecitationVerse int?, arabicConducted..otherConducted bool x5, arabicTopic..otherTopic str? x5, nonConductionReason str?, editable bool}`.
`editable` (`SessionsModel::isEditable`): false if `now - created_at` is more than 10 whole days (`DateTime::diff()->days > 10`; created_at read in PHP's default timezone, **unverified**), else true when `created_by = me` or `classes.teacher = me` or "canManage" (passed as **true** by every caller, since the route already passed the permission).

**#21 GET `/classes/{id}/conduction?page&pageSize`**: P(sessions:create, class, `You do not have permission to manage this class`). Same paging clamp. Reads `class_sessions` (`SQL_CALC_FOUND_ROWS`, no `deleted_at` filter). Out `{class, sessions:[spec x n], totalRecords int, totalPages float (PHP `ceil()`, so JSON `3.0`), page int}`.
`isEditable` runs one query per row (N+1). X-DOM: roster names (`users` to member profiles).

**#22 GET `/classes/{id}/conduction/new`**: Out `{class, lastSessionDate str|null, nextSessionDate str|null, futureDate str|null, latestTopics:{arabicTopic..otherTopic str?}, latestSurah int|null, holyQuran:[{id int, surah str, arabic str, verses int}]}`.
- `lastSessionDate` (**raw**): newest `class_sessions.conducted_on` of the class (any session, conducted or not, deleted or not), else `classes.started_on`, else null.
- `nextSessionDate` (**raw**): from `lastSessionDate` (null is replaced by yesterday): the first `class_schedules.day` greater than the last date's ISO weekday (rows ordered by `day`, **including soft-deleted schedules**: `getClassSchedule` has no `deleted_at` filter), else the first schedule's day next week;
  difference <= 0 gets +7. A class with no schedule rows: `$classSchedule[0]['day']` is an undefined index (a warning, not an exception), the arithmetic gives `7 - N` days; the surrounding `catch` never fires. `futureDate` = next date only when `> today` (string compare).
- `latestTopics`: newest non-blank topic per subject among conducted sessions (`conducted_on desc, id desc`), trimmed, null when none. `latestSurah`: newest conducted session with `quran_recitation_surah > 0`.
- X-DOM: `holy_quran` (content domain) ordered by id.

**#23 GET `/classes/{id}/conduction/check?date=`**: `date` blank or `strtotime` false: 422 `date is required and must be a valid date` (accepts words like `tomorrow`). Out `{alreadyConducted bool (a class_sessions row exists for that date, any state), sameWeek bool}`.
`sameWeek` = sessions that Monday..Sunday week `>= max(count(all class_schedules rows incl. deleted), 1)`.

**#24 POST `/classes/{id}/conduction`** (201, or 200 on replay)
- In, order of failure: `conductedOn` string and `strtotime` ok else 422 `conductedOn is required and must be a valid date` (future dates and words allowed); `conducted` (default true; `filter_var` boolean); if not conducted and `nonConductionReason` blank: 422 `nonConductionReason is required when the class was not conducted`.
  If conducted: `duration` int > 0 (422 `duration is required for a conducted class`); at least one present among `students[]` and `extraStudents[]` (422 `At least one student must be marked present`); at least one of the five `*Conducted` flags (422 `At least one subject must be selected`);
  each selected subject needs a non-blank topic (422 `Topic covered is required for Arabic|Aqaed|Ahkam|Akhlaq|Other`). `extraStudents` entries with a blank name are skipped. No length checks: `nonConductionReason` (varchar 100), topics (1000), extra name (100) over-length is a DB error, a 500 (**unverified under strict mode**).
- Replay: `recordedAt` (ISO, optional) is clamped to now and stored as `created_at`; `findReplay(class, date, me, created_at)` returns the existing id (then 200, no write). Else `getSessionByDate` exact duplicate (any session on that date) 409 `A conduction record already exists for this date`.
- Writes (`SessionsModel::add`, **not in a transaction**): `keepClassMembers` silently drops `students[]` whose token never had a `class_students` row in this class (removed members are kept); `attendance` = count of `present === true` among kept students plus present extras;
  `INSERT class_sessions (class_id, teacher = classes.teacher now, conducted_on, conducted = reason? 0 : 1, non_conduction_reason, duration, attendance, quran_recitation_surah/verse, five *_conducted as 0/1 (not Y/N), five topics, created_by = me, created_at = recordedAt or now)`;
  `conducted_by` is never set; one `class_attendance (session_id, token, present, recitation)` per kept student (recitation forced 0 if absent); extras `(session_id, token = client token or 0, name, extra_student 1, present)`. If the second duplicate check inside `add()` finds a row it returns 0, then the route re-runs `findReplay`, else 409 same text.
- Out: the saved session (spec, `editable` true). X-DOM: none written. The `*_conducted` columns hold a mix of `Y/N` (legacy), `0/1` (API) and `''` (web false); readers must accept all.

**#25 GET `/classes/{id}/conduction/{session_id}`**: P(sessions:update, class). `getById`: session missing or `class_id != class` 404 `Session not found`. Out `{class, session:spec, attendance:[{token int, name str, present bool, recitation int, extra bool}], holyQuran:[...]}`.
Attendance = `class_attendance` rows joined to `users` by token (name) unless `extra_student`; the unjoined name falls back to the stored one. X-DOM: member names; `holy_quran`.

**#26 PUT `/classes/{id}/conduction/{session_id}`**: order P(sessions:update); 404 `Session not found`; 403 `Session is not editable`; then the #24 payload rules (422); then `getSessionByDate(..., excluding this id)` 409 `Another session already exists for this date`.
`edit()`: same member filter and count; one transaction: `UPDATE class_sessions SET conducted_on, conducted, reason, duration, attendance, surah, verse, flags, topics, updated_at = now(), updated_by = me` (`teacher`, `created_*`, `conducted_by` unchanged),
`DELETE FROM class_attendance WHERE session_id`, re-insert (new ids, new `created_at`). Out: the session spec.

### 2.6 Reading a class and managing it

**#27 GET `/classes/{id}`**
- In: `teacher = getTeacherToken(id)` (active class only, no joins): null gives 404 `Class not found`. P(classes:read, class). `reach = ReachAsync(classes:read)`. If `teacher != me` and `reaches(reach, classes->get(id))`: `getForManager` (role `conducting|attending|managing`; `joinUrl` whenever `link <> ''`).
  Otherwise gender = (teacher = me) ? none : GI (400); `getForUser`: teacher sees it without a gender gate; others need `c.gender = member gender` AND an active enrolment. No row gives 404 `Class not found`.
  **Bug:** `reaches(array, array)` receives `false` when `get()` fails its INNER JOINs (class with orphan teacher, level or gender), a TypeError and a 500, for a non-teacher caller.
- Out: the #5 class spec (without city, country, tags, studentCount) plus `schedules` (`getSchedules`, ordered day, hour, minute, not deleted). `joinUrl` for a plain student is null.

**#28 PUT `/classes/{id}`**
- In, order: P(classes:update, class, `You do not have permission to manage this class`); LOGADM; BODY; `languageId` null or one of 1,2,3 (422 `languageId is not a known language`); `startedOn` null or exact `Y-m-d` (422 `startedOn must be a date as YYYY-MM-DD`);
  `format` `Online|Offline` (422 `format must be Online or Offline`); `address, city, country, location` null or string `<= 300` (422 `<f> must be at most 300 characters`), blank becomes null; `teacher` int > 0 (422 `teacher is required`) and, only if changed, `isTeacherCandidate(teacher, current gender)`
  (422 `teacher is not a member who can be assigned`); `tags` ints (422 `tags must be a list of tag ids`); `schedules` S-rules (the list is **required**: `null` gives the 21-entries message). `extra_students` is passed back untouched. Level, gender, code, name, link, status are not editable.
- Writes (`ClassesModel::update`): transaction 1: `UPDATE classes SET started_on, language_id, location, format, address, city, country, teacher, extra_students, updated_by = me` (**`updated_at` is not set**), tag diff (add: insert / clear soft-delete; remove: `deleted_at/by` set; unknown tag ids silently dropped); commit; outbox touch `class:<id>`.
  **Then, outside any transaction**: schedule diff against ALL existing rows including soft-deleted (`select * from class_schedules where class_id`): a submitted `id` that matches updates that row in place (a soft-deleted row stays deleted), others insert; schedules not submitted are soft-deleted
  (and their topics), again re-stamping `deleted_at` on rows already deleted; topics diff the same way (`topicId` plus `id`). Entries with a null day/hour/minute/timezone are ignored.
- Out: the manage payload (#29). X-DOM: teacher validity reads identity+membership.
- Side: no `class_audit_log`; no event to notifications although `class_schedules` rows referenced by `class_scheduled_notifications.class_schedule_id` may be soft-deleted.

**#29 GET `/classes/{id}/manage`** (`api_manage_payload`)
- P(classes:update, class), LOGADM. Out:
  `{class:{id int, code str, name text, levelId int, levelName str, gender int, genderName str, languageId int?, startedOn date?, format str, address text?, city text?, country text?, location text?, teacher int, teacherName text?, joinUrl str?},
  tags:[{id,name}], schedules:[{id,day,hour,minute,timezone, topics:[{id,topicId}]}] (rows not deleted, **no ORDER BY**), lookups:{languages:[{id,name}] (constant 1..3), tags, topics:[{id,name}], timezones}, can:{update,enrol,setClassAdmin,transfer bool},
  students:[{token,name,email,mobile,joinedOn date?,notes text?,mcqAdmin bool}], removedStudents:[{token,name,email,mobile,removedAt datetime?,removedReason text?,removedByName text?}], mcqStudents:[{token,name,email,mobile}], transferHistory:[...]|null, destinations:[{id,code,name}]|null}`.
  `can.*` = `can(classes:update|students:enrol|class-students:update, class)`, `can(students:transfer)` (no target). `transferHistory` and `destinations` only when `can.transfer`.
- Reads: roster = `class_students JOIN users` grouped per user: `MAX(mcq_admin)`, `MIN(created_at)` as `joinedOn` (the creation time, **not** `joined_on`), `MAX(notes)`, active and not removed, order name; removed list = member whose latest row (max id) is removed and reason not `Transfer|Promotion|Demotion to class #%`;
  `mcqStudents` = members with a response to a spot quiz of this class who are on neither list (**X-DOM assessment** `spot_quiz_responses`, `spot_quizzes`); transfer history = `student_transfers` joined to `users` (student, transferrer), `classes` (both codes), `transferred_at desc` for the class as source or destination;
  destinations = `getAll()` (all active classes of **both** genders, scoped by `assignedOnlyIds(classes:read)` read from `$_SESSION`) except this one, order gender, level sort, id. X-DOM: `users` names, emails, mobiles (member profiles + identity email).
- Side: LOGADM (`admin_access_log`).

**#30 GET `/classes/{id}/students`**: P(class-students:read, class, `You do not have permission to view this class's students`). Out `{students:[{token,name,email,mobile,joinedOn,notes,mcqAdmin}]}`; `email`, `mobile`, `notes` forced null unless the caller also has `classes:update` on the class.

**#31 GET `/classes/{id}/students/performance?from&to`**
- P(mcqs:manage, class, `You do not have permission to see this class's student figures`). `to` default today, `from` default one year before `to`. Range rules (`reportRangeError`), all 422: not `YYYY-MM-DD` or not a real date `from and to must be dates as YYYY-MM-DD`; `from > to` `from must not be after to`; more than 366 days `The range can cover at most a year`.
- Reads: three aggregates keyed by token: attendance (`class_sessions` conducted in range inner-joined to `class_attendance`, left-joined to `class_students` and `users`; `expected` = sessions the member has an attendance row for), recitation sum, and X-DOM assessment: published quizzes in range (`spot_quizzes.published_at`),
  questions per topic (`spot_quiz_questions`), responses per member and topic (`spot_quiz_responses`). Roster = current students only.
- Out (**raw**): `{from str, to str, totalMcqs int, maxMarks:{total int, topics:[{name str, max int}]} (order Quran, Aqaed, Ahkam, Akhlaq, any other topic after them), students:[{token, name, expected, present, attendance int (rounded percent), mcqAttempted, mcqCorrect, topics:{<topic>:int}, recitation int}]}`.
  `topics` is `[]` (array) when the range has no topics and an object otherwise (PHP empty-array quirk). A member with two enrolment rows is counted per row and the later row wins.

**#32 GET `/classes/{id}/teachers?q=`**: P(classes:update, class, `...manage this class`). Same pool as #10 with the class's own gender. Out `{teachers:[{token,name}]}`.

**#33 GET / #34 PUT `/classes/{id}/schedule`**
- Guard `api_require_class_schedule`: passes if `can(classes:update, class)`, else P(classes:schedule, class, `You do not have permission to set this class's schedule`). 
- GET out `{schedules:[{id,day,hour,minute,timezone}], timezones:[...]}` (schedules from `fetchSchedules`: not deleted, no ORDER BY).
- PUT: BODY, `schedules` S-rules with topics stripped (422s as in #8), then `replaceSchedules` (one transaction, edits by id among the class's live rows, inserts others, soft-deletes unsent rows and their topics; sets `updated_at = current_timestamp`, `updated_by = me`). Out as GET. No search touch, no `classes.updated_by`.

### 2.7 Enrolment

All answer with the **roster payload** `{students, removedStudents, mcqStudents, transferHistory}` as in #29 (`api_manage_roster_for`; `email/mobile/notes` blanked unless `classes:update` is held; `transferHistory` null unless `students:transfer`).

**#35 POST `/classes/{id}/students {token}`**: P(students:enrol, class, `You do not have permission to change this class's students`). `token` int > 0 else 422 `token must be a member's token`. Already active: no-op. Else `addStudent(class, token, addedBy = me)`: needs a `users` row for the token and, if the member's gender is known
(`genderOf`: `1`/`Male` gives 1, `2`/`Female` gives 2, anything else unknown), equal to the class's; refusal 422 `Could not add <token>: not a registered member, or their gender does not match this class.` (one message for both).
Writes: **X-DOM membership `class_registrations`** insert if the member has none; `class_students (class_id, token_no, joined_on=now(), added_by=me)` (a removed member gets a **new** row, not a restore); outbox `person`. X-DOM reads: `users` (existence), member gender.

**#36 POST `/classes/{id}/students/bulk {lines:[str], resolutions:{lineNo: add|enrol|skip}}`**
- In: P(students:enrol); LOGADM; rate limit `class_bulk_add` 10 per 60 s per user id: 429 `Too many bulk adds. Please wait a minute and try again.`; `lines` list (`array_is_list`) of at most 200 (422 `lines must be a list of at most 200 lines`); each a string `<= 300` (422 `each line must be text of at most 300 characters`);
  at least one non-blank (422 `Add at least one student, one per line: a name, then an optional mobile number.`); each resolution one of the three (422 `a resolution must be add, enrol or skip`).
- Rules (`bulkEnrol`): line `"name"` or `"name, mobile"`; name <= 100, mobile `^\+?[0-9 \-]+$` with 7..15 digits (per-line `rejected` reasons `The name is missing.`, `The name is longer than 100 characters.`, `The mobile number is not valid.`); a mobile that matches an existing member
  (last 10 digits, same gender or unknown gender) already in the class: `rejected` `That member is already in this class.`; matched but not in class: flag `mobile_match` (needs `enrol|add|skip`); same normalised name as a current student: flag `duplicate_name` (needs `add|skip`); an unresolved flag returns `status confirm` and writes nothing.
- Writes (all or nothing, one transaction, under named lock `class_bulk_enrol` 10 s): **X-DOM identity+membership**: for each `add`: new `users` row `(token = max(token)+1 running, email '<token>@thestrongrope.com', name, gender = class gender, roleid 0, mobile, createdon now())`; **X-DOM membership** `class_registrations (token, for_classid, status 'Accepted', created_at)`;
  `class_students (class_id, token_no, joined_on now(), status 'A', added_by)`; each `enrol`: `addStudent`. Outbox `person` per member. On failure: 500 `Nothing was added. Please try again.` and event `class.bulk_add_failed`.
- Out (**raw**): `{status 'added'|'confirm'|'none', added int, lines:[{line int, name str, status 'added'|'enrolled'|'rejected'|'duplicate_name'|'mobile_match'|'ready', reason?, member?:{name masked "First L."}}], roster? (only when added > 0)}`.

**#37 PUT `/classes/{id}/students/{token}`**: P(classes:update, class, `...manage this class`); the member must be on the active list else 404 `Student not found in this class`. Fields `name,email,mobile,notes`: each default `''`, must be string `<= 500` else 422 `<f> must be text of at most 500 characters`, trimmed.
`studentEmailError`: a `<digits>@thestrongrope.com` address must carry the member's own token (422 `Email can only be <token>@thestrongrope.com (your token) or a real email address. Cannot use other token emails.`), else must be a valid address (422 `Please provide a valid email address`).
`canChangeEmail`: a different non-blank email is refused unless the member's current email is blank or the placeholder AND `firebase_uid` is empty (422 `This member signs in with their own email; it cannot be changed here.`). Any exception gives 422 `Failed to update student`.
- Writes (transaction): **X-DOM identity/membership**: `users SET name` (if non-blank), `email` (if non-blank), **`mobile` (always, even `''`: an omitted mobile wipes it)**; `class_students.notes` (always, `''` when omitted, for every row of the pair). **No search-outbox touch**. Out: roster payload.

**#38 POST `.../remove {reason}`**: P(students:enrol). Member must be on the active list (404). `reason` trimmed, 1..500 (422 `reason is required and must be at most 500 characters`). `UPDATE class_students SET removed_at=now(), removed_by=me, status='I', removed_reason, mcq_admin=0 WHERE class_id AND token_no` (**all rows of the pair**, overwriting older removal data); outbox `person`.
**#39 POST `.../restore`**: P(students:enrol). Member must be on the removed list (404 `Student is not in the removed list`). `UPDATE ... SET status='A', removed_at=null, removed_by=null, removed_reason=null` for **all rows of the pair** (several rows can come back active; the roster groups by member so it hides it); `joined_on` and `mcq_admin` untouched; outbox `person`. No gender or duplicate check.
**#40 PUT `.../class-admin {status bool}`**: P(class-students:update, class, `You do not have permission to set the MCQ-admin flag`) (taught or all scope only). Active member (404). `status` must be a JSON bool (422 `status must be true or false`). `UPDATE class_students SET mcq_admin` for all rows of the pair. **Access reads this flag** (`IClassScopes.MembershipsAsync` McqFlagged), so it changes that member's permissions.

**#41 POST `.../transfer {toClassId, type?, reason?}`**: P(students:transfer) with **no target** (all scope only). Active member (404). `toClassId` int and != this class (422 `toClassId must be a different class`); `type` in `transfer|promotion|demotion` default `transfer` (422 `type must be transfer, promotion or demotion`);
`reason` trimmed `<= 500` (422 `reason must be at most 500 characters`); destination GC (404 `Class not found` if inactive or missing); gender equal (422 `A student can only move to a class of the same gender`). `transferStudent` (one transaction; exceptions become 422 with the model message such as `Student <t> is already enrolled in destination class #<id>`):
source row `status 'I', removed_at, removed_by = me, removed_reason = '<Type> to class #<id>[: reason]'`; new `class_students (class_id, token_no, joined_on = now())` (no `added_by`, `mcq_admin` and notes not carried); `student_transfers (token_no, from_class_id, to_class_id, type, reason, transferred_by = me)`; outbox `person`.

### 2.8 Registrations (classes acting on membership)

Common guard `api_require_waiting_registrant` (`registrations.php:20`): if the caller can read registrations of neither gender: P(registrations:read, gender 1) (403); `pendingRegistrant(id)`: none gives 409 `This registrant is no longer waiting: they have been placed or rejected.`; then P(registrations:read, gender = registrant's `users.gender` cast with `(int)`).
`pendingRegistrant` (X-DOM membership+identity) = the waiting-list query: `class_registrations` grouped by token with `MAX()` of every column (so `id` is the **highest** registration id of the member), joined to `users`, **excluding** status `Rejected`, members with any active enrolment in an active class, and emails ending `@thestrongrope.com`.
"Placed" is therefore derived, never stored.

**#42 GET `/registrations/{id}/classes`**: after the guard: `classes->getAll(registrant gender)` = active classes of that gender with `students` = count of `class_students` where `removed_at is null` (status ignored, extra students ignored), `assignedOnlyIds(classes:read)` scope, order gender, level sort, id;
filtered to classes where `can(students:enrol, class)`. Out `{classes:[{id int, code str, level str, teacher str? (X-DOM name), location text?, students int}]}`.

**#43 POST `/registrations/{id}/place {classId}`**: guard, then `classId` int > 0 (422 `classId must be a class id`); GC (404); P(students:enrol, class, `You do not have permission to place members in this class`); `addStudent(class, registrant token)` with `addedBy` null (**placement is not attributed**):
refusal (gender mismatch, or `users` missing) 422 `Could not place them: their gender does not match this class.` Writes as #35 (the registration row is **not** updated; status stays as it was). Out `{placed true, registrationId int, classId int}`. Event `registration.placed` logged. No lock between the waiting check and the insert (two admins can place into two classes).

### 2.9 Syllabus, guides (admin-ish) and teachers

**#44 GET `/syllabus/levels`**: P(syllabus:read). Out `[{id int, code str, name str, sort_order int}]` from `class_levels`.
**#45 GET `/syllabus/level/{level_id}`**: P(syllabus:read); `(int)level_id` not in `class_levels` (non-numeric = 0) gives 404 `Level not found`. Out (**raw wrapper**) `{level_id int, level_name str, level_code str, items:[{id int, level_id int, subject_name str, description str?, link_type 'pdf'|'external', url str, sort_order int (null becomes 0), is_active bool, created_at datetime, modified_at datetime?}]}`;
reads `syllabus` where `level_id`, `is_active = 1`, `deleted_at is null`, order `sort_order, subject_name`.

**#14 GET `/guides`**: P(guides:manage) no target. Out `{levels:[{id int, name str}]}` = class levels (by `sort_order`) that have a slug (ids 2..5). **#15 GET `/guides/{level_id}`**: 404 `Level not found` if not 2..5; out `{guide str|null (language 1 row), level_name str}`.
**#16 PUT `/guides/{level_id} {guide}`**: `guide` must be a non-blank string (422 `guide must be the guide text`) of at most 65535 **bytes** (422 `guide is too long to save`). `INSERT guides (level_id, language_id = 1, guide) ON DUPLICATE KEY UPDATE guide` (no `updated_at`/`updated_by`; `created_by` default 0 on a new row); outbox touch `guide:<level>`. Out `{guide}` exactly as sent (untrimmed). The text is HTML stored unsanitised and shown by the public `guide.php` and the app.

**#17 GET `/me/guides`**: P(syllabus:read), then `isStudentOrTeacher` (scopes `enrolled` or `taught` non-empty) else 403 `Guides are for students and teachers` (+ event `permission.refused guides:read`). Out `{guides:[{slug str, name str}]}` for levels 2..5 in level order.
**#18 GET `/me/guides/{slug}`**: same guard; unknown slug, no row or blank text gives 404 `Guide not found`; out `{guide str, share_url str?, level_name str}` (cast).

**#46 POST `/classes/{id}/deactivate {type, effectiveDate, reason}`**
- In: P(deactivated-classes:manage) (route; the model repeats it with `Only administrators can deactivate classes`, unreachable). Non-string fields become `''`. Model refusals, in order: `type` in `completed|shutdown` (422 `Invalid type; expected completed or shutdown`); date exact `Y-m-d` (422 `Invalid effective date; expected YYYY-MM-DD`);
  reason trimmed non-empty (422 `Reason is required`), `strlen` bytes `<= 300` (422 `Reason must be 300 characters or fewer`); class exists (404 `Class #<id> not found`); status `A` (409 `Class #<id> is not active (status=<s>)`). Any other failure: 500 `The class could not be deactivated, and nothing was changed. Please try again.`
- Writes (one transaction): `classes SET status='I', comments = reason, completed_on|shutdown_on = date (the other null), updated_by = admin, updated_at = now(), deleted_by = admin, deleted_at = now()`; every active `class_students` row of the class: `removed_at = now(), removed_by = admin, status = 'I', removed_reason = 'Class deactivated: <reason>'` (cut to 300);
  `class_schedule_topics` and `class_schedules` soft-deleted; `class_audit_log (class_id, action 'deactivated', details JSON {type, effective_date, reason}, performed_by = admin)`; commit, then outbox touch `class:<id>` and `person:<token>` for each removed student. Untouched: `class_tags`, `class_access` grants, quizzes, scheduled notifications.
- Out (**raw**) `{deactivated true, classId int, auditId int}`; event `class.deactivated` logged. Cross-domain effect: access loses the class from every member's scopes (it reads `classes.status`).

**#47 GET `/teachers/{token}`**
- P(teachers:lookup) no target; `canView(me, token)` (else 404 `Teacher not found` + event `teacher.view_refused`): the target's `users.gender` is read with `(int)` (the words `Male`/`Female` give 0): a member without gender 1 or 2 needs scope `all`; else `can(teachers:lookup, gender)`;
  else for a gents member `can(teachers:lookup, teacher_gender = 1)` and the member teaches (a `teachers` row or a `classes.teacher` row). `teacherDetail`: no `users` row gives 404 `Teacher not found`.
- Reads: `users` (token, name, email, mobile, state, city, country, zip) left join `teachers` (five level flags); `classes` taught (any status) with schedules (active only); `teachers_history` joined to `users` for the author name; `class_students` rows of the member (all, with class, level, teacher, remover name) with schedules for live ones.
  X-DOM: identity email; membership name, mobile, state, city, country, zip; names of teachers and removers.
- Out: `{token int, name str, email str?, mobile str?, state str?, city str?, country str?, zip str?, trained bool (a `teachers` row exists), flags:{salman,abuzar,miqdad,ammar,bilal bool}, conducting:[class], conducted:[class], attending:[class], attended:[class], history:[{comments text?, by str?, on date?}]}`.
  `class` = `{id int, code str, level str, city str?, country str?, startedOn date? (falls back to the created date), endedOn date?, comments text?, teacher str?, teacherToken int?, removedBy str?, schedules:[str]}` where a schedule string is `"<English weekday> HH:MM <timezone>"` (`DAYNAME(1970-09-2<day>)`, so day 1 = Monday; zero-padded).
  `conducting` = taught and active, `conducted` = taught and inactive (`endedOn` = completed or shutdown date, `comments`); `attending` = active, not removed; `attended` = inactive class or removed (`endedOn` = completed, shutdown or removal date; `comments` = class comments or removal reason; `removedBy` name).
  The attended/attending query INNER JOINs the class teacher's `users` row: classes with an orphan teacher vanish from the list. Ordering: classes by `status, code`; attending by `status, level sort, code`; history `created_at desc`.

## 3. Closing

### (a) Shared helpers that should become one rule each in `domains/classes/api/domain/`

| # | Rule (suggested name) | Used by | Source and notes |
|---|---|---|---|
| 1 | `ActiveEnrolment` predicate: `status = 'A' AND removed_at IS NULL` (and, for "can see the class", class `status = 'A'`) | 1-3, 5, 6, 19, 20, 27, 29-43, 47, and access/membership ports | PHP repeats it ~25 times and **varies it**: `listingDetails`, `getAll().students`, `getStudentsFromMCQs`, `isChildEnrolled`, #1 (no filter at all), `getEnrolmentStats` ignore `status` or `removed_at`. Keep one named predicate and one named "any row ever" variant |
| 2 | `EnrolmentWriter`: `Enrol` (insert + membership registration side effect + search touch), `Rejoin`, `Remove`, `Restore`, `Transfer`, `SetClassAdmin` | 6, 35, 36, 38-41, 43, 46 | `classstudents.php:156-330, 604-913`. Decide once whether remove/restore/rejoin touch every row of the pair (PHP does) or the latest only; a rule with a test either way |
| 3 | `MemberGender.Of(raw)`: `1`/`Male` is 1, `2`/`Female` is 2, else unknown; plus `GenderGate` ("unknown may join, known must equal") | 6, 35, 36, 42, 43 | `entityaccess.php:279`. `TeachersModel::genderOf` (`(int)` cast, so `Male` is 0) is a second version used by #47; copy both exactly |
| 4 | `ClassNaming`: `Code(level, gents, n)`, `Name(levelName, n)`, `NextSerial` | 8 | `functions.php:195-209`: gents `['', SM, AG, MK, AY, B]`, ladies `['', SL, ABL, ML, AL, BL]` (gents level 5 is `B`, whereas `TeachersModel::LEVELS` says `BL`) |
| 5 | `JoinLink`: generate (10 chars base36, unique), `Url(link)` from the public base, code regex `^[A-Za-z0-9]{1,32}$`, `JOIN_LINK_CUTOVER = 2026-11-07` (only feeds a field the cast drops) | 5, 6, 7, 8, 27, 29 | replaces trigger `classes_before_create`; the old `?c=` redirect rule belongs to the site, not here |
| 6 | `TeacherPool`: `IsCandidate(token, classGender)`, `Search(q, classGender)`; rule "any current student or a hard-coded member token constant (holder unverified); a gents class takes gents only" | 8, 10, 28, 32 | `classes.php:1320-1363` (the constant sits at `1329`, `1356`, `1373`). Needs member names/genders: see (b) |
| 7 | `ScheduleInput` (S-rules) + `TimezoneCatalog` (143 pairs, 121 zones, `Calcutta` to `Kolkata`, label HTML decode, dedupe by zone) | 8, 9, 28, 33, 34 | `class_manage.php:364-403`, `classes.php:1147-1296`. Ship the list as data, not as `TimeZoneInfo` lookups (it holds retired names) |
| 8 | `ScheduleDiff.Apply` (edit by id, insert, soft-delete the rest and their topics, topics likewise); one version, in one transaction, that ignores already-deleted rows | 28, 34 | PHP has two diverging copies (`update()` re-stamps deleted rows and runs after commit; `replaceSchedules` is clean). Pick `replaceSchedules` semantics for both and record it |
| 9 | `ClassVisibility`: `CanViewClass(class, token)`, `GetForUser`, `GetForManager`, reach test `Reaches(reach, class)` | 5, 19, 20, 27 | `classes.php:758, 795-1005`; `ReachAsync` from access |
| 10 | `ClassLookup.Active(id)` = GC semantics (inner joins or not, a conscious choice) | all `{class_id}` routes | see quirk Q1; one function so the decision is made once |
| 11 | `DateRange`: parse `start_date`/`end_date` (decide: lenient = ignore bad, or 422), `ReportRange` (`from/to`, <= 366 days, 3 messages) | 2, 3, 19, 20, 31 | `classstudents.php:1038, 1421`. PHP passes raw strings; Postgres needs a decision |
| 12 | `AttendanceSummary` (`totalSessions`, `attendedSessions`, `totalRecitation`) and `AttendanceHistory`, with the per-caller rounding (2 decimals for `my-*`, 1 for `child-*`) | 2, 3, 19, 20 | `classstudents.php:955-1035`; quiz summary comes from assessment |
| 13 | `SessionFlags`: read `Y y 1 true` as true (`N 0 ''` false); write one canonical form | 11, 21, 24-26 | column is `char(1)` with defaults `N`/`Y` (aqaed default `Y`); PHP writes `0/1`; legacy rows `Y/N` |
| 14 | `ConductionRules`: payload validation (10 messages, order fixed), `Editable` (10-day window, creator/teacher/manager), `Replay` by `(class, date, creator, created_at)` with `recordedAt` clamp, `SameWeek`, `NextSessionDate`, `LatestTopics`, extra-student parsing | 21-26 | `conduction.php:94-224`, `sessions.php` |
| 15 | `Roster`: current students (grouped per member), removed list (latest row removed, not a transfer), `MCQ candidates`, contact blanking | 21, 22, 29, 30, 35-41 | `classstudents.php:34, 1145`; needs member profiles |
| 16 | `Paging.Clamp(page, pageSize)` (`page >= 1`, `1 <= size <= 100`, default 20) | 11, 21 | |
| 17 | `ClassDeactivation` (one transaction, 6 tables, 5 refusals) and `ClassAudit.Write` | 46 | `classes.php:1727` |
| 18 | Constants as data: `Languages {1 English, 2 Urdu, 3 Gujarati}`; `GuideSlugs {2 abuzar, 3 miqdad, 4 ammar, 5 bilal}`; `SyllabusTopics` (the JSON file, MIQDAD only, keyed by uppercase level name); `TeacherLevels {salman SM, abuzar AG, miqdad MK, ammar AY, bilal BL}` | 7, 13, 17, 18, 12, 29, 47 | PHP's `languages` table (3 rows, soft delete) duplicates the constant: pick one source |
| 19 | `WireCast` helpers for classes (PHP `api_cast` zero-values: blank `text` becomes `0`, `str?` blank becomes null, bool spellings, `float` always `x.0`) | all | reuse membership's `PhpText`/`PhpValue` (`domains/membership/api/domain/`) rather than a second copy |
| 20 | `SearchTouch`: queue `class:<id>`, `person:<token>`, `guide:<level>` into the outbox | 6, 8, 28, 35-41, 43, 46, 16 | PHP touches after commit and swallows failures (`searchoutbox.php:32`); events in (c) replace it |

Trigger and `ON UPDATE` sweep (task item 6): PHP's `classes_before_create` is the only trigger on a table these operations write (the other is `spot_quizzes_before_insert`, assessment). No `ON UPDATE CURRENT_TIMESTAMP` on `users`,
`class_registrations`, `class_students`, `class_sessions`, `class_attendance`, `student_transfers`, `class_schedules`, `class_schedule_topics`, `class_tags`, `classes`, `guides`, `class_audit_log`, `admin_access_log`: so **commands must set** `updated_at` only where PHP did
(`class_sessions` edit, `class_schedules`/`class_schedule_topics` edit, `classes.updated_at` on deactivate; `deleted_at` stamps everywhere) and PHP leaves `classes.updated_at` and `guides.updated_at` null on PUT. `syllabus.modified_at` has `ON UPDATE` (admin ops, not here; the C# command must set it).
`created_at` defaults exist on all (`now()`); `class_sessions.created_at` is client-supplied on create (`recordedAt`).

### (b) Cross-domain reads and writes, by owner (the main risk)

New-API reality: `users` is split. Identity keeps `token`, `email`, `firebase_uid`; membership `member_profiles` (keyed by **user id**) keeps `name`, `mobile`, `gender` (raw text), `state`, `city`, `country`, `zip`; access keeps the role. Every PHP `JOIN users` below therefore needs a **batch read by member token**
returning name, mobile, gender (and email where noted). Neither identity's `UserDirectory.ByTokensAsync` nor membership's `MemberNames.ByUserIdsAsync` (by user id, name only) offers that yet: a new public interface is needed (name+mobile+gender by token, bounded batch).

**WRITES to other domains** (each must become a command on the owner, or an event):

| Owner | Write | Ops | Notes |
|---|---|---|---|
| identity + membership | **create a member**: `users (token = max+1, email '<token>@thestrongrope.com', roleid 0, createdon)` + profile `(name, gender = class gender, mobile)` | 36 | PHP: `MAX(token)+1` under `GET_LOCK('class_bulk_enrol')`. identity already has token allocation (`MemberDirectory`, advisory lock 7100001); it must expose "create placeholder member" |
| identity + membership | **edit a member**: `users.email`; profile `name`, `mobile` (mobile always overwritten, even `''`) | 37 | no search touch in PHP; email rule needs `firebase_uid` empty (identity) |
| membership | insert `class_registrations (token, for_classid, status 'Accepted')` when the member has **no** row | 6, 35, 36, 43 | ported table has `Status` CHECK `Pending|Accepted|Rejected`, `class_level` CHECK; a 3-column insert satisfies it (`ClassLevel` null). Must be a membership command (it also must keep "duplicates per token, update changes every row" semantics) |
| platform | `admin_access_log` insert | 8, 28, 29, 36 | `LOGADM`; only role ids 1,3,4,5,7; path, ip, user agent, referer |
| platform | outbox rows for search (`class`, `person`, `guide`) | see (a)20 | |
| platform | rate-limit counters (file cache in PHP): `join_preview` 30/60 s per IP, `class_create` 1/60 s per class signature, `class_bulk_add` 10/60 s per user | 7, 8, 36 | `shared/api` `MemberRateLimit` exists for member keys; #7 is **per IP**, unauthenticated |

**READS from other domains:**

| Owner | What | Ops |
|---|---|---|
| membership `member_profiles` (+ identity token map) | teacher name and mobile (5, 27, 29, 42, 21/22/25 header, 1) ; student name, email (identity), mobile, gender (21, 22, 25, 29, 30, 31, 35-37, 43, 47); teacher pool names and gender text (8, 10, 28, 32); removed-by and transferred-by names (29, 47); teacher contact block (47: name, mobile, state, city, country, zip); mobile match on all members (36) | 1, 5, 8, 10, 21-22, 25, 27, 29-32, 35-37, 42, 43, 47 |
| membership `class_registrations` | the waiting list: grouped by token with `MAX()` over every column, status != `Rejected`, no active enrolment in an active class, email not `@thestrongrope.com`; the registrant's gender | 42, 43 |
| membership `user_guardians` | active link `(parent_token = me, child_token, status 'active')` | 1, 2, 3 |
| access | `CanAsync`/`ReachAsync` for: classes:read, classes:join, classes:create, classes:update, classes:schedule, class-students:read/update, students:enrol, students:transfer, sessions:create/update, attendance:read, performance:read, mcqs:manage, syllabus:read, guides:manage, registrations:read/reject, teachers:lookup, children-performance:read, deactivated-classes:manage; `assignedOnlyIds` (#29, #42), `isStudentOrTeacher` (#17-18), scopes (#47) | all |
| assessment | `spot_quizzes`, `spot_quiz_responses`, `spot_quiz_questions`: attempted-quiz count and mean percent (3, 20), MCQ candidates for the roster (29), per-member per-topic correctness and max marks (31) | 3, 20, 29, 31 |
| content | `holy_quran` (id, surah, arabic, verses) | 22, 25 |
| platform | `genders.name` (#7, #29 `genderName`); `languages` (the constant duplicates it) | 7, 29 |

**Reverse dependencies (others read classes data)** the new slices must keep intact through the ports: access via `IClassScopes` (`classes.teacher`, `class_students.mcq_admin/status/removed_at`, `classes.status/gender/city/country/level/tags`);
membership via `IClassEnrolments.IsEnrolledAsync` (a gender lock) and "placed" being derived from `class_students` (the waiting list is a **membership** query that reads classes' enrolment table, so membership needs the same enrolment predicate); notifications via `class_schedules.id` (`class_scheduled_notifications.class_schedule_id`);
search via the outbox kinds above. Ops 8, 28, 34, 38-41, 46 change what those ports answer.

### (c) State changes that deserve an event

| Event (past tense) | Entity id | Changed fields / payload | From ops | Consumers |
|---|---|---|---|---|
| `ClassCreated` | classId | code, name, levelId, gender, teacher, city, country, link | 8 | search, access (rules), notifications |
| `ClassDetailsChanged` | classId | changed subset of teacher, languageId, startedOn, location, format, address, city, country, tags added/removed | 28 | search, access (teacher scope, city/country/tag rules) |
| `ClassScheduleChanged` | classId | scheduleIds added / edited / removed | 28, 34, 46 | notifications (class-relative reminders) |
| `ClassDeactivated` | classId | type, effectiveDate, reason, auditId, removed tokens | 46 | search, access, notifications (scheduled sends), membership (waiting list) |
| `StudentEnrolled` | classId, token | via (`join`/`add`/`bulk`/`place`/`transfer`/`rejoin`/`restore`), addedBy | 6, 35, 36, 41, 43, 39 | search, membership, access, notifications |
| `StudentRemoved` | classId, token | reason, removedBy, via (`remove`/`transfer`/`deactivate`) | 38, 41, 46 | same |
| `StudentTransferred` | token, fromClassId, toClassId | type, reason, by | 41 | search |
| `ClassAdminFlagChanged` | classId, token | mcqAdmin (access scope `own` changes) | 40 (also cleared by 38, rejoin) | access |
| `ClassStudentEdited` | classId, token | which of name, email, mobile, notes | 37 | search, identity/membership (their own commands) |
| `MemberPlaceholderCreated` | token | classId, name, mobile | 36 | search, membership |
| `ConductionRecorded` / `ConductionEdited` | sessionId, classId | conductedOn, conducted, attendance count, editedBy | 24, 26 | reports, search (none today) |
| `GuideSaved` | levelId, languageId | length | 16 | search (`guide`) |
| `RegistrationPlaced` | registrationId, token | classId | 43 | membership (waiting list), notifications (none today) |

### (d) Quirks and suspected PHP bugs (copy, do not fix, unless noted)

1. **GC is stricter than "active"**: `ClassesModel::get()` INNER JOINs `genders`, `class_levels`, `users`(teacher), so an active class with a null/orphan gender, level or teacher is a 404 `Class not found` on every `{class_id}` route, yet still appears in #5, #6, #7 and the teacher's own lists (those LEFT JOIN). Count of such rows **unverified** (no database).
2. **#27 500**: `reaches($reach, false)` TypeError when `get()` fails its inner joins (quirk 1; non-teacher caller).
3. **#6 join ignores `addStudent`'s result** (a NULL-gender active class: nothing written, yet 200 `Successfully joined the class!`; whether any exist is in (e)); "already enrolled" is a 200 with `success:false`; `rejoin` updates every row of the pair, keeps `removed_by`, skips the search touch; `getEnrolmentRow` returns an arbitrary row among several.
4. **Whole-pair updates** (remove #38, restore #39, class-admin #40, rejoin #6): each rewrites all rows for `(class, token)`; restore can leave several active rows; remove overwrites older removal metadata. `addStudent` after a removal inserts a new row instead of restoring (only `enrolByToken`, used by an admin route outside this scope, restores).
5. **No uniqueness or lock on enrolment** (`class_students` has no unique key): double-click or two admins create duplicates. `getStudents` hides them with `GROUP BY`; `students/performance` double counts per row (later row wins).
6. **`joinedOn`** is `MIN(created_at)`, not `joined_on`; `rejoin`/`restore` change `joined_on` which nothing displays.
7. **#8**: `levelId` unchecked (a class with an unknown level is created, named `Unknown<n>`, then 404s by quirk 1); code/name numbering `count(*)+1` over all statuses, racy and not unique-indexed; the rate limit is consumed by failed creates; no audit row although the CHECK allows `created`/`updated`.
8. **#28 not atomic and re-stamping**: schedules and topics are written after the commit; the diff includes soft-deleted rows (a submitted deleted id is "edited" yet stays deleted; every unsent row, deleted or not, is soft-deleted again with a fresh `deleted_at`); `classes.updated_at` never set.
9. **#37 wipes mobile** when the field is omitted (`''` is `isset`); `notes` too; no search touch after changing name/mobile/email; email checks run twice.
10. **#24/#26**: attendance of tokens outside the class is dropped silently (the "someone present" check ran before the drop, so a session can be saved with attendance 0); no length limits (500s); `conducted_by` never set; `teacher` is the current class teacher, not the recorder; PUT deletes and re-inserts all attendance rows (ids and `created_at` reset);
    `isEditable` is evaluated with "canManage = true" always; the 403 for non-editable precedes payload validation; `quranRecitation*` and `duration` are stored for non-conducted sessions if sent; `*_conducted` Y/N vs 0/1 mix; `class_sessions` has `deleted_at` but no query filters it.
11. **#22**: `nextSessionDate` counts soft-deleted schedules; with no schedules it still returns a date (the `catch` never fires); `lastSessionDate` includes non-conducted sessions; compare is string based.
12. **#21**: `totalPages` is a float (`3.0` under `PRESERVE_ZERO_FRACTION`); N+1 `isEditable`; `editable` is true for anyone passing `sessions:create`.
13. **#11** returns a bare array without totals, uses `classes:read` (not `sessions:read`), checks GI before class existence (400 before 404, even for the class's own teacher).
14. **#5**: `studentCount` only for pure managers (null for teachers/attendees who also manage); `extra_students` lines counted with `count(explode("\n"))` here but `count(explode(PHP_EOL)) - 1` in `ClassesModel::get()` (`total_students`): off by one between the two; teacher mobile exposed to every enrolled student.
15. **#7**: deactivated classes answer 404 (they carry `deleted_at`); blank class name becomes integer `0` through the `text` cast; link lookup is case-insensitive in MariaDB; per-IP limit uses `client_ip()` behind trusted proxies.
16. **#3/#20/#2** date semantics: `end_date` is inclusive for sessions (`conducted_on <= d`) but exclusive of the end day for quiz responses (`created_at <= 'd'` is midnight); attendance percent counts every conducted session including ones before the member joined; rounding is 2 decimals (my-*) vs 1 (child-*, after an inner round of 2).
17. **#1**: lists every enrolment row (no status/removed/class-status filter), duplicates per re-enrolment; `started_on` `''` when null; response is raw snake_case.
18. **#16** guide text is unsanitised HTML written by `guides:manage` holders, served to members and the public page (stored XSS surface if a future client renders it as HTML); no `updated_by`; only language 1; slug map is hard-coded (levels 2..5), so Salman (1) can never have a guide.
19. **#12** reads a repo data file, MIQDAD only, matched by uppercase level **name**: renaming a level silently empties it.
20. **#43** placement is not recorded (no `added_by`, registration row untouched); the 409 check and the insert are not locked; `rejectRegistration` (outside scope) writes `users.id` into `modified_by` where the rest of the table uses tokens.
21. **#31** `topics` is `[]` when empty but an object otherwise; `maxMarks` includes quizzes outside the roster; response not cast (field order by PHP insertion order).
22. **#10/#32** teacher pool is "any member who is a current student of any class" plus a hard-coded member token constant (holder unverified); `LIKE` is accent-insensitive in MariaDB (`utf8mb4_unicode_520_ci`); Postgres `citext` is case-only, so matches differ for accented names (decide, and test).
23. **Permission quirks**: `#37` needs `classes:update` although the neighbours need `students:enrol`; `#41` checks `students:transfer` with no target, before it knows the class gender; `#33/#34` accept `classes:update` OR `classes:schedule`; `#17/#18` also require being a student or teacher on top of `syllabus:read` (which all members hold).
24. **Router**: ids are cast with `(int)` (`/classes/5abc` is class 5); `api_cast` zero-values differ by type (see membership recon).
25. **Whole-request side effects of AUTH** (login tracking, claim sync) occur on every op and are identity's; #7 is the only op without them.

### (e) Not determined

- Production values and counts: classes whose gender, level or teacher row is missing (quirk 1); duplicate enrolment rows; mix of `Y/N`/`0/1` in `*_conducted`; whether `genders.name` is `Gents`/`Ladies` (affects #7 `gender`); `REDIRECT_URI` per environment (sets `joinUrl`/`share_url` host).
- PHP default timezone (`date_default_timezone_get()`): decides how `isEditable` and `recordedAt` read naive `created_at`. **Unverified**; check `php.ini`/container config, not DB.
- MariaDB `sql_mode` in production (strict or not): decides whether over-length text (`non_conduction_reason` 100, topics 1000, extra-student name 100, `guides.guide` 65535) is a 500 or a silent truncation.
- Whether `class_access` is a table or the view in production (affects `assignedOnlyIds`); `withdrawn.list` migration state. Not read by any op here directly (access's concern).
- Behaviour of `class_scheduled_notifications` for a deactivated class (the worker was not read): whether a stale schedule id breaks a fire.
- Which of the three `NoEnrolments`/`NoClasses` defaults the gateway wiring still uses at the time of the build (`IClassScopes`, `IClassEnrolments` are declared, not yet supplied by classes: `domains/classes/CLAUDE.md`).
- The body of `web/guide.php` (public renderer of #13/#18 `share_url`): not read.
- `class_students.notes` is `text`; length limits (500) are API-side only.
- Production count of active classes with a NULL gender (quirk 3 of (d), #6).
