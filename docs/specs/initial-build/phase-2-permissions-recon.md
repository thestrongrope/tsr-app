# Phase 2 recon: the PHP API's authorization, as built

Read-only recon of `tsr-account` at branch `develop` (commit ed72cd98). Paths are repo-relative to tsr-account;
`file:line` is as of `develop`. Facts only, no design. No database, container, `.env` or member data was touched.
Companion file: `permission-map.csv` (one row per operation).

Counts: **211 operations over 191 paths** (`web/api-docs.json`, and the 211 route rows of `web/api/mobile/index.php:21-293`),
**211 CSV rows, 5 rows carry an `unknown` cell** (row_filtering of five `children.php` routes, whose model SQL I did not read line by line).
**102 permission names** in 40 resources. **6 role ids used** (0,1,3,4,5,7) plus 6 defined but unused.

## 1. Roles

| id | name | where defined | held by |
|---|---|---|---|
| 0 | member / USER | default `users.roleid`; `routes/permissions.php:15-25` (name map) | everyone else |
| 1 | ROLE_ADMIN (super admin) | `web/functions.php:24` | yes |
| 2 | none | no constant, no seed | n/a |
| 3 | ROLE_GENTS_ADMIN | `functions.php:25` | **nobody** (`docs/dev/domain.md:18`, `docs/mobile/web-vs-mobile-parity.md:227`) |
| 4 | ROLE_LADIES_ADMIN | `functions.php:26` | yes |
| 5 | ROLE_CLASS_ADMIN (class coordinator) | `functions.php:29` | yes; set automatically (see below) |
| 6 | ROLE_CLASS_TEACHER | `functions.php:36` (name map only) | **nobody**; teacher-ness is `classes.teacher == token`, never roleid (`functions.php:30-35`, `domain.md:14`) |
| 7 | ROLE_FINANCE | `functions.php:37` | yes |

- Role display names also in `web/models/auditlog.php:43-51`; a legacy page catalog per role in `web/api/mobile/permissions/pages.json` (serves `GET /user/permissions` only, `routes/permissions.php:41-146`).
- Role 5 is assigned and removed by code: `ClassAccessModel::writeGrant` sets 0 -> 5 on a member's first rule (`models/classaccess.php:790-793`); last rule revoked returns 5 -> 0 (`:333`, `:824`); a higher role is left alone; Finance (7) is refused (`:749`). `migrations/2026_09_28_remove_unruled_class_admins.sql` reset three role-5 members to 0.
- "Roles held by nobody": 3 and 6, per the docs (live-data claim, not verifiable from code).

## 2. Permission names

- Scheme: `resource:action:scope` (`models/permissions.php:9`). Scopes (7): `self` 15, `enrolled` 3, `own` 8, `taught` 2, `assigned` 13, `gender` 18, `all` 43.
- Catalog = table `permissions(name, description)`, a living list grown by migrations (`migrations/2026_09_27_permissions.sql:25-29,51-137`, plus 7 later migrations: `2026_10_19_class_schedule_own_permission`, `2026_10_19_permissions_manage_all`, `2026_10_22_quiz_reset_permission`, `2026_11_03_class_access_manage_permissions`, `2026_11_05_parent_link_permissions`, `2026_11_06_members_enrol_by_token_permission`, `2026_11_09_feedback_permissions`). Counts per resource: classes 12, parents 11, sessions 9, registrations 7, notifications 6, teachers 5, mcqs 5, students 4, class-students 4, reports 3, others 1-2 each (40 resources).
- **Role to permission**: table `role_permissions(roleid, permission)` (`:31-36`), seeded by pattern at migration time, not by a live rule:

| role | gets | source |
|---|---|---|
| 1 | every `%:all` that existed at seed time except `quiz-competition`, `syllabus:read`, `content:read`, `quiz:admin` (`:139-146`); later added explicitly: `permissions:manage:all` (`2026_10_19_permissions_manage_all.sql:19`), `class-access:manage:all` (`2026_11_04_class_access_manage_role_grants.sql`), `parents:add/add-direct/manage:all` (`2026_11_05_parent_link_permissions.sql`), `members:enrol-by-token:all` (`2026_11_07_...`), `feedback:review:all` (`2026_11_09_feedback_permissions.sql`). NOT given: `quiz:admin:all`, `quiz:reset:all` (held by nobody until granted; `docs/mobile/release-handover.md:407`) | |
| 3, 4 | every `%:gender` at seed time (14 names, `:148-152`) + `class-access:manage:gender`, `parents:add/add-direct/manage:gender` | `2026_11_04...`, `2026_11_05...` |
| 5 | every `%:assigned` at seed (11, `:154-156`) + `parents:add:assigned`, `parents:add-direct:assigned` | |
| 7 | `donors:read:all` only (`:158-159`) | |
| 0, 6 | nothing from the table | |

