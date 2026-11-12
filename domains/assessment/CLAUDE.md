# domains/assessment/

Spot quizzes, standard MCQs, quiz competitions.

## Status

**Tables and 27 operations with a slice (12 Nov 2026): batch A1 and 9 of batch A2 are proven against PHP; the standard MCQ routes and the quiz competition admin (lane sheets) are proven up to the Google boundary (Hurl on PHP and the new API, database tests with a fake Sheets client; the real Google client is unverified, see `docs/specs/initial-build/test-sheets-notes.md`).** A1 and A2: a member takes a quiz and reads scores; a teacher or class admin manages a class's quizzes.** Built: `GET /classes/{class_id}/mcq/quizzes`, `GET /mcq/open`, `GET /mcq/by-code/{code}`, `GET /mcq/quizzes/{quiz_id}`, `/questions`, `POST /mcq/quizzes/{quiz_id}/responses` (the one write), `GET /mcq/quizzes/{quiz_id}/my-score`, `GET /classes/{class_id}/my-scores`, `GET /me/children/{child_token}/classes/{class_id}/scores` (one folder each under `api/features/`: `class-quizzes`, `open-quizzes`, `quiz-by-code`, `quiz-detail`, `quiz-questions`, `quiz-submit`, `quiz-my-score`, `class-my-scores`, `child-scores`; contract `spec/tests/<slice>.hurl`, shapes in `spec/api.yaml`). Shared: `domain/QuizRules.cs` (scoring, the correct option, the by-code state machine; unit tested), `QuizAccess.cs` (visible quiz, attempt, enrolment, gender), `AnswerBody.cs`, `QuizResult.cs`, `ScoreRows.cs` (the per-response date rule), `Paging.cs`, `Refusals.cs`. Run the contract with `tools/assessment-contract.sh test|parity` (fixtures `db/synthetic/assessment-a1-fixtures.sql` and `tools/parity-php/assessment-a1-fixtures.sql`, tokens 902401 to 902499, classes 9621 to 9624, quizzes 962401 to 962499, reset on every run); db tests `db/tests/AssessmentA1Tests.cs`; notes (PHP facts, quirks, what each route exposes): `docs/specs/initial-build/assessment-a1-notes.md`. **Batch A2 (manage and copy picker), built: 9 of its 12.** `GET /classes/{class_id}/mcq/manage` (`manage-list`), `/classes/{class_id}/mcq/topics` (`manage-topics`), `/classes/{class_id}/mcq/standard` (`manage-standard`), `GET` and `PUT /mcq/manage/{quiz_id}` (`manage-quiz`, `manage-update`), `POST /mcq/manage/{quiz_id}/deactivate` (`manage-deactivate`), `GET /mcq/copy/classes` (`copy-classes`), `/mcq/copy/classes/{class_id}/topics` (`copy-topics`) and `.../quizzes` (`copy-quizzes`); shared `domain/ManageAccess.cs` (the active class, the quiz with its class, `mcqs:manage` and `mcqs:copy` on a class, the link, the topics) and `QuizEdit.cs` (the body rules of an edit, unit tested). The manage routes are for the class teacher, a current class admin student and a super admin; the copy routes are NOT for teachers or class admins (a super admin, a gender admin, a coordinator). `GET /mcq/manage/{quiz_id}` carries the answer key: it is refused before any read to everyone else (db tests pin it). Contract files `spec/tests/manage-*.hurl`, `copy-*.hurl` (fixtures `db/synthetic/assessment-a2-fixtures.sql`, `tools/parity-php/assessment-a2-fixtures.sql`: tokens 902501 to 902512, classes 9631 to 9637, quizzes 963401 and up, standard MCQs `A2S-*`), db tests `db/tests/AssessmentA2Tests.cs`, notes `docs/specs/initial-build/assessment-a2-notes.md`.
**Lane quiz-writes (build-out, 12 Nov 2026), ported from PHP and not yet proven: the last eight routes, so the whole MCQ surface is built (no `Planned.cs`).** `POST /classes/{class_id}/mcq` (`manage-create`), `POST /classes/{class_id}/mcq/standard/{mcq_id}/copy` (`manage-standard-copy`), `POST /mcq/manage/{quiz_id}/copy` (`manage-copy`), `GET /mcq/manage/{quiz_id}/scores` (`manage-scores`), `GET` and `POST /mcq/manage/{quiz_id}/offline` (`manage-offline`, `manage-offline-save`), `GET /mcq/manage/{quiz_id}/sheet` (`manage-sheet`: PDF through platform's `ReportExport.DownloadPageAsync`), `POST /mcq/manage/{quiz_id}/publish` (`manage-publish`: notifications' `AnnounceCountedAsync`). Shared in `domain/`: `QuizCode` and `NewQuiz` (the quiz code and the one insert), `OptionOrder`, `ClassStudents`, `OfflineBatch`, `QuizSheet`, `DuplicateAnswer`. Scores, the offline screen and the sheet show the answer key or students' scores: reachable only after `mcqs:manage`. Notes (PHP facts, assumptions, flags, test checklist): `docs/specs/initial-build/lane-quiz-writes-notes.md`.
`docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md`.

