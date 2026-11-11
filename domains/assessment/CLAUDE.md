# domains/assessment/

Spot quizzes, standard MCQs, quiz competitions.

## Status

**Tables and placeholder routes (2026-11-10).** No slices and no public interface yet: every operation of this domain is a 501 placeholder in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `assessment`, 7 tables: `spot_quizzes`, `spot_quiz_questions`, `spot_quiz_submissions`, `spot_quiz_responses`, `standard_mcqs`, `standard_mcq_questions`, `quiz_campaigns` | built; migration `Initial` |
| PHP's trigger on `spot_quizzes` (a random unique `code` on insert, any supplied value ignored) | not ported: the slice that creates a quiz will do it |

## Owns

- Schema `assessment` (above). Names, keys and indexes follow PHP's. A class, level, language, topic or member is a plain integer (another domain's row);
  PHP declared no foreign key between these tables. `spot_quiz_questions.is_arabic` (a `bit(1)`) is `boolean`; the tinyint flags are `smallint`.
- Dependencies: none (`AssessmentModule.Dependencies` is empty). Classes show quiz counts through a future assessment interface, never the tables.
- Events: none published, none consumed.

## Checks

```
dotnet test domains/assessment/api/tests   # the model: the 7 tables in schema "assessment"
dotnet test db/tests                       # the migrated database
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quiz_results` | class_id, token, quiz_id, published_at, correct, max_marks, answered (the member's response count), answered_at (their first response's time); migration `QuizResultsAnswered` | classes (my and child performance, roster, student reports) |
