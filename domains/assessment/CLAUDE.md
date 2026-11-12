# domains/assessment/

Spot quizzes, standard MCQs, quiz competitions.

## Status

**Tables and 9 built operations (batch A1, 2026-11-12): a member takes a quiz and reads scores.** Built: `GET /classes/{class_id}/mcq/quizzes`, `GET /mcq/open`, `GET /mcq/by-code/{code}`, `GET /mcq/quizzes/{quiz_id}`, `/questions`, `POST /mcq/quizzes/{quiz_id}/responses` (the one write), `GET /mcq/quizzes/{quiz_id}/my-score`, `GET /classes/{class_id}/my-scores`, `GET /me/children/{child_token}/classes/{class_id}/scores` (one folder each under `api/features/`: `class-quizzes`, `open-quizzes`, `quiz-by-code`, `quiz-detail`, `quiz-questions`, `quiz-submit`, `quiz-my-score`, `class-my-scores`, `child-scores`; contract `spec/tests/<slice>.hurl`, shapes in `spec/api.yaml`). Shared: `domain/QuizRules.cs` (scoring, the correct option, the by-code state machine; unit tested), `QuizAccess.cs` (visible quiz, attempt, enrolment, gender), `AnswerBody.cs`, `QuizResult.cs`, `ScoreRows.cs` (the per-response date rule), `Paging.cs`, `Refusals.cs`. Run the contract with `tools/assessment-contract.sh test|parity` (fixtures `db/synthetic/assessment-a1-fixtures.sql` and `tools/parity-php/assessment-a1-fixtures.sql`, tokens 902401 to 902499, classes 9621 to 9624, quizzes 962401 to 962499, reset on every run); db tests `db/tests/AssessmentA1Tests.cs`; notes (PHP facts, quirks, what each route exposes): `docs/specs/initial-build/assessment-a1-notes.md`. The eight `/reports/mcq-summary` and `/reports/mcq-adherence` routes moved to `classes` (lane mcq-reports). The other 26 operations (manage, copy, publish, offline, sheet, admin quiz, standard MCQs) are 501 placeholders in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `assessment`, 7 tables: `spot_quizzes`, `spot_quiz_questions`, `spot_quiz_submissions`, `spot_quiz_responses`, `standard_mcqs`, `standard_mcq_questions`, `quiz_campaigns` | built; migration `Initial` |
| PHP's trigger on `spot_quizzes` (a random unique `code` on insert, any supplied value ignored) | not ported: the slice that creates a quiz will do it |

## Owns

- Schema `assessment` (above). Names, keys and indexes follow PHP's. A class, level, language, topic or member is a plain integer (another domain's row);
  PHP declared no foreign key between these tables. `spot_quiz_questions.is_arabic` (a `bit(1)`) is `boolean`; the tinyint flags are `smallint`.
- Dependencies: `access` (`Permissions`; `AssessmentModule.Dependencies`). Other domains are read through their published views in SQL: `classes.v_enrolments` (enrolment), `classes.v_classes` (class code), `membership.v_members` (the member's gender), `membership.v_guardian_links` (a parent's link). No public interface.
- Events (outbox, in the transaction of the change; no consumer):

| Event | Payload | Written by |
|---|---|---|
| `assessment.quiz_answered` | quizId, classId, token (never the answers) | POST /mcq/quizzes/{quiz_id}/responses (none for a refusal or a lost race) |

  Consumed: none. The answers are never in the key-less routes: the questions route never selects the answer column; only the caller's own answered quizzes show the correct text.

## Checks

```
dotnet test domains/assessment/api/tests   # the model: the 7 tables in schema "assessment"
dotnet test db/tests                       # the migrated database and the A1 routes (AssessmentA1Tests)
tools/assessment-contract.sh test          # Hurl on the test stack (parity: the same files on PHP)
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quizzes` | quiz_id, class_id, topic, published_at, max_marks (every quiz, answered or not; migration `QuizTopics`) | classes (student figures, MCQ summary reports) |
| `v_quiz_results` | class_id, token, quiz_id, published_at, correct, max_marks, answered (the member's response count), answered_at (their first response's time), topic (migration `QuizTopics`); migration `QuizResultsAnswered` | classes (my and child performance, roster, student reports, MCQ summary reports) |
| `v_standard_mcqs` | code, level_id, language_id (standard MCQs not deleted; migration `McqAdherenceViews`), topic, subject, lesson, name, sort_order (migration `McqReportViews`) | classes (pending report, MCQ adherence reports) |
| `v_class_mcq_copies` | class_id, mcq_code, quiz_id (the latest copy), published_at (the latest publish time); one row per standard MCQ per class, deactivated copies left out; migration `McqAdherenceViews` | classes (pending report, MCQ adherence reports) |