- **Not in the tables, hard-coded in PHP**: MEMBER set, 21 names, held by every user with token > 0 (`permissions.php:31-39`); OWN set, 8 names (`:42-46`), held while the user teaches an active class or holds a live `mcq_admin` flag on one; TAUGHT set, 2 names (`:49`), held while teaching an active class. Each is intersected with the `permissions` table (`:408`), so a name missing from the table is dropped.
- **Individual grants**: table `user_permissions(id, user_id=users.id, permission, granted_by, granted_at, reason, revoked_at, revoked_by, revoke_reason)` (`2026_09_27_permissions.sql:38-49`, `2026_10_19_permission_grants_columns.sql:19-22`). Held while `revoked_at is null` (`permissions.php:394-399`). Made by migration (any name; `docs/dev/domain.md:59-84`) or in-app by `permissions:manage:all` holders (super admin only): `PermissionGrantsModel::grant` (`models/permissiongrants.php:135-180`), which offers only `:all`-scope names the member does not already hold, minus `NOT_GRANTABLE` = `permissions:manage:all`, `class-access:manage:all`, `members:enrol-by-token:all` (`:38,114-116`). Reason required (<=300 chars); revoke by grant id.
- **Grants do not carry a scope.** The scope is part of the permission name; `class`, `gender`, `city`, `level`, `country` are never stored on a grant. Scoped data lives elsewhere: class coordinator reach is `class_access_rules` (below); gender admin reach is the role id (`permissions.php:353`).
- Named-member grants seeded at creation: `standard-mcqs:update:all` (2 members), `summary-report:read:all` (1), `api-docs:read:all` (1) (`2026_09_27_permissions.sql:161-169`), another `standard-mcqs:update:all` in `2026_10_09_grant_standard_mcqs_update.sql`. `quiz:admin:all` is "a plain user_permissions grant" (`permissions.php:14`); the old `state/quiz_superusers.json` is still referenced in the seed comment (`:136`).
- Names with no route using them (web-only): e.g. `sessions:read:enrolled`, `class-requests:create:self`, `content:read:all`, `quiz-competition:take:all`, `spot-quizzes:manage:all`, `summary-report:read:all`, `api-docs:read:all`. (`notifications:send` is used by the class send route only; `notifications:broadcast:all` by the four `/notifications/*` admin routes.)

## 3. `can()` exactly

Entry points in `web/models/permissions.php` (class `PermissionsModel`):

| method | signature | returns / adds |
|---|---|---|
| `can` | `can(int $userId, string $action, array $target = []): bool` (`:78`) | allow/deny. `$action` is `resource:action` (no scope). Unknown action throws `InvalidArgumentException` (`:417-425`). Any `PDOException` -> deny + log (`:83-86`) |
| `verify` | `verify($userId,$action,$target)` (`:95`) | web guard: refusal logs `permission.refused`, 404, die |
| `forUser` | `forUser(int $userId)` (`:61`) | `{permissions[], scopes{gender,assigned,assigned_genders,own,taught,enrolled}}` for `GET /me/permissions` |
| `scopesOf` | (`:110`) | scope suffixes held for an action |
| `managedReach` | (`:124`) | `{all, gender, ids}` from scopes `all`,`gender`,`assigned` only |
| `searchReach` | (`:147`) | `{all, gender, classIds(assigned+own+taught+enrolled), self(token)}` |
| `genderLock` | (`:184`) | gender a page is pinned to, or null: not `all`; `gender` scope -> that gender; only `assigned` over classes of exactly one gender -> that gender |
| `assignedOnlyIds` | (`:208`) | class ids when the user's ONLY reach is `assigned`, else null |
| `reaches` | `reaches(array $reach, array $class)` (`:216`) | does a managedReach cover a class row |

`$target` shapes (`:73-76`): `[]` anywhere; `['class'=>id]`; `['gender'=>g]`; `['teacher_gender'=>g]`.

