# domains/assessment/

Spot quizzes, standard MCQs, quiz competitions. Owns schema `assessment`. Every route is built (no `api/Planned.cs`).

## Status

One folder per route under `api/features/`; each slice's header comment names its route, its order of checks, its PHP source and its deviations. Shapes: `spec/api.yaml`.

| Group | Slices |
|---|---|
| A member takes a quiz and reads scores | 9: `class-quizzes`, `open-quizzes`, `quiz-by-code`, `quiz-detail`, `quiz-questions`, `quiz-submit` (the one write), `quiz-my-score`, `class-my-scores`, `child-scores` |
| A teacher or class admin manages a class's quizzes | 14: `manage-*` (the sheet is a PDF through platform's `ReportExport.DownloadPageAsync`; publish calls notifications' `AnnounceCountedAsync`) |
| Copy picker | 3: `copy-classes`, `copy-topics`, `copy-quizzes` |
| Standard MCQs from Google Sheets | 2: `standard-mcq-sources`, `standard-mcq-update` |
| Quiz competition admin | 7: `admin-quiz*` |
| Quiz competition status for the app's home banner | 1: `quiz-info` (public, optional bearer) |

Not verified against a real service: the Google client. The sheet routes are proven up to the Google boundary (Hurl on PHP and the new API, database tests with a fake Sheets client; `docs/specs/initial-build/test-sheets-notes.md`).

Tables (8): `spot_quizzes`, `spot_quiz_questions`, `spot_quiz_submissions`, `spot_quiz_responses`, `standard_mcqs`, `standard_mcq_questions`, `quiz_campaigns` (migration `Initial`), `quiz_state` (migration `QuizState`). Names, keys and indexes follow PHP's. A class, level, language, topic or member is a plain integer (another domain's row); PHP declared no foreign key between these tables. `spot_quiz_questions.is_arabic` (a `bit(1)`) is `boolean`; the tinyint flags are `smallint`.

## Dependencies

`access` (`Permissions`), `notifications` (`NotificationsCommands.AnnounceAsync`, written by the settings refresh when a quiz goes live, and `AnnounceCountedAsync` by a quiz publish), `platform` (`ReportExport`) (`AssessmentModule.Dependencies`). No public interface.

