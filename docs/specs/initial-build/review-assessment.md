# Review: assessment (manage quizzes, scores and publish, standard MCQ update, quiz competition admin)

Independent, read-only review (Opus, `security` agent) of `dotnet-11` at `8e04e3b`, against `build/parity-php/src/web`, by the brief in `review-brief.md`. Received 12 Nov 2026. The reviewer ran gitleaks over `domains/assessment` (0 findings) and no build, test, database or network call. Saved as received; see "Follow-up" at the end.

**Verdict:** no authorization, row-scope, data-exposure, injection or irreversible-action hole. One should-fix (A1): a quiz admin publish that writes to the sheet but reports that nothing was published.

## Should-fix

**A1. `POST /admin/quiz/publish` with an empty scoreboard or no daily winners.**
- Where: `domains/assessment/api/features/admin-quiz-publish/AdminQuizPublish.cs:200` and `:95`.
- What happens: line 200 turns the empty list into one empty row and writes it to the public sheet (for `what: scoreboard` the "Last updated on …" line too). Line 95 then sees `Rows == 0` and answers "Nothing was published: the sheet range for this winner is not set in the quiz settings." with `changed: false`; it saves no timestamp, writes no `quiz_state_changed` event, and the transaction is disposed without a commit.
- Result: an outward write with no audit trail, and the admin is told the wrong reason.
- PHP: `models/quizadmin.php:548` returns `published => $what !== 'mega_student' || $rows > 0`, so scoreboard and winners with 0 rows give "Published 0 rows." with `changed: true` and the timestamps saved (`:2152`, `:2194-2197`).
- Fix direction: apply the "Nothing was published" path only to `mega_student` with no range set.
- Reviewer: high (read both sides). No test covers an empty scoreboard or empty winners.

## Notes

- A2. A second notification from a retry after an error: `features/manage-publish/ManagePublish.cs:94` catches only `DbException`. The publish has already committed (`:69-81`); any other exception from the announcement gives a 500, the teacher retries, and that writes a second notification plus inbox rows for every student. PHP catches `Throwable` (`routes/mcq_admin.php:335`). Low confidence: the announcement command mostly throws database errors.
- A3. A database transaction held across Google calls: `AdminQuizDownload.cs:44-55` (up to 30 episode reads at 30 s each), `StandardMcqUpdate.cs:85-91`, `AdminQuizPublish.cs:73-90`. Each opens a transaction and takes advisory lock 5002 or 5001 before the Google calls, so a slow Google API can keep a pooled connection idle in a transaction for minutes. PHP held a named lock across the same calls, but no open transaction. Operational, not security.
- A4 (needs validation). Download (`:37`), publish (`:58`) and the draw (`QuizDrawFlow.cs:42`) read the settings before `TryTakeAsync`; a settings refresh landing in between means the action runs on the old settings. Whether PHP reads the settings inside `locked()` was not checked.
- A5. `spot_quiz_submissions` has no unique (quiz, token) index; two simultaneous offline saves on a quiz with no questions can both insert a submission row. Harmless; matches PHP.
- A6. `ManageAccess.cs:62` compares `ClassStatus == "A"` in C# (case-sensitive) while `ActiveClassAsync` (`:38`) compares in SQL against citext. Stricter than PHP; reachable only if a lowercase 'a' status exists.

## Checked and ruled out

- Every manage route: caller, quiz or class (404), then `mcqs:manage` or `mcqs:copy` on the quiz's own `class_id` from the database, never a body field; matches `mcq_admin.php` route for route. Copy checks the source class, then the target class.
- Offline save: every token must be a current student of the quiz's class (`OfflineBatch.cs:79`), every question id must belong to this quiz (`:88`), the correct answer comes from the database, the batch is one transaction, and the unique responses index catches a phone answer (`mcq.php:1348-1430`).
- Update accepts no question ids; it replaces all questions in one transaction after the row lock taken by the UPDATE.
- Answer key, scores and offline screen: reachable only after `mcqs:manage`.
- Quiz code: `RandomNumberGenerator`, 36^8 combinations; the race is as PHP's. Guessing through `GET /mcq/by-code` was not reviewed (the route predates this change).
- SQL: all parameterised; text comparisons cast with `::citext`.
- Sheet PDF: every value goes through `WebUtility.HtmlEncode` (`QuizSheet.cs`).
- Google Sheets: the spreadsheet id and range come only from configuration or the settings sheet, never the request body, and pass through `Uri.EscapeDataString` on a fixed host; writes use `valueInputOption=RAW` as PHP (`functions.php:980`); a missing `TSR_GOOGLE_SERVICE_ACCOUNT_B64` becomes a `SheetsException`, then a 502 or a "failed" result; exception messages hold only HTTP statuses; 30 s timeout, 50,000-row cap.
- Winners draw: a cryptographic random source (`CryptoQuizRandom`).
- Admin guards: every admin route asks `quiz:admin`, reset also `quiz:reset`, the standard MCQ routes `standard-mcqs:update`; tested in `TestSheetsQuizTests.cs:579-584` and `TestSheetsTests.cs:321-323`.
- Bounds: 500 questions, 500 students × 5000 ids, 20 language and level ids, 30 episodes, 5000-row reads.
- Secrets and dependencies: test PEMs are generated at run time; no new packages.
- The hard delete in `StandardMcqUpdate.cs:219-225` is PHP's (`mcq.php:~410-425`).

## PHP looseness that was copied

- Publish again: no check for questions, deactivation or a previous publish; each publish adds a new notification and inbox rows, but no second push.
- PUT replaces the questions of a published or answered quiz, which orphans the stored answers.
- Scores are grouped by the student's name, so two students with the same name become one row.
- `CopyQuizzes` puts the caller's text into `LIKE`, so `topic=%` lists every quiz of the class (only for someone allowed to copy from it).
- Standard copy has no duplicate rule; it copies deleted standards and every question whose `mcq_code` matches, across language and level pairs.
- No unique index on the quiz code.
- GET `/sheet` writes the option order.
- The public sheet gets each winner's token, name and city.
- The settings sheet chooses which spreadsheets and ranges the service account writes to.
- Offline answers are accepted for unpublished or deactivated quizzes.

## Guards no test would catch if deleted (found by reading, not an exhaustive grep)

- The empty-list publish path (A1).
- In `ManagePublish.AnnounceAsync`, an exception other than a database error.
- `QuizEdit.MaxQuestions` (500) at the slice level.
- `StandardMcqUpdate` "Too many ids" (21 ids).
- `QuizSettings.MaxEpisodes` and the `validation_chunks` clamp.
- The `for update` in `ManageDeactivate` (no concurrency test).
- The `NewQuiz` throw when there is no transaction.

## Not checked by the reviewer

The `access` rules behind `mcqs:manage` and `mcqs:copy`; `QuizEligibility`, `QuizDraw` and `QuizOverview` in depth; the student routes from before `cc83a55`; the real Google wire; the build and unit tests; osv-scanner and semgrep.

## Follow-up

- A1: confirmed by a second reviewer (Opus, read-only, told to disprove it; the accepted values are scoreboard, winners, mega, mega_student), then fixed 12 Nov 2026: the "Nothing was published" answer applies only to `mega_student`. Test `TestSheetsQuizTests...REVIEW_A1` (an empty scoreboard) failed first. The empty winners list shares the line but has no test of its own (the seeded world always yields a winners row).
- A2 to A6: open.