`can()` algorithm (`:240-281`, resolution `:329-415`):
1. `assertKnown`: some catalog name has this `resource:action` (`:417`); else throw.
2. Resolve the user once per request, cached by id (`:331`): load `id, token, roleid` (`:344`). No row or **token 0 (guest)** -> empty set, deny everything (`:348-350`).
3. Scopes are resolved from data each time: `gender` = `[ROLE_GENTS_ADMIN=>1, ROLE_LADIES_ADMIN=>2][roleid]`, else null (`:353,377`); `taught` = ids of `classes` where `teacher = token and status='A'` (`:354`); `own` = taught plus classes where the user has `class_students.mcq_admin = 1 and removed_at is null` on an active class (`:358-366`); `assigned` + `assigned_genders` = active classes in `class_access` (a view over rules, section 4) where `removed_at is null` (`:367-375`); `enrolled` = active classes with `class_students.status='A' and removed_at is null` (`:384-391`).
4. Permission names held = MEMBER constant + union of `role_permissions` for roleid and live `user_permissions` (`:394-400`) + OWN if `own` non-empty + TAUGHT if `taught` non-empty (`:401-406`), intersected with the catalog (`:408`).
5. The names for this action are reduced to their scope suffixes (`heldScopes` `:223`). **None held -> deny** (`:245`).
6. **Empty target -> allow** (`:248`): holding the action at any scope is enough ("anywhere").
7. Target `class`: the class must exist **and be active** (`status='A'`) else deny (`:253-256,436`, even for scope `all`); then allow if ANY held scope matches (`classInScope` `:283-299`): `all` true; `gender` class.gender == user's gender; `assigned|own|taught|enrolled` class id in that resolved list; any other scope (`self`) false.
8. Target `gender` or `teacher_gender`: allow if any held scope's genders contain it (`:265-278`; `scopeGenders` `:302-315`): `all` -> {1,2}; `gender` -> {own gender}; `assigned` -> `assigned_genders` (the genders of every active assigned class); `own/taught/enrolled/self` -> {} (deny). For `teacher_gender` the set is widened by the teacher rule: if it contains 2 -> {1,2}, elif 1 -> {1} (`:321-327`).
9. Any other target keys -> deny (`:280`).
- There is no admin override or guest branch beyond roles via `role_permissions` (super admin is just role 1 rows); the sole "guest" rule is step 2.
- Quirk noted in code: for scope `assigned`, a `gender` target answers true for every gender the user has any assigned class in, so callers needing "this student's classes" use `managedReach` + per-class `can` instead (`models/guardians.php:586-606`).

Other deciders:

| entry | file:line | adds |
|---|---|---|
| `api_require($action,$target,$detail)` | `web/api/mobile/lib/response.php:232-240` | `can()` for `$_SESSION['user']['id']`; refusal -> log `permission.refused` + 403 `{detail}`; never allows by default |
| `api_verify($bool,...)` | `response.php:190` | wraps a model predicate (e.g. `canViewClass`) -> 403/404 |
| `api_find_class` | `response.php:247` | active class else 404, before the permission check |
| `api_require_identity` | `routes/classes.php:124-138` | 400 "User gender not set" if profile gender missing |
| `api_verify_enrolled` / `ClassesModel::canViewClass` | `classes.php:148`, `models/classes.php:758` | enrolled (A, not removed) OR teacher, class active, else 404 |
| `EntityAccessModel` | `models/entityaccess.php:28-138` | student card via `managedReach(classes:read)` filtered per class; subscriber card only when reach is `all` and person is not enrolled; `memberDetails` needs `members:enrol-by-token`; `genderOf` (`:279`) |
| `ClassAccessModel` | `models/classaccess.php:36,700-708,845-860` | operator may manage member/rule gender via `can('class-access:manage',['gender'=>g])`; rule gender null needs both genders; cannot edit own access (`:685-693`); `fromRole` text via `managedReach(classes:read)` (`:872`) |
| `PermissionGrantsModel` | `models/permissiongrants.php` | grant list = unheld `:all` names minus NOT_GRANTABLE |
| `GuardiansModel::staffMayAddFor` | `models/guardians.php:568-616` | managedReach all/gender vs child gender, else any active class of the child via `can(...,['class'])` |
| `TeachersModel::canView` | `models/teachers.php:765-810` | `teachers:lookup` any, then by gender, then `teacher_gender=1` AND member actually teaches (`teachers` row or `classes.teacher`); no-gender member needs scope `all` |
| `TeachersModel::changeTrainingLevels` | `teachers.php:679-700` | per teacher `can(teachers:read,['gender'=>(int)users.gender])` |
| `McqModel` copy | `models/mcq.php:127-130,194-198` | `can(mcqs:copy,[class])` on source AND target; class dropdown via `can(mcqs:copy,[gender])` per gender |
| `SessionsModel::isEditable` | `models/sessions.php:90-114` | state rule, see section 7 |
| `ClassScheduledNotificationWorker` | `models/classschedulednotificationworker.php:168` | re-checks `notifications:send` on the class at fire time |
| `QuizAdminModel::canReset` | `models/quizadmin.php:258-275` | `can(quiz:reset)` inside the model; deny on lookup failure |
| `ClassesModel::deactivate` | `models/classes.php:1733` | re-checks `deactivated-classes:manage` |

