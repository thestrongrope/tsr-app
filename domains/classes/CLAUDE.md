# domains/classes/

Classes, levels, tags, schedules, sessions, attendance, enrolment, teachers, syllabus and guides.

## Status

**Tables and placeholder routes (2026-11-10).** No slices and no public interface yet: every operation of this domain is a 501 placeholder in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `classes`, 16 tables: `classes`, `class_levels`, `tags`, `class_tags`, `class_schedules`, `topics`, `class_schedule_topics`, `class_sessions`, `class_attendance`, `class_students` (enrolment), `student_transfers`, `class_audit_log`, `teachers`, `teachers_history`, `syllabus`, `guides` | built; migration `Initial` |
| Port `IClassScopes` (access) and `IClassEnrolments` (membership), supplied from here | not yet: access and membership use their defaults |
| PHP's trigger on `classes` (the share `link`) | not ported: the slice that creates a class will set it |

## Owns

- Schema `classes` (above). Column names follow PHP's, so the data move is a copy. Keys that name a member, gender, language or another domain's row are plain
  integers; the one foreign key (`syllabus` to `class_levels`) stays inside the schema. A session's day (`conducted_on`) and the class dates are `date`.
- `classes.city` and `classes.country` (the columns access rules match) use the ICU collation `public.geo_ci_ai` (case and accent insensitive, as MariaDB's
  was), declared by platform's migration. Every other text column is `citext` with a length CHECK.
- Dependencies: none (`ClassesModule.Dependencies` is empty). Register it after platform (`Program.cs`): its migration uses platform's collation.
- Events: none published, none consumed.

## Checks

```
dotnet test domains/classes/api/tests   # the model: the 16 tables in schema "classes"
dotnet test db/tests                    # the migrated database: citext, no cross-schema key, the limited role's rights
```