| Part | State |
|---|---|
| Schema `assessment`, 8 tables: `spot_quizzes`, `spot_quiz_questions`, `spot_quiz_submissions`, `spot_quiz_responses`, `standard_mcqs`, `standard_mcq_questions`, `quiz_campaigns` (migration `Initial`), `quiz_state` (migration `QuizState`) | built |
| PHP's trigger on `spot_quizzes` (an 8 character base 36 `code` on insert, any supplied value ignored) | ported as PHP has it in `domain/QuizCode.cs` and `NewQuiz.cs`: cryptographic draw, `not exists` check in the insert's transaction, up to 20 draws. Racy exactly as PHP's; NO unique index (a decision for the test phase) |

## Owns

- Schema `assessment` (above). Names, keys and indexes follow PHP's. A class, level, language, topic or member is a plain integer (another domain's row);
  PHP declared no foreign key between these tables. `spot_quiz_questions.is_arabic` (a `bit(1)`) is `boolean`; the tinyint flags are `smallint`.
- Dependencies: `access` (`Permissions`), `notifications` (the announcement command), `platform` (`ReportExport`, the PDF of a sheet) (`AssessmentModule.Dependencies`). Other domains are read through their published views in SQL: `classes.v_enrolments` (enrolment), `identity.v_users` (a student's email),  `classes.v_classes` (class code, status, level name and order, city, gender, language), `membership.v_members` (the member's gender), `membership.v_guardian_links` (a parent's link). No public interface.
- Events (outbox, in the transaction of the change; no consumer):

| Event | Payload | Written by |
|---|---|---|
| `assessment.quiz_answered` | quizId, classId, token (never the answers) | POST /mcq/quizzes/{quiz_id}/responses (none for a refusal or a lost race) |
| `assessment.quiz_updated` | quizId, classId, token (no text, no answers) | PUT /mcq/manage/{quiz_id} (every successful save; none for a refusal) |
| `assessment.quiz_deactivated` | quizId, classId, token, deactivated (true or false) | POST /mcq/manage/{quiz_id}/deactivate, only when the state changes (a repeat writes the row as PHP does but no event) |
| `assessment.quiz_created` | quizId, classId (the class of the new quiz), token, source (new, standard or copy) | POST /classes/{class_id}/mcq, .../standard/{mcq_id}/copy, POST /mcq/manage/{quiz_id}/copy |
| `assessment.offline_answers_recorded` | quizId, classId, token, count (students saved; no names, answers or scores) | POST /mcq/manage/{quiz_id}/offline (none for a refusal or a rolled back batch) |
| `assessment.quiz_published` | quizId, classId, token | POST /mcq/manage/{quiz_id}/publish |

  Consumed: none. The answers are never in the key-less routes: the questions route never selects the answer column; only the caller's own answered quizzes show the correct text.

## Google Sheets, quiz state, locks, settings (lane sheets, build-out)

- `domain/ISheets.cs` is the one boundary to Google Sheets (read a range, write a range); `GoogleSheets.cs` calls the REST API over HTTP with a service-account JWT (no SDK). Optional settings (the API starts without them; a sheet route then answers 502 or "could not be read"): `TSR_GOOGLE_SERVICE_ACCOUNT_B64` (base64 service-account JSON, never logged) and `TSR_QUIZ_SETTINGS_SHEET_ID` (PHP `QUIZ_SETTINGS_GOOGLE_SHEET_ID`).
- Built: `GET /standard-mcqs/sources`, `POST /standard-mcqs/update` (slices `standard-mcq-sources`, `standard-mcq-update`; saved level is the chosen id + 1, as PHP) and the quiz admin: `GET /admin/quiz`, `POST /admin/quiz/settings/refresh`, `/download`, `/winners/generate`, `/winners/regenerate`, `/publish`, `/reset` (slices `admin-quiz*`; shared rules in `domain/Quiz*.cs`: `QuizSettings`, `QuizEligibility`, `QuizDraw` with the `IQuizRandom` seam, `QuizDrawFlow`, `QuizOverview`, `QuizAdmin`, `QuizStateStore`).
- Table `quiz_state(name pk, document jsonb, updated_at)` (migration `QuizState`) replaces PHP's JSON files: documents `settings`, `participants`, `quiz_day`, `timestamps`, `scoreboard`, `winners`, `winners_replaced` (append only; the archive). Reset clears five (scoreboard, quiz_day, timestamps, winners, participants). Member data (names, tokens, cities) lives only in these documents and the responses; never in logs or events.
- Advisory locks (transaction-level, single bigint key, `domain/AssessmentLocks.cs`; membership's 3001 is the two-key form): 5001 standard MCQ update, 5002 quiz admin (PHP `quiz_admin`). No other code may use 5001 to 5099.
- Events: `assessment.standard_mcqs_updated` {languageId, levelId, quizzes} (one per updated pair); `assessment.quiz_state_changed` {action: settings_refresh|download|generate|regenerate|publish|reset}.
- Dependencies added: `notifications` (`NotificationsCommands.AnnounceAsync`, written by the settings refresh when a quiz goes live, and `AnnounceCountedAsync` by a quiz publish). Reads through views: `membership.v_members` (name, city, country), `classes.v_enrolments` and `classes.v_classes` (enrolled students).
- Notes for the test phase: `docs/specs/initial-build/lane-sheets-notes.md`; what was proven and the findings settled: `docs/specs/initial-build/test-sheets-notes.md`. Contract: `tools/contract-sheets.sh test|parity`; db tests `db/tests/TestSheets*Tests.cs`. The cross-day winners check is a matching (no cap of 20 started episodes).

## Checks

```
dotnet test domains/assessment/api/tests   # the model: the 8 tables in schema "assessment"
dotnet test db/tests                       # the migrated database and the A1 and A2 routes (AssessmentA1Tests, AssessmentA2Tests)
tools/assessment-contract.sh test          # Hurl on the test stack (parity: the same files on PHP)
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quizzes` | quiz_id, class_id, topic, published_at, max_marks (every quiz, answered or not; migration `QuizTopics`) | classes (student figures, MCQ summary reports) |
| `v_quiz_results` | class_id, token, quiz_id, published_at, correct, max_marks, answered (the member's response count), answered_at (their first response's time), topic (migration `QuizTopics`); migration `QuizResultsAnswered` | classes (my and child performance, roster, student reports, MCQ summary reports) |
| `v_standard_mcqs` | code, level_id, language_id (standard MCQs not deleted; migration `McqAdherenceViews`), topic, subject, lesson, name, sort_order (migration `McqReportViews`) | classes (pending report, MCQ adherence reports) |
| `v_class_mcq_copies` | class_id, mcq_code, quiz_id (the latest copy), published_at (the latest publish time); one row per standard MCQ per class, deactivated copies left out; migration `McqAdherenceViews` | classes (pending report, MCQ adherence reports) |
