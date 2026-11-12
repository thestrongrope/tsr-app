# domains/assessment/

Spot quizzes, standard MCQs, quiz competitions.

## Status

**Tables and 9 built operations (batch A1, 2026-11-12): a member takes a quiz and reads scores.** Built: `GET /classes/{class_id}/mcq/quizzes`, `GET /mcq/open`, `GET /mcq/by-code/{code}`, `GET /mcq/quizzes/{quiz_id}`, `/questions`, `POST /mcq/quizzes/{quiz_id}/responses` (the one write), `GET /mcq/quizzes/{quiz_id}/my-score`, `GET /classes/{class_id}/my-scores`, `GET /me/children/{child_token}/classes/{class_id}/scores` (one folder each under `api/features/`: `class-quizzes`, `open-quizzes`, `quiz-by-code`, `quiz-detail`, `quiz-questions`, `quiz-submit`, `quiz-my-score`, `class-my-scores`, `child-scores`; contract `spec/tests/<slice>.hurl`, shapes in `spec/api.yaml`). Shared: `domain/QuizRules.cs` (scoring, the correct option, the by-code state machine; unit tested), `QuizAccess.cs` (visible quiz, attempt, enrolment, gender), `AnswerBody.cs`, `QuizResult.cs`, `ScoreRows.cs` (the per-response date rule), `Paging.cs`, `Refusals.cs`. Run the contract with `tools/assessment-contract.sh test|parity` (fixtures `db/synthetic/assessment-a1-fixtures.sql` and `tools/parity-php/assessment-a1-fixtures.sql`, tokens 902401 to 902499, classes 9621 to 9624, quizzes 962401 to 962499, reset on every run); db tests `db/tests/AssessmentA1Tests.cs`; notes (PHP facts, quirks, what each route exposes): `docs/specs/initial-build/assessment-a1-notes.md`. The other 34 operations (manage, copy, publish, offline, sheet, reports, admin quiz, standard MCQs) are 501 placeholders in `api/Planned.cs` (catalog: `docs/specs/initial-build/operations.csv`). Facts and decisions:
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `assessment`, 8 tables: `spot_quizzes`, `spot_quiz_questions`, `spot_quiz_submissions`, `spot_quiz_responses`, `standard_mcqs`, `standard_mcq_questions`, `quiz_campaigns` (migration `Initial`), `quiz_state` (migration `QuizState`) | built |
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

## Google Sheets, quiz state, locks, settings (lane sheets, build-out)

- `domain/ISheets.cs` is the one boundary to Google Sheets (read a range, write a range); `GoogleSheets.cs` calls the REST API over HTTP with a service-account JWT (no SDK). Optional settings (the API starts without them; a sheet route then answers 502 or "could not be read"): `TSR_GOOGLE_SERVICE_ACCOUNT_B64` (base64 service-account JSON, never logged) and `TSR_QUIZ_SETTINGS_SHEET_ID` (PHP `QUIZ_SETTINGS_GOOGLE_SHEET_ID`).
- Built: `GET /standard-mcqs/sources`, `POST /standard-mcqs/update` (slices `standard-mcq-sources`, `standard-mcq-update`; saved level is the chosen id + 1, as PHP) and the quiz admin: `GET /admin/quiz`, `POST /admin/quiz/settings/refresh`, `/download`, `/winners/generate`, `/winners/regenerate`, `/publish`, `/reset` (slices `admin-quiz*`; shared rules in `domain/Quiz*.cs`: `QuizSettings`, `QuizEligibility`, `QuizDraw` with the `IQuizRandom` seam, `QuizDrawFlow`, `QuizOverview`, `QuizAdmin`, `QuizStateStore`).
- Table `quiz_state(name pk, document jsonb, updated_at)` (migration `QuizState`) replaces PHP's JSON files: documents `settings`, `participants`, `quiz_day`, `timestamps`, `scoreboard`, `winners`, `winners_replaced` (append only; the archive). Reset clears five (scoreboard, quiz_day, timestamps, winners, participants). Member data (names, tokens, cities) lives only in these documents and the responses; never in logs or events.
- Advisory locks (transaction-level, single bigint key, `domain/AssessmentLocks.cs`; membership's 3001 is the two-key form): 5001 standard MCQ update, 5002 quiz admin (PHP `quiz_admin`). No other code may use 5001 to 5099.
- Events: `assessment.standard_mcqs_updated` {languageId, levelId, quizzes} (one per updated pair); `assessment.quiz_state_changed` {action: settings_refresh|download|generate|regenerate|publish|reset}.
- Dependencies added: `notifications` (`NotificationsCommands.AnnounceAsync`, written by the settings refresh when a quiz goes live). Reads through views: `membership.v_members` (name, city, country), `classes.v_enrolments` and `classes.v_classes` (enrolled students).
- Notes for the test phase: `docs/specs/initial-build/lane-sheets-notes.md`.

## Checks

```
dotnet test domains/assessment/api/tests   # the model: the 8 tables in schema "assessment"
dotnet test db/tests                       # the migrated database and the A1 routes (AssessmentA1Tests)
tools/assessment-contract.sh test          # Hurl on the test stack (parity: the same files on PHP)
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quizzes` | quiz_id, class_id, topic, published_at, max_marks (every quiz, answered or not; migration `QuizTopics`) | classes (student figures) |
| `v_quiz_results` | class_id, token, quiz_id, published_at, correct, max_marks, answered (the member's response count), answered_at (their first response's time), topic (migration `QuizTopics`); migration `QuizResultsAnswered` | classes (my and child performance, roster, student reports) |
| `v_standard_mcqs` | code, level_id, language_id (standard MCQs not deleted; migration `McqAdherenceViews`) | classes (pending report) |
| `v_class_mcq_copies` | class_id, mcq_code, quiz_id (the latest copy), published_at (the latest publish time); one row per standard MCQ per class, deactivated copies left out; migration `McqAdherenceViews` | classes (pending report) |