## 4. Scopes

| scope | stored as | compared with target | meaning |
|---|---|---|---|
| `all` | name only | always true (class must be active) | every class and member |
| `gender` | not stored; derived from roleid 3 or 4 (`permissions.php:353`) | `classes.gender` (INT 1 gents, 2 ladies) or target gender | classes of the admin's own gender |
| `assigned` | `class_access_rules` + `class_access_rule_conditions` (`migrations/2026_09_28_class_access_rules.sql`); `class_access` is a VIEW over them (`2026_09_28_class_access_cutover.sql`, definition `tools/synthetic-data/schema.sql:1336`) | class id in the resolved list; gender target vs `assigned_genders` | rule = member + gender (null = either) + conditions `field IN/NOT IN values`, fields `city`, `country`, `level` (`class_level_id`), `tag`. Values of one field ORed, different fields ANDed, negations excluded, case-insensitive text; null city/country/level fails a NOT IN too; several rules unioned; active classes only (`docs/dev/domain.md:24-57`; `classaccess.php:394-523`). Evaluated live, so a new class is covered at once |
| `own` | derived (teach, or `class_students.mcq_admin=1`) | class id in list | classes taught or MCQ-flagged |
| `taught` | derived | class id in list | classes taught |
| `enrolled` | derived | class id in list | classes attended |
| `self` | name only | never matches a class or gender target | the user's own data; only passes an empty-target check, and the model scopes the rows to the caller's token |

All class lists are active classes only (`permissions.php:23`). Scope kinds that are not in permission names: **city, country, level, tag** (only as rule conditions behind `assigned`); there is no `level`/`city` permission scope.

## 5. Gender segregation

Gender data: `classes.gender` INT (1 gents, 2 ladies); `users.gender` is **text** holding `'1'`/`'2'` and also `'Male'`/`'Female'` (`models/entityaccess.php:273-288`, `classaccess.php:48`). Some code normalises via `genderOf`, some casts `(int)` (so `Male` reads 0): `guardians.php:584`, `teachers.php:690-699`. GENDER_GENTS=1, GENDER_LADIES=2 (`functions.php:27-28`).

| rule | where | who/what |
|---|---|---|
| gender-scope permissions | `permissions.php:289-290,307-309` | roles 3/4 hold `*:gender` names; class or target gender must equal own |
| assigned scope by gender | `:311-312` | coordinators match the genders of their assigned classes |
| teacher rule: gents may teach ladies, not the reverse | `permissions.php:321-327`; `classes.php:1320-1339` (`searchTeachers`, `isTeacherCandidate`: gents class takes gents only, plus hard-coded token 1001 always eligible) | teacher lookup/assignment |
| enrol only same gender (unrecorded gender allowed) | `models/classstudents.php:152-171,247-270`; `routes/classes.php:286` (join 403); `member_enrol.php:140-146` (422 `other_gender`); `class_manage.php:727` | all enrol paths |
| transfer same gender | `routes/class_manage.php:899` | `students:transfer` |
| member sees class only if class.gender == own gender AND enrolled | `models/classes.php:937-961` (`getForUser`) | members (managers and the teacher bypass) |
| profile gender frozen while enrolled | `models/subscribers.php:46-66`; `routes/users.php:106` (422) | members |
| report gender lock | `permissions.php:184-198`, `routes/reports.php:21-27`, `teachers.php:19-26` | gender admin / single-gender coordinator get their gender whatever `?gender=`; others get requested, default gents |
| gender target in guards | `reports:read`, `quran-leaderboard:read`, `registrations:read/reject`, `teachers:read`, `classes:create` | `api_require(...,['gender'=>g])` |
| class-access management by gender | `classaccess.php:845-860` | operator needs `class-access:manage` for member's and rule's gender |
| parent links | `guardians.php:458,525,978-992` | `parents:manage` with `['gender'=>child gender]` |
| gents registrations include unset gender | `models/subscribers.php:554` | `(gender=1 OR gender=0)` |

