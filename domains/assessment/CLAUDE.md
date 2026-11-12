# domains/assessment/

Spot quizzes, standard MCQs, quiz competitions.

## Status

**Tables and 18 built operations (batch A1, then 9 of batch A2, 2026-11-12): a member takes a quiz and reads scores; a teacher or class admin manages a class's quizzes.** Built: `GET /classes/{class_id}/mcq/quizzes`, `GET /mcq/open`, `GET /mcq/by-code/{code}`, `GET /mcq/quizzes/{quiz_id}`, `/questions`, `POST /mcq/quizzes/{quiz_id}/responses` (the one write), `GET /mcq/quizzes/{quiz_id}/my-score`, `GET /classes/{class_id}/my-scores`, `GET /me/children/{child_token}/classes/{class_id}/scores` (one folder each under `api/features/`: `class-quizzes`, `open-quizzes`, `quiz-by-code`, `quiz-detail`, `quiz-questions`, `quiz-submit`, `quiz-my-score`, `class-my-scores`, `child-scores`; contract `spec/tests/<slice>.hurl`, shapes in `spec/api.yaml`). Shared: `domain/QuizRules.cs` (scoring, the correct option, the by-code state machine; unit tested), `QuizAccess.cs` (visible quiz, attempt, enrolment, gender), `AnswerBody.cs`, `QuizResult.cs`, `ScoreRows.cs` (the per-response date rule), `Paging.cs`, `Refusals.cs`. Run the contract with `tools/assessment-contract.sh test|parity` (fixtures `db/synthetic/assessment-a1-fixtures.sql` and `tools/parity-php/assessment-a1-fixtures.sql`, tokens 902401 to 902499, classes 9621 to 9624, quizzes 962401 to 962499, reset on every run); db tests `db/tests/AssessmentA1Tests.cs`; notes (PHP facts, quirks, what each route exposes): `docs/specs/initial-build/assessment-a1-notes.md`. **Batch A2 (manage and copy picker), built: 9 of its 12.** `GET /classes/{class_id}/mcq/manage` (`manage-list`), `/classes/{class_id}/mcq/topics` (`manage-topics`), `/classes/{class_id}/mcq/standard` (`manage-standard`), `GET` and `PUT /mcq/manage/{quiz_id}` (`manage-quiz`, `manage-update`), `POST /mcq/manage/{quiz_id}/deactivate` (`manage-deactivate`), `GET /mcq/copy/classes` (`copy-classes`), `/mcq/copy/classes/{class_id}/topics` (`copy-topics`) and `.../quizzes` (`copy-quizzes`); shared `domain/ManageAccess.cs` (the active class, the quiz with its class, `mcqs:manage` and `mcqs:copy` on a class, the link, the topics) and `QuizEdit.cs` (the body rules of an edit, unit tested). The manage routes are for the class teacher, a current class admin student and a super admin; the copy routes are NOT for teachers or class admins (a super admin, a gender admin, a coordinator). `GET /mcq/manage/{quiz_id}` carries the answer key: it is refused before any read to everyone else (db tests pin it). Contract files `spec/tests/manage-*.hurl`, `copy-*.hurl` (fixtures `db/synthetic/assessment-a2-fixtures.sql`, `tools/parity-php/assessment-a2-fixtures.sql`: tokens 902501 to 902512, classes 9631 to 9637, quizzes 963401 and up, standard MCQs `A2S-*`), db tests `db/tests/AssessmentA2Tests.cs`, notes `docs/specs/initial-build/assessment-a2-notes.md`.
**NOT BUILT, BLOCKED: create (`POST /classes/{class_id}/mcq`), copy a standard MCQ and copy between classes (`POST /mcq/manage/{quiz_id}/copy`).** They insert quizzes and need the random unique `code` PHP's trigger makes, with a unique index to retry on; the new schema has NO unique (or any) index on `spot_quizzes.code`, and neither had PHP (the trigger checks with a racy NOT EXISTS). Adding it is a schema change on a table that may hold duplicate or empty codes in real data: owner's decision (notes: the proposal).
The other 25 operations (create and copy from the batch above, publish, scores, offline, sheet, reports, admin quiz, standard MCQs update) are 501 placeholders in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `assessment`, 7 tables: `spot_quizzes`, `spot_quiz_questions`, `spot_quiz_submissions`, `spot_quiz_responses`, `standard_mcqs`, `standard_mcq_questions`, `quiz_campaigns` | built; migration `Initial` |
| PHP's trigger on `spot_quizzes` (an 8 character base 36 `code` on insert, any supplied value ignored) | not ported, and BLOCKED: no unique index on `code` in the new schema (see Status) |

## Owns

- Schema `assessment` (above). Names, keys and indexes follow PHP's. A class, level, language, topic or member is a plain integer (another domain's row);
  PHP declared no foreign key between these tables. `spot_quiz_questions.is_arabic` (a `bit(1)`) is `boolean`; the tinyint flags are `smallint`.
- Dependencies: `access` (`Permissions`; `AssessmentModule.Dependencies`). Other domains are read through their published views in SQL: `classes.v_enrolments` (enrolment), `classes.v_classes` (class code, status, level name and order, city, gender, language), `membership.v_members` (the member's gender), `membership.v_guardian_links` (a parent's link). No public interface.
- Events (outbox, in the transaction of the change; no consumer):

| Event | Payload | Written by |
|---|---|---|
| `assessment.quiz_answered` | quizId, classId, token (never the answers) | POST /mcq/quizzes/{quiz_id}/responses (none for a refusal or a lost race) |
| `assessment.quiz_updated` | quizId, classId, token (no text, no answers) | PUT /mcq/manage/{quiz_id} (every successful save; none for a refusal) |
| `assessment.quiz_deactivated` | quizId, classId, token, deactivated (true or false) | POST /mcq/manage/{quiz_id}/deactivate, only when the state changes (a repeat writes the row as PHP does but no event) |
| `assessment.quiz_created` | (planned: quizId, classId, token, source new, standard or copy) | the blocked create and copy routes |

  Consumed: none. The answers are never in the key-less routes: the questions route never selects the answer column; only the caller's own answered quizzes show the correct text.

## Checks

```
dotnet test domains/assessment/api/tests   # the model: the 7 tables in schema "assessment"
dotnet test db/tests                       # the migrated database and the A1 and A2 routes (AssessmentA1Tests, AssessmentA2Tests)
tools/assessment-contract.sh test          # Hurl on the test stack (parity: the same files on PHP)
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quizzes` | quiz_id, class_id, topic, published_at, max_marks (every quiz, answered or not; migration `QuizTopics`) | classes (student figures) |
| `v_quiz_results` | class_id, token, quiz_id, published_at, correct, max_marks, answered (the member's response count), answered_at (their first response's time), topic (migration `QuizTopics`); migration `QuizResultsAnswered` | classes (my and child performance, roster, student reports) |
| `v_standard_mcqs` | code, level_id, language_id (standard MCQs not deleted; migration `McqAdherenceViews`) | classes (pending report) |
| `v_class_mcq_copies` | class_id, mcq_code, quiz_id (the latest copy), published_at (the latest publish time); one row per standard MCQ per class, deactivated copies left out; migration `McqAdherenceViews` | classes (pending report) |
