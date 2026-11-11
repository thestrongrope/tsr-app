# domains/classes/

Classes, levels, tags, schedules, sessions, attendance, enrolment, teachers, syllabus and guides.

## Status

**Tables, 26 read slices and 19 write slices (2026-11-11).** `GET /class-levels` (`api/features/class-levels/ClassLevels.cs`, the slice template) and 19 more reads (batch B1: guides, syllabus, sessions, my and child attendance and performance, the class list and detail, the roster, the schedule, the two teacher searches, the create options; one folder each under `api/features/`, contract `spec/tests/<slice>.hurl`). It supplies access's `IClassScopes` (`api/ClassScopes.cs`); no other public interface yet. Run the contract with `tools/classes-contract.sh test|parity`; notes: `docs/specs/initial-build/fill-b1-notes.md`. Batch B2a added 3 reads (`manage`, `students/performance`, `GET /teachers/{token}`) and 8 writes (`PUT .../class-admin`, `PUT /classes/{id}/schedule`, `PUT /classes/{id}`, `POST /classes`, `PUT /guides/{level_id}`; each writes its rows and one outbox row in one transaction); the write contract files run against the WRITE fixtures (`db/synthetic/classes-write-fixtures.sql`, `tools/parity-php/classes-write-fixtures.sql`), reset by `tools/classes-contract.sh` on every run; notes: `docs/specs/initial-build/fill-b2-notes.md`. Batch B2b added the enrolment writes: remove, restore, add one, transfer, join by link (`POST /classes/join`), the public `GET /join/{code}` preview, `GET /registrations/{id}/classes` and place (`POST /registrations/{id}/place`); the shared rules are `api/domain/Enrolment.cs` (PHP `addStudent`), `EnrolmentRules.cs`, `WaitingRegistrant.cs`, `ClientAddress.cs`; their contract files run against the ENROLMENT fixtures (`db/synthetic/classes-enrol-fixtures.sql`, `tools/parity-php/classes-enrol-fixtures.sql`, tokens 9005xx, classes 9411 and up), reset on every run; notes: `docs/specs/initial-build/fill-b2-notes.md`. Batch B2c added deactivate (`POST /classes/{id}/deactivate`) and edit a student (`PUT .../students/{token}`), their files run against the B2C fixtures (`db/synthetic/classes-b2c-fixtures.sql`, `tools/parity-php/classes-b2c-fixtures.sql`, tokens 9006xx, classes 9431 and up). Bulk add (`POST .../students/bulk`) is built (BULK fixtures `db/synthetic/classes-bulk-fixtures.sql` and `tools/parity-php/classes-bulk-fixtures.sql`, tokens 9007xx, classes 9451 and up; `classes-bulk-cleanup.sql` first deletes the members a run created). Batch B3 added conduction (a teacher records a class session): list, `new` (the form's data), `check`, one record, `POST` and `PUT` (`api/features/conduction-*/`; the pure rules are `api/domain/ConductionRules.cs`, unit tested, the shared reads `ConductionData.cs`, the one write `ConductionWriter.cs`, db test `db/tests/ConductionWritesTests.cs`); their files run against the CONDUCTION fixtures (`db/synthetic/classes-conduction-fixtures.sql`, `tools/parity-php/classes-conduction-fixtures.sql`, tokens 9008xx, classes 9471 and up, sessions 947101 and up, run-created sessions deleted on every reset); notes: `docs/specs/initial-build/fill-b3-notes.md`. The other operations are 501 placeholders in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `classes`, 16 tables: `classes`, `class_levels`, `tags`, `class_tags`, `class_schedules`, `topics`, `class_schedule_topics`, `class_sessions`, `class_attendance`, `class_students` (enrolment), `student_transfers`, `class_audit_log`, `teachers`, `teachers_history`, `syllabus`, `guides` | built; migration `Initial` |
| Port `IClassScopes` (access), supplied from here (`Services.Replace`, because `AddAccess` registers first) | built; `IClassEnrolments` (membership) not yet: membership uses its default |
| Published views `classes.v_classes`, `classes.v_enrolments` (migration `PublishedViews`) | built |
| PHP's trigger on `classes` (the share `link`) | not ported as a trigger: `POST /classes` draws the link (ten random base-36 characters) |

## Owns

- Schema `classes` (above). Column names follow PHP's, so the data move is a copy. Keys that name a member, gender, language or another domain's row are plain
  integers; the one foreign key (`syllabus` to `class_levels`) stays inside the schema. A session's day (`conducted_on`) and the class dates are `date`.