Applied as list filters (not allow/deny): `MisModel::reach()/reachFilter()` (`models/mis.php:16-60`: all -> optional gender; gender/assigned union; none -> `1=0`), `ClassesModel::getAll` and `SubscribersModel` allocated counts and `QuranRecitation` via `assignedOnlyIds` (`models/classes.php:205`, `subscribers.php:420`, `quranrecitation.php:55`), `listForUser($reach)` (`classes.php:795`), search `searchReach` + `SearchFilterModel::allows/toEs` (`models/search.php:80-170`, `searchfilter.php`), `onlyReportable` (`mis.php:693`), `copyableClasses` per gender.

## 6. Where checks happen

- Front controller `web/api/mobile/index.php`: matches path+method, records the route pattern for the deletion gate (`:309-310`), loads handler; 404/405 otherwise (`:320`). **No central authorization**; each handler calls `api_authenticate(true)` then `api_require(...)` (RoutePermissionsTest enforces that every route names a check or an exemption, `tests/mobile-api/RoutePermissionsTest.php`).
- Routes: 211 rows. Public: `/health`, `/app-version`, `/release-notes`, `/join/{code}` (rate limited), `/auth/debug-token` (404 in production). Sign-in only, no catalog check: `/auth/link`, `/me/permissions`, `/me/permissions/{p}`, `/user/permissions`, `/class-levels`, `/holy-quran`, `/registration` x2, `/geo/*` x3. Everything else calls `api_require` (CSV column `permission_checks`).
- Check in handler only: most. Check in handler AND model: class access, parent links, teacher detail/training, MCQ copy, quiz reset, class deactivate, scheduled notifications. Check only in model after a coarse handler check: `/search`, `/students/{t}`, `/subscribers/{t}`, `/teachers/{t}`, class-sessions history, `/admin/class-access/*`.
- Checks inside SQL (row filtering): reports (all of `/reports/*`), `/classes` (`include=managed`), registrations report and allocated download, quran leaderboard, class lists for copy, `getAll`, search, children and my-* (own token), inbox.
- Admin actions are audit-logged by `api_log_admin_action` (`lib/audit.php`) on class manage/create/update, member enrol, syllabus, notifications, WhatsApp QR (`routes/*.php` as listed in CSV notes).
- Refusals: 403 for permission (`api_require`), 404 for not-in-scope/hidden objects (e.g. parent links, student card), 422 for gender/validation rules.

## 7. Non-permission gates

| gate | where | effect |
|---|---|---|
| Missing bearer / bad Firebase token | `lib/auth.php:108-128` | 401 |
| Registration incomplete = token 0 | `auth.php:158-160` | 403 on every `api_authenticate` route (1,729 abandoned rows per comment); new Firebase users are created with a token (`models/subscribers.php:120-128`) so this hits legacy rows only |
| Profile gender missing | `routes/classes.php:124-138` | 400 on routes using `api_require_identity` (classes sessions/guide/join/attendance/performance, quizzes, `/search`) |
| Account deletion pending | `auth.php:41-70,235-257` | 403 `{detail, deletion_status}` for every route except `GET /health`, `POST /auth/link`, `POST /auth/debug-token`, `GET /me`, `GET/POST/DELETE /me/deletion-request`, `DELETE /devices` (status in `pending`, `awaiting_prize_delivery`, `AccountDeletionModel::LIVE`) |
| Resurrection guard | `auth.php:202-223` | after a completed deletion for that email inside `RESURRECTION_WINDOW_SECONDS`, `api_authenticate(true)` is refused 403 |
| App minimum build | `routes/app_version.php` | **not enforced server-side**: `/app-version` only publishes `minimumBuild`; the client decides |
| Guests | none in the API | no guest-ok route; token-0 users are 403 and hold no permissions (`permissions.php:348`) |
| `api_authenticate(false)` | `routes/feedback.php:12` | the only route that does not create the users row |
| Rate limits (`rate_limit_allows`) | join preview 30/60s per IP; class push 10/h; scheduled create 20/h; class create 1/60s per signature; bulk add 10/60s; member lookup/enrol 30/h; parent invite inspect 60/h; parent candidate 30/h; CC nudge 30/h; geo 60/min; WhatsApp per user; deletion complete 1/60s | 429 |
| Session edit window | `models/sessions.php:90-114` | a conduction session is editable only if created <= 10 days ago AND (creator OR class teacher OR holds `sessions:update` on the class); 403 "Session is not editable" (`routes/conduction.php:515`) |
| Quiz state | `models/mcq.php:906-933`, `routes/mcq.php` | quiz must be published, student enrolled; not deactivated to answer; 409 attempted; `restrict_to_class` flag deliberately ignored |
| Class state | `permissions.php:436`, `api_find_class` | inactive class is 404 or deny everywhere |
| Registrant state | `routes/registrations.php:20-35` | 409 once placed/rejected; refusal ordering avoids leaking id existence |
| Class removal | `routes/classes.php:300-305` | removed members cannot re-join by link (403) |

