# Fill batch B1 notes (11 Nov 2026): class reads

Groundwork: `ClassScopes` (classes supplies access's `IClassScopes`; `Dependencies = ["access"]`, `Services.Replace` because `AddAccess` runs first); `domain/ClassGuards.cs`,
`Refusals.cs`, `GuideSlugs.cs`; fixtures `db/synthetic/classes-fixtures.sql` + `tools/parity-php/classes-fixtures.sql` (tokens 900301+, classes 9301-9303); `tools/classes-contract.sh test|parity`.
Fixed in the seed (found by the groundwork, advisor step 2): the schema-phase seed made 900104/900107 (inside the access contract's 9001xx range) class teachers, so the real port moved
`/me/permissions` on the new API only; the teachers are now 900301/900302 (the fixture file also retargets an already-seeded database). The seed's class levels did not match PHP's reference
data (PHP: 1 SM SALMAN, 2 AG ABUZAR, 3 MK MIQDAD, 4 AY AMMAR, 5 B BILAL; the guide slugs go by those ids); the seed now matches.
Swap: `GET /me/guides` and `GET /me/guides/{slug}` do not exist in the PHP archive (`build/parity-php/src`, the running oracle); the recon read a newer tsr-account. No oracle, so they are replaced by two extras.
share_url (guide, class guide) is null: PHP gives null without `REDIRECT_URI`, neither side sets it; the public web base setting is deferred.

## Slices
- GET /guides, /guides/{level_id}, /classes/{class_id}/guide, /syllabus/levels, /syllabus/level/{level_id}, /classes/{class_id}/syllabus-topics, /classes/{class_id}/sessions:
  files `features/{guides-list,guide-get,class-guide,syllabus-levels,syllabus-level,class-syllabus-topics,class-sessions}/`; PHP pass, new pass (class-levels.hurl also now passes on PHP).
  Quirks copied: `(int)` cast of ids ("3abc" is 3), `str?` of '' is null, sessions list has no `deleted_at` filter and includes not-conducted rows, topics catalogue is an embedded data file (only MIQDAD).
- GET /classes/{class_id}/my-attendance, /my-performance, /me/children/{child_token}/classes, .../{class_id}/attendance, .../{class_id}/performance:
  files `features/{my-attendance,my-performance,child-classes,child-attendance,child-performance}/`, `domain/{StudentAttendance,ChildGuards,PhpFloat}.cs`; PHP pass, new pass.
  Migration added (assessment): `QuizResultsAnswered` adds `answered` to `v_quiz_results` (PHP divides by the member's response count, not the quiz's question count); assessment CLAUDE.md updated.
  Dates: both parts are bounded. A bound is read as MariaDB reads a date (Y-m-d with one or two digit parts, any punctuation, YYYYMMDD, each with an optional time after a T or a space; a bare date is its midnight) and compared as a time:
  the session day at midnight, the quiz by `v_quiz_results.answered_at` (added to `QuizResultsAnswered`: the member's first response to the quiz). Deviation (recorded): PHP bounds each response by its own time, here a quiz is in or out as a whole.
  Text MariaDB cannot read as a date is ignored (PHP hands it on; Postgres would throw); only readable forms are tested. Floats are written as PHP does (`100.0`, `PhpFloat`). Summary is computed from the history rows (same WHERE as PHP's two queries).
  Quirk copied: a teacher passes the my-* guard and sees every session absent; child classes has no status filter.
- GET /classes, GET /classes/{class_id}: `features/{classes-list,class-detail}/`, `domain/ClassCards.cs`; PHP pass, new pass. The wire card is an ordered map (PHP's array), the list adds city, country, tags, studentCount, schedules.
  PHP BUG not copied: any `?q=` answers 500 on PHP (`:q` is used twice with native prepares), so q is tested in `classes-list-search-new-api.hurl`, which `classes-contract.sh parity` skips (files named `*-new-api.hurl`).
  Quirks copied: q "0" is empty (PHP empty()); studentCount counts enrolment rows with no removed_at (any status) plus the lines of extra_students; role managing only with a reach and no enrolment; joinUrl always null (public web base, deferred).
  Deviation: PHP throws 500 when a class lacks its gender, level or teacher row and the caller is not the teacher (reaches() gets false); here the class is just not treated as managed.
  Seed fix: seed classes 9001-9004 now have teachers 900303/900304 (900301 would put the fixture teacher in a seed class PHP does not have).

## Result and what is left
14 new slices built (15 in classes with class-levels; catalog 36 built, 177 planned). Stopped at a slice boundary on budget: not built are the 2 swapped `/me/guides*` (no oracle) and 5 of the 8 extras:
`/classes/{id}/students`, `/classes/{id}/teachers`, `/classes/{id}/schedule`, `/classes/create-options`, `/classes/teachers` (smallest first), then `/classes/{id}/manage`, `/classes/{id}/students/performance`, `/teachers/{token}`.
Checks: build 0 warnings; tests: classes 13, hosts/api 245, shared/api 93, access 64, db 290, all green; Hurl on the test stack 16 classes files (102 requests), on PHP 15 (97; the 16th is `*-new-api`);
planned-surface (15 requests), access contract 3 files pass on the test side. Not run: geo and membership Hurl (as told).
Process note: Hurl was written and run on PHP first for every slice; the red run on the new side (501) was not captured separately.

Deferred (recorded, not fixed):
- `ClassScopes` loads up to 10,000 active classes and all their tags on every permission check that needs the class set.
- `?q=` in the classes list does not escape `%` and `_` and has no length cap (the same as PHP).
- The 403 branches of the my-* and child routes cannot be reached over HTTP: every signed-in member holds `performance:read` and `children-performance:read` (PermissionSets.Member), a guest cannot sign in, so no Hurl case exists for them.

## Batch B2 (11 Nov 2026): the five smallest extras
- GET /classes/{id}/students, /classes/{id}/teachers, /classes/{id}/schedule, /classes/create-options, /classes/teachers: files `features/{class-students,class-teachers,class-schedule,class-create-options,class-create-teachers}/`,
  `domain/{TeacherSearch,Timezones}.cs`, `data/timezones.json` (PHP's 143 pairs; 121 zones after first-label-wins); contract `spec/tests/{class-students,class-teachers,class-schedule,class-create-options,class-create-teachers}.hurl`;
  PHP pass, new pass (classes: 22 files, 156 requests on the new side, 21 files, 151 on PHP). No migration, no view: email comes from `identity.v_users`, name and mobile from `membership.v_members`.
  Fixtures: enrolment rows get a fixed `created_at` (the roster's joinedOn is the day of created_at) and row 9301 a note, both sides.
  Quirks copied: a caller without classes:update gets email, mobile, notes as null placed first in the object (PHP `[null...] + $s`); schedule slots in id order (PHP has no ORDER BY); /classes/teachers gender is 2 only for the text "2";
  the teacher pool is every active student of any class plus token 1001 (PHP constant). Deviation: name search uses ILIKE (PHP's collation also ignores accents). A teacher of the class may read its schedule (classes:schedule:own) and roster (names only).
  planned-surface.hurl: its literal-before-param case moved from /classes/teachers (now built) to /classes/1/conduction/new.
  Not run: the full Hurl glob (membership and geo prepare); the red run on the new side (501) was not captured separately.
- Review fix (main thread): a NUL byte in `q` gave 500 on `/classes/teachers`, `/classes/{id}/teachers` and `/classes`; now an empty result, as PHP answers for the teacher searches (Hurl cases added). Any other route passing request text to SQL may share this: check per slice. Deferred: `ILIKE` does not ignore accents as MySQL's `LIKE` does; silent caps of 5000 students and 5000 tags.