- `classes.city` and `classes.country` (the columns access rules match) use the ICU collation `public.geo_ci_ai` (case and accent insensitive, as MariaDB's
  was), declared by platform's migration. Every other text column is `citext` with a length CHECK.
- Dependencies: `access` (`Permissions` and the port `IClassScopes` it supplies), `platform` (`PlatformCommands.RecordAdminAccessAsync`, the admin audit row), `membership` (`MembershipCommands.RecordAcceptedRegistrationAsync`, `ChangeContactAsync`, `CreateProfileAsync`), `identity` (`IdentityCommands.ChangeEmailAsync`, `CreateMemberAsync`); all `ClassesModule.Dependencies`. Other domains are read through their published `v_*` views in SQL (`membership.v_members`, `v_guardian_links`, `platform.v_genders`, `assessment.v_quiz_results`, `assessment.v_quizzes`, `content.v_quran` for the surah list of the conduction screens). Register it after platform (`Program.cs`): its migration uses platform's collation.
- Events (outbox, written in the transaction of the change; no consumer yet):

| Event | Payload | Written by |
|---|---|---|
| `classes.student_class_admin_changed` | classId, token, mcqAdmin, changedBy | PUT .../students/{token}/class-admin |
| `classes.schedule_replaced` | classId, slotCount, changedBy | PUT /classes/{id}/schedule |
| `classes.class_updated` | classId, changedBy | PUT /classes/{id} |
| `classes.class_created` | classId, createdBy | POST /classes |
| `classes.guide_saved` | levelId, languageId, changedBy | PUT /guides/{level_id} |
| `classes.student_removed` | classId, token, removedBy | POST .../students/{token}/remove |
| `classes.student_restored` | classId, token, restoredBy | POST .../students/{token}/restore |
| `classes.student_enrolled` | classId, token, addedBy (null for join and place), source (`added`, `joined`, `placed`, `bulk`) | POST .../students, POST .../students/bulk (one per enrolled or created member), POST /classes/join, POST /registrations/{id}/place |
| `classes.student_rejoined` | classId, token | POST /classes/join (a member who left) |
| `classes.student_transferred` | fromClassId, toClassId, token, type, transferredBy | POST .../students/{token}/transfer |
| `classes.class_deactivated` | classId, type, effectiveDate, auditId, removedTokens, deactivatedBy | POST /classes/{id}/deactivate |
| `classes.session_recorded` | classId, sessionId, recordedBy | POST /classes/{id}/conduction (none for a replay or a refusal) |
| `classes.session_updated` | classId, sessionId, updatedBy | PUT /classes/{id}/conduction/{session_id} |
| `classes.student_edited` | classId, token, editedBy | PUT /classes/{id}/students/{token} (the class note; the email and contact events belong to identity and membership) |

  Consumed: none. PHP's push, WhatsApp and search-outbox touches on enrolment changes are not sent (conduction sends nothing in PHP either): the outbox row is the hand-off. The admin audit row PHP writes for privileged callers (manage, update, create, bulk add) is platform's published command, called through `ClassGuards.LogAdminAccessAsync` right after the permission check.

## Published commands this domain uses

| Command | Owner | Used by |
|---|---|---|
| `PlatformCommands.RecordAdminAccessAsync` | platform | manage, update, create, bulk add |
| `MembershipCommands.RecordAcceptedRegistrationAsync` | membership | add, join, place, bulk add (through `Enrolment.AddAsync`) |
| `MembershipCommands.ChangeContactAsync` | membership | edit a student |
| `MembershipCommands.CreateProfileAsync` | membership | bulk add |
| `IdentityCommands.CreateMemberAsync` | identity | bulk add |
| `IdentityCommands.ChangeEmailAsync` | identity | edit a student |

## Public routes (no sign-in), and why

`GET /join/{code}` is `security: []` in `api.yaml` (domains/CLAUDE.md rule 4): the app shows the class a join link names before sign-in (PHP's reason, kept). It returns only name, level, language, gender and open, never the teacher, counts or ids, and is limited to 30 calls a minute per client address (`MemberRateLimit`, in memory; `ClientAddress` is PHP's `client_ip`).

## Checks

```
dotnet test domains/classes/api/tests   # the model: the 16 tables in schema "classes"
dotnet test db/tests                    # the migrated database: citext, no cross-schema key, the limited role's rights
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_classes` | id, code, name, class_level_id, gender, teacher, status, city, country | access (scopes), membership (waiting list, gender lock), assessment reports |
| `v_enrolments` | id, class_id, token_no, status, removed_at, mcq_admin | access (mcq scope), membership (placed, gender lock), assessment reports |