Read in SQL through published views: `classes.v_enrolments` (enrolment, enrolled students), `classes.v_classes` (class code, status, level name and order, city, gender, language), `identity.v_users` (a student's email), `membership.v_members` (the member's gender, name, city, country), `membership.v_guardian_links` (a parent's link).

## Rules for this domain

- **Who may manage.** The manage routes are for the class teacher, a current class admin student and a super admin; the copy routes are NOT for teachers or class admins (a super admin, a gender admin, a coordinator). The checks are `mcqs:manage` and `mcqs:copy` on a class (`domain/ManageAccess.cs`).
- **The answer key.** `GET /mcq/manage/{quiz_id}` carries the answer key: it is refused before any read to everyone else (db tests pin it). Scores, the offline screen and the sheet show the answer key or students' scores: reachable only after `mcqs:manage`. The answers are never in the key-less routes: the questions route never selects the answer column; only the caller's own answered quizzes show the correct text.
- **An answered quiz is not edited** (owner's decision; PHP edits it and orphans the answers): `PUT /mcq/manage/{quiz_id}` answers 409. An edit locks the quiz row `for update`; every answer writer (`quiz-submit`, `manage-offline-save`) takes it `for share` first and refuses with 409 when the quiz's questions changed since it read them (`domain/QuizLock.cs`; details in the header of `manage-update`). Contract: `manage-update-new-api.hurl`, and PHP's old behaviour in `manage-update-php-only.hurl`.
- **The quiz code** is unique, stricter than PHP (owner's decision): index `spot_quizzes_code`, migration `QuizCodeUnique`. A new quiz is inserted only through `domain/NewQuiz.cs` (it replaces PHP's insert trigger: an 8 character base 36 `code`, any supplied value ignored; it draws again on a taken code). Production had no duplicate and no empty code.
- **Google Sheets** are reached only through `domain/ISheets.cs`; `GoogleSheets.cs` calls the REST API over HTTP with a service-account JWT (no SDK).
- **Standard MCQ update:** the saved level is the chosen id + 1, as PHP.
- **Quiz state.** Table `quiz_state(name pk, document jsonb, updated_at)` replaces PHP's JSON files (the documents and what a reset clears: `domain/QuizStateStore.cs`). Member data (names, tokens, cities) lives only in these documents and the responses; never in logs or events.
- **The cross-day winners check** is a matching (no cap of 20 started episodes).
- **GET /quiz/info is public** (domains/CLAUDE.md rule 4): callable signed out because the home banner shows before sign-in. It returns only what the competition shows everyone (the quiz name, dates and status), never a member's data, and a signed-in caller (an optional bearer, `MemberRoute.Optional`: a bad bearer is 401, a member is never created) only adds the participation forms and their own flags. The settings are read from the settings sheet when the saved copy is 60 seconds old (`domain/QuizSettingsRefresh.cs`, shared with the admin refresh); a busy lock or a failing sheet serves the saved copy. 60 calls a minute per client address.
- **Advisory locks** (transaction-level, single bigint key, `domain/AssessmentLocks.cs`; membership's 3001 is the two-key form): 5001 standard MCQ update, 5002 quiz admin (PHP `quiz_admin`). No other code may use 5001 to 5099.
- **Fixtures.** `tools/assessment-contract.sh` resets its fixtures on every run (the submit and edit files write rows). No two files answer the same quiz as the same member. Run its prepare LAST, after the classes one (root `CLAUDE.md`). Ids, and what each fixture member is for: the header of each fixture file.

## Settings

Both optional: the API starts without them, and a sheet route then answers 502 or "could not be read".

| Setting | Meaning |
|---|---|
| `TSR_GOOGLE_SERVICE_ACCOUNT_B64` | base64 service-account JSON, never logged |
| `TSR_QUIZ_SETTINGS_SHEET_ID` | PHP `QUIZ_SETTINGS_GOOGLE_SHEET_ID` |

## Where things are

| Need | File |
|---|---|
| The HTTP contract | `spec/api.yaml`; behaviour in `spec/tests/<slice>.hurl` (`*-new-api.hurl` run on the new API only, `*-php-only.hurl` on PHP only) |
| Rules shared by slices (each file's header says what it holds and its PHP source) | `api/domain/`: taking a quiz `QuizRules`, `QuizAccess`, `AnswerBody`, `QuizResult`, `ScoreRows`, `Paging`, `Refusals`; managing `ManageAccess`, `QuizEdit`, `QuizLock`, `QuizCode`, `NewQuiz`, `OptionOrder`, `ClassStudents`, `OfflineBatch`, `QuizSheet`, `DuplicateAnswer`; the competition `QuizSettings`, `QuizEligibility`, `QuizDraw` (the `IQuizRandom` seam), `QuizDrawFlow`, `QuizOverview`, `QuizAdmin`, `QuizStateStore`, `QuizSettingsRefresh`, `QuizInfoBody` |
| Fixtures (the same rows for PHP under the same name in `tools/parity-php/`) | `db/synthetic/assessment-a1-fixtures.sql` (member routes), `assessment-a2-fixtures.sql` (manage and copy) |
| Database tests | `db/tests/AssessmentA1Tests.cs`, `AssessmentA2Tests.cs`, `TestQuizwritesTests.cs`, `TestSheets*Tests.cs` |
| PHP facts, quirks, what each route exposes | `docs/specs/initial-build/assessment-a1-notes.md`, `assessment-a2-notes.md`, `lane-quiz-writes-notes.md`, `test-quizwrites-notes.md`, `lane-sheets-notes.md`, `test-sheets-notes.md` |
| Schema design | `docs/specs/initial-build/schema-phase-design.md`, `schema-phase-tables.csv`, `schema-phase-notes.md` |

## Checks

```
dotnet test domains/assessment/api/tests   # the model: the 8 tables in schema "assessment"
dotnet test db/tests                       # the migrated database and the routes
tools/assessment-contract.sh test          # Hurl on the test stack (parity: the same files on PHP)
tools/contract-quizwrites.sh test          # create, copy, scores, offline, sheet, publish (also parity)
tools/contract-sheets.sh test              # standard MCQs and the quiz admin (also parity)
```

## Events (outbox, in the transaction of the change; no consumer)

| Event | Payload | Written by |
|---|---|---|
| `assessment.quiz_answered` | quizId, classId, token (never the answers) | POST /mcq/quizzes/{quiz_id}/responses (none for a refusal or a lost race) |
| `assessment.quiz_updated` | quizId, classId, token (no text, no answers) | PUT /mcq/manage/{quiz_id} (every successful save; none for a refusal, including a quiz that has answers) |
| `assessment.quiz_deactivated` | quizId, classId, token, deactivated (true or false) | POST /mcq/manage/{quiz_id}/deactivate, only when the state changes (a repeat writes the row as PHP does but no event) |
| `assessment.quiz_created` | quizId, classId (the class of the new quiz), token, source (new, standard or copy) | POST /classes/{class_id}/mcq, .../standard/{mcq_id}/copy, POST /mcq/manage/{quiz_id}/copy |
| `assessment.offline_answers_recorded` | quizId, classId, token, count (students saved; no names, answers or scores) | POST /mcq/manage/{quiz_id}/offline (none for a refusal or a rolled back batch) |
| `assessment.quiz_published` | quizId, classId, token | POST /mcq/manage/{quiz_id}/publish |
| `assessment.standard_mcqs_updated` | languageId, levelId, quizzes | POST /standard-mcqs/update (one per updated pair) |
| `assessment.quiz_state_changed` | action: settings_refresh, download, generate, regenerate, publish or reset | the quiz admin writes |

Consumed: none.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quizzes` | quiz_id, class_id, topic, published_at, max_marks (every quiz, answered or not; migration `QuizTopics`) | classes (student figures, MCQ summary reports) |
| `v_quiz_results` | class_id, token, quiz_id, published_at, correct, max_marks, answered (the member's response count), answered_at (their first response's time), topic (migration `QuizTopics`); migration `QuizResultsAnswered` | classes (my and child performance, roster, student reports, MCQ summary reports) |
| `v_standard_mcqs` | code, level_id, language_id (standard MCQs not deleted; migration `McqAdherenceViews`), topic, subject, lesson, name, sort_order (migration `McqReportViews`) | classes (pending report, MCQ adherence reports) |
| `v_class_mcq_copies` | class_id, mcq_code, quiz_id (the latest copy), published_at (the latest publish time); one row per standard MCQ per class, deactivated copies left out; migration `McqAdherenceViews` | classes (pending report, MCQ adherence reports) |