## 8. Tests that could seed a permission matrix

| path | rough count | covers |
|---|---|---|
| `tests/mobile-api/RoutePermissionsTest.php` | 4 tests, one table of every route -> permission names (exempt with reasons) | the route-to-permission map (source for the CSV cross-check) |
| `tests/mobile-api/MePermissionsTest.php` | 30 | `forUser`/`can` per fixture user and class; uses the old `canAddConduction`/`canAccessClass` as oracle (header comment, `:12`, `:205`) |
| `tests/mobile-api/PermissionsVerifyTest.php`, `ApiRequireTest.php` | 2, 4 | `verify`, `api_require` |
| `tests/mobile-api/ClassListReachTest.php`, `ReportableClassReachTest.php`, `SearchReachTest.php`, `SearchFilterTest.php`, `ThisWeekTeacherMobilesTest.php` | 7, 7, 7, 8, 5 | reach and row filters |
| `tests/mobile-api/PermissionGrantsRouteTest.php`, `ClassAccessRouteTest.php` | 9, 22 | admin routes |
| `tests/web/ClassAccessModelTest.php` | 103 | rule semantics and gender management |
| `tests/web/EntityAccessTest.php`, `PermissionGrantsModelTest.php`, `GuardiansModelTest.php`, `TeachersModelTest.php`, `McqCopyPermissionTest.php`, `PagePermissionsTest.php`, `RegistrationsAllocatedReachTest.php` | 33, 15, 41, 15, 8, 4, 6 | per model |
| `tests/score/QuizAdminCharacterizationTest.php` | 64 | quiz admin incl. reset permission |
| `tests/e2e/permission-matrix.txt` (115 lines) + `permission_matrix.py`, `mobile_api_matrix.py`, `write_negatives.py`, `personas.php`, `fixtures.php` | spec file, runs against the LOCAL stack | hand-written who-may-open table over web pages for 14 personas (super_admin, gents_admin, ladies_admin, coordinator variants, finance, named grants...); `docs/specs/permissions-enforcement/leak-testing.md` describes layers (the mobile-API differential is marked "not done" there). Needs a running stack; I did not run it |

Unit tests load the migration INSERTs into SQLite (`MePermissionsTest.php:123`), so the seed files above are the tested catalog.

## 9. Unknowns

- Live data: which users hold which role, who holds each named grant, and the actual `class_access_rules` content were not read (no DB access). "Roles 3 and 6 held by nobody" rests on `docs/dev/domain.md:18` and `docs/mobile/web-vs-mobile-parity.md:227`; the same doc says live roleid is only 0,1,4,5,7.
- Whether production `permissions`/`role_permissions` equals the migrations (rows could have been edited by hand); `role_permissions` for role 1 was seeded by pattern on 2026-09-27, so names added later as `:all` appear only if a migration granted them.
- `children.php` row filtering of five routes (model SQL for parent/child lists not read fully); `unknown` in the CSV.
- Web pages (`web/*.php`) and their guards were out of scope (mobile API only); `docs/specs/permissions-enforcement` suggests they use `verify()` with 404.
- `quizadmin.php` and `whatsapp`/`deletion-request` internals beyond the permission gate were not read.
- `MisModel::getClassFilter` body (`models/mis.php`, the `$user` variant used by class-session history) was not read beyond its caller; I assumed it uses the same `reachFilter` (comment at `mis.php:2251`).
- The Elasticsearch search index (`searchsource.php`, outbox) is a second copy of class/person data used in access filtering; its freshness semantics were not verified (every hit is re-checked against the DB per `models/search.php:80-170`).
