# domains/classes/

Classes, levels, tags, schedules, sessions, attendance, enrolment, teachers, syllabus and guides, and the class reports.

## Status

All 96 operations are built; there is no `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). One folder per
slice under `api/features/<slice>/`, its contract in `spec/tests/<slice>.hurl`, shapes and per-route rules in `spec/api.yaml` and
in each slice's header comment. `GET /class-levels` (`api/features/class-levels/ClassLevels.cs`) is the slice template.

| Slices | Count | What |
|---|---|---|
| `class-*`, `classes-list` | 25 | levels, list, detail, sessions, manage, create and its options, the two teacher searches, update, deactivate, schedule, roster, add, bulk add, edit, remove, restore, transfer, class admin, join by link |
| `conduction-*` | 6 | a teacher records a class session: list, `new` (the form's data), `check`, one record, `POST`, `PUT` |
| `guide*`, `me-guide*`, `syllabus-*` | 7 | guides by level, a member's guide by slug, the syllabus |
| `my-*`, `child-*`, `teacher-detail` | 6 | my and a child's attendance and performance, a child's classes, one teacher |
| `registration-*`, `join-preview` | 3 | a waiting registrant's classes, place, the public join preview |
| `admin-*` | 15 | syllabus, transfers, member lookup and enrolment by token, deactivated classes and candidates, teachers (list, training, import) |
| `report-*` | 34 | the class reports, their CSV and downloads, the MCQ reports, the recitation leaderboard, the pending nudge |

| Part | State |
|---|---|
| Schema `classes`, 16 tables: `classes`, `class_levels`, `tags`, `class_tags`, `class_schedules`, `topics`, `class_schedule_topics`, `class_sessions`, `class_attendance`, `class_students` (enrolment), `student_transfers`, `class_audit_log`, `teachers`, `teachers_history`, `syllabus`, `guides` | built; migration `Initial` |
| Port `IClassScopes` (access), supplied from `api/ClassScopes.cs` (`Services.Replace`, because `AddAccess` registers first) | built; `IClassEnrolments` (membership) not yet: membership uses its default. No other public interface yet |
| PHP's trigger on `classes` (the share `link`) | not ported as a trigger: `POST /classes` draws the link (ten random base-36 characters) |

## Owns

- Schema `classes` (above). Column names follow PHP's, so the data move is a copy. Keys that name a member, gender, language or another domain's row are plain
  integers; the one foreign key (`syllabus` to `class_levels`) stays inside the schema. A session's day (`conducted_on`) and the class dates are `date`.
- `classes.city` and `classes.country` (the columns access rules match) use the ICU collation `public.geo_ci_ai` (case and accent insensitive, as MariaDB's
  was), declared by platform's migration. Every other text column is `citext` with a length CHECK.

## Dependencies

`access`, `platform`, `membership`, `identity`, `notifications` (`ClassesModule.Dependencies`). Register it after platform (`Program.cs`): its migration uses platform's collation.

Other domains are read through their published `v_*` views in SQL: `membership.v_members`, `v_guardian_links`, `platform.v_genders`, `assessment.v_quiz_results`, `v_quizzes`, `v_standard_mcqs`, `v_class_mcq_copies`, `content.v_quran` (the surah list of the conduction screens).

| Published command or interface used | Owner | Used by |
|---|---|---|
| `Permissions`, and the port `IClassScopes` this domain supplies | access | the permission checks and scopes |
| `PlatformCommands.RecordAdminAccessAsync` | platform | manage, update, create, bulk add |
| `ReportExport` | platform | the report downloads (xlsx or PDF) |
| `MembershipCommands.RecordAcceptedRegistrationAsync` | membership | add, join, place, bulk add (through `Enrolment.AddAsync`) |
| `MembershipCommands.ChangeContactAsync` | membership | edit a student |
| `MembershipCommands.CreateProfileAsync` | membership | bulk add |
| `IdentityCommands.CreateMemberAsync` | identity | bulk add |
| `IdentityCommands.ChangeEmailAsync` | identity | edit a student |
| `NotificationsCommands.LastNudgeAsync`, `AnnounceAsync` | notifications | the nudge |

## Rules specific to this domain

- Every route but the join preview is `create`: PHP signs the caller in with the member-creating sign-in.
- Each write writes its rows and one outbox row in one transaction.
- The admin audit row PHP writes for privileged callers (manage, update, create, bulk add) is platform's published command, called through `ClassGuards.LogAdminAccessAsync` right after the permission check.
- PHP's push, WhatsApp and search-outbox touches on enrolment changes are not sent (conduction sends nothing in PHP either): the outbox row is the hand-off.
- Every report takes its gender and reach from `domain/ReportScope.cs`: the gender lock, the `reports:read` reach as one list of class ids, the demo class AYD1 never in it.
- A report's read slice is thin: its query and rules are in `domain/`, so the screen and the download share them.
- The recitation leaderboard is built here, not in content, because it reads class attendance. The eight MCQ report routes are here, not in assessment.
- `domain/GuideSlugs.cs` is PHP `GuidesModel::SLUGS`; `domains/search/api/domain/SearchFacts.cs` holds a copy.
- The `/me/guides` guard is `domain/GuideReaders.cs`: `syllabus:read`, then an active enrolment or an active class taught, read from access's resolved scopes.

## Settings

| Setting | Read by | Meaning |
|---|---|---|
| `TSR_PUBLIC_WEB_BASE` | `GET /me/guides/{slug}` | `share_url` is this plus `/guide.php?guide=<slug>`; null without the setting |

## Public routes (no sign-in), and why

`GET /join/{code}` is `security: []` in `api.yaml` (domains/CLAUDE.md rule 4): the app shows the class a join link names before sign-in (PHP's reason, kept). It returns only name, level, language, gender and open, never the teacher, counts or ids, and is limited to 30 calls a minute per client address (`MemberRateLimit`, in memory; `ClientAddress` is PHP's `client_ip`).

## Advisory locks (`pg_advisory_xact_lock(class, key)`)

| Class | Key | Used by |
|---|---|---|
| 7200001 | member token | POST /admin/members/{token}/enrolments |
| 7300001 | teacher token | POST /reports/pending/nudge (the 24-hour rule is checked again under it) |

## Where things are

| Need | File |
|---|---|
| The HTTP contract | `spec/api.yaml` |
| Module: registration, routes, dependencies | `api/ClassesModule.cs` |
| Tables | `api/ClassesContext.cs`, `api/ClassesEntities.cs`, `api/Migrations/` |
| Guards and refusals | `api/domain/ClassGuards.cs` (the class reads), `AdminGuards.cs`, `ChildGuards.cs`, `Refusals.cs` |
| Enrolment (PHP `addStudent`) and its rules | `api/domain/Enrolment.cs`, `EnrolmentRules.cs`, `WaitingRegistrant.cs` |
| Conduction: rules, shared reads, the one write | `api/domain/ConductionRules.cs`, `ConductionData.cs`, `ConductionWriter.cs` |
| Admin: syllabus, transfers, lookup, deactivation, teachers | `api/domain/SyllabusItems.cs`, `SyllabusRules.cs`, `ClassListing.cs`, `TransferRoster.cs`, `StudentMove.cs`, `MemberLookup.cs`, `DeactivationView.cs`, `TeacherTraining.cs`, `TeacherWriter.cs` |
| Reports: reach, months, weeks (PHP's `calendar_table` without the table), dates, CSV, figures | `api/domain/ReportScope.cs` (also `KeepAssignedAsync`), `ReportMonths.cs`, `ReportCalendar.cs`, `ReportDates.cs`, `ReportCsv.cs`, `ReportFigures.cs`, `NaturalCompare.cs` (PHP `strnatcmp`) |
| One report's query and rules | `api/domain/<Name>Report.cs` with its `*Rules`, `*Figures`, `*Weeks` or `*Grid` file; also `ActiveTeachers`, `ClassSessionHistory`, `SyllabusCatalogue`, `TeacherView`; `SummaryRows` is shared by summary and pending |
| MCQ reports and the leaderboard | `api/domain/McqSummaryReport.cs`, `McqAdherenceReport.cs`, `McqAdherence.cs` (the pending report's MCQ query too), `ReportClasses.cs`, `AskedClassIds.cs`, `QuranLeaderboard.cs` (shared with the students report) |
| Fixtures: which file, its tokens and ids, what resets | the header of `tools/classes-contract.sh` and of each `db/synthetic/classes-*-fixtures.sql` (PHP side: `tools/parity-php/classes-*-fixtures.sql`); `classes-bulk-cleanup.sql` first deletes the members a bulk add created |
| Fixtures of the MCQ report, leaderboard and nudge files | `db/synthetic/reports2-fixtures.sql`, `tools/parity-php/reports2-fixtures.sql` |
| Build notes, facts and decisions | `docs/specs/initial-build/`: `fill-b1-notes.md` to `fill-b5d-notes.md`, `lane-mcq-reports-notes.md`, `lane-small-notes.md`, `test-reports2-notes.md`, `schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md` |

## Checks

```
dotnet test domains/classes/api/tests   # the model: the 16 tables in schema "classes"; the *.Tests.cs beside the rules
dotnet test db/tests                    # the migrated database: citext, no cross-schema key, the limited role's rights
tools/classes-contract.sh test|parity   # loads and resets the fixtures, then every Hurl file but the three groups below
tools/contract-reports2.sh test|parity  # report-mcq-*, report-quran-leaderboard*, report-pending-nudge* (classes-contract.sh skips them)
```

Database tests of this domain's writes and reports: `db/tests/ConductionWritesTests.cs`, `EnrolmentWritesTests.cs`, `BulkAddTests.cs`, `AdminB4aWritesTests.cs`, `ReportsB5aTests.cs`, `ReportsB5bTests.cs` (the pending, TSR and students reports too), `ReportsB5dTests.cs`, `TestReports2Tests.cs`, `MeGuidesTests.cs`.

## Events (outbox, written in the transaction of the change; no consumer yet)

| Event | Payload | Written by |
|---|---|---|
| `classes.student_class_admin_changed` | classId, token, mcqAdmin, changedBy | PUT .../students/{token}/class-admin |
| `classes.schedule_replaced` | classId, slotCount, changedBy | PUT /classes/{id}/schedule |
| `classes.class_updated` | classId, changedBy | PUT /classes/{id} |
| `classes.class_created` | classId, createdBy | POST /classes |
| `classes.guide_saved` | levelId, languageId, changedBy | PUT /guides/{level_id} |
| `classes.student_removed` | classId, token, removedBy | POST .../students/{token}/remove |
| `classes.student_restored` | classId, token, restoredBy | POST .../students/{token}/restore, POST /admin/members/{token}/enrolments (a removed row comes back) |
| `classes.student_enrolled` | classId, token, addedBy (null for join and place), source (`added`, `joined`, `placed`, `bulk`, `by_token`) | POST .../students, POST .../students/bulk (one per enrolled or created member), POST /classes/join, POST /registrations/{id}/place, POST /admin/members/{token}/enrolments (a new row) |
| `classes.student_rejoined` | classId, token | POST /classes/join (a member who left) |
| `classes.student_transferred` | fromClassId, toClassId, token, type, transferredBy | POST .../students/{token}/transfer, POST /admin/transfers (one per student moved) |
| `classes.class_deactivated` | classId, type, effectiveDate, auditId, removedTokens, deactivatedBy | POST /classes/{id}/deactivate |
| `classes.session_recorded` | classId, sessionId, recordedBy | POST /classes/{id}/conduction (none for a replay or a refusal) |
| `classes.session_updated` | classId, sessionId, updatedBy | PUT /classes/{id}/conduction/{session_id} |
| `classes.student_edited` | classId, token, editedBy | PUT /classes/{id}/students/{token} (the class note; the email and contact events belong to identity and membership) |
| `classes.syllabus_item_created` | syllabusId, levelId, createdBy | POST /admin/syllabus |
| `classes.syllabus_item_updated` | syllabusId, changedBy | PUT /admin/syllabus/{id} |
| `classes.syllabus_item_deleted` | syllabusId, deletedBy | DELETE /admin/syllabus/{id} |
| `classes.teacher_nudged` | teacherToken, senderToken, classIds | POST /reports/pending/nudge (with send true) |
| `classes.teacher_training_changed` | token, salman, abuzar, miqdad, ammar, bilal, changedBy, batchId | POST /admin/teachers/training, POST /admin/teachers/import (one per teacher) |

Consumed: none.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_classes` | id, code, name, class_level_id, gender, teacher, status, city, country, level_name (migration `ClassViewLevelName`), extra_students (migration `ClassViewExtraStudents`), language_id and level_sort_order (migration `ClassViewLanguageLevelOrder`) | access (scopes), membership (waiting list, gender lock, the student card: level name, the placed-registrations file: extra students), assessment (the class code of the open quizzes, the manage and copy routes: the class code, level, city, language and level order), assessment reports |
| `v_class_levels` | id, code, name, sort_order (migration `ClassLevelsView`) | access (class access: the levels a rule can use, and the check that a level exists), notifications (history: audience words) |
| `v_enrolments` | id, class_id, token_no, status, removed_at, mcq_admin | access (mcq scope), membership (placed, gender lock), assessment (every quiz route: who is a current student), assessment reports, notifications (class audience) |
| `v_teachers` | token, status (migration `TeacherView`) | search (the teacher re-check: an active teacher, and whether a member teaches) |
| `v_guides` | level_id, language_id, level_name, has_text (whether the guide is non-blank; the text is not published; migration `GuideView`) | search (the guide re-check: a counting guide and its level's name) |
| `v_class_schedules` | id, class_id, day, hour, minute, timezone, deleted_at (deleted slots included; migration `ClassScheduleAndLevelViews`) | notifications (scheduled reminders, the slot list) |
