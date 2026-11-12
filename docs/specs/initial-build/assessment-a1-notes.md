# Assessment batch A1 notes (12 Nov 2026): a member takes a quiz and reads scores

Groundwork: `AssessmentModule.Dependencies = ["access"]`; `domain/{QuizRules,QuizAccess,Refusals}.cs`; fixtures `db/synthetic/assessment-a1-fixtures.sql` + `tools/parity-php/assessment-a1-fixtures.sql`
(tokens 902401 to 902499, classes 9621 to 9624, city A1ville, language 9, quizzes 962401 to 962499, code `A1Q<id>`); `tools/assessment-contract.sh test|parity`; Hurl vars `auth_qz_<alias>`.
Moved to `shared/api` (a second domain needed them, D4): `PhpFloat`, `RequestBodies` (classes gets them through a global using), and the date-bound reader as `PhpDateBound` (unit tested; classes' `StudentAttendance` calls it).
No migration and no new view: enrolment is `classes.v_enrolments`, the guardian link `membership.v_guardian_links`, the member's gender `membership.v_members`, the class code `classes.v_classes`.

## Routes
### 4. GET /mcq/quizzes/{quiz_id}: `features/quiz-detail/`, `spec/tests/quiz-detail.hurl`; PHP pass, new pass
PHP mcq.php:196. Order: quizzes:take (403), gender (400), getForStudent (404 "Quiz not found"), attempt, question count.
Visible = published and the caller a current student (status A, removed_at null) of the quiz's class; deactivated is visible; the class's own status is not checked (a closed class's quiz is visible).
Exposes: id, code, name, topic (null when empty), classId, publishedAt (`Y-m-dTH:i:s`), questionCount, attempted, score (null before any answer). No question text and no answer.

### 5. GET /mcq/quizzes/{quiz_id}/questions: `features/quiz-questions/`, `domain/Paging.cs`, `spec/tests/quiz-questions.hurl` + `quiz-questions-new-api.hurl`; PHP pass, new pass; db test `AssessmentA1Tests`
PHP mcq.php:235. Order: quizzes:take (403), gender (400), the caller's score above 0 (409 "Quiz already attempted. Cannot retake."), visible (404), deactivated (409 "This quiz is not currently available"), page.
Quirk copied (PHP's own comment, :244): only a SCORE above zero blocks, so a member who scored 0 is let in (submit then refuses: any response blocks). An answered deactivated quiz is "already attempted" (the attempt check is first).
Exposes (before and after answering the same): per question id, text, isArabic (true/false/null), options (non-blank options as stored, plus "I don't know", shuffled with `Random.Shared`; "No options available" then "I don't know" unshuffled when none).
The answer number and the correct option are NOT selected from the table: the key is never on this wire (checked by a db test on the exact key list). Page/pageSize as PHP: max(1, (int)page), size 1 to 100 default 20, `abc` is 0.
Deviation: a page number beyond the SQL offset range gives PHP a fatal error page (200, HTML); here an empty page (`quiz-questions-new-api.hurl`). The question list is paged (no unbounded read), as PHP's.

### 7. GET /mcq/quizzes/{quiz_id}/my-score: `features/quiz-my-score/`, `domain/QuizResult.cs` (+ tests), `spec/tests/quiz-my-score.hurl`; PHP pass, new pass; db test
PHP mcq.php:411. Order: quizzes:take (403), gender (400), visible (404 "Quiz not found"), no response of the caller (404 "No attempt found").
Exposes the caller's own answers only: questionId, questionText, selected (always 0: the index is not stored), selectedText, correctText, isCorrect (1/0), in question order; envelope total (question count), answered (their rows), correct, percent.
The correct text is shown here because the caller has answered (it is the same row they wrote). percent = round(correct / total * 100, 2) of the DECIMAL value, a float on the wire (`75.0`); the integer 0 when the quiz has no questions (PHP's `: 0`). Empty texts are null (`str?`). Row cap 5000.
Not covered over HTTP: the zero-question case and an answer whose question was deleted (left join, questionText null): unit-tested in `QuizResult.Tests.cs` only.

### 6. POST /mcq/quizzes/{quiz_id}/responses: `features/quiz-submit/`, `domain/{AnswerBody,QuizRules}.cs` (+ tests), `spec/tests/quiz-submit.hurl` + `quiz-submit-new-api.hurl`; PHP pass, new pass; db tests (rows, event, refusals, 8 simultaneous submits)
PHP mcq.php:283. Order: quizzes:take (403), gender (400), any response of the caller (409 "Already attempted"), visible (404), deactivated (409 "This quiz is not currently available"), no questions (400 "Quiz has no questions"),
body (422 "Invalid JSON body"), `responses` missing/empty (400 "Payload requires non-empty responses"), missing or extra question ids (400, `detail` is the OBJECT `{missing, extra}`: missing in question order, extra in the order sent, ids cast with (int)), then the write.
Scoring: the selected TEXT against `option{answer}` (answer defaults to 1; outside 1 to 5 or an empty option means no right answer, stored as ''), both trimmed with PHP's trim set (space, tab, LF, CR, NUL, VT; NOT no-break space), lower-cased, compared as text, empty is wrong. No entity decoding (`&amp;` is not `&`), no numeric match (`1.0` is not `1`). Arabic untouched. `ToLowerInvariant` stands for mb_strtolower (only exotic full case mappings differ).
Write: one transaction, rows inserted in question-id order, `created_at` from the clock cut to the second, then the outbox row. The new schema has PHP's unique index (`spot_quiz_responses_question_token`, question + member); the pre-check gives 409 "Already attempted" and the index is the net for two simultaneous submits (loser: 409 "You have already submitted this quiz", its transaction rolled back: no rows, no event). The db test sends 8 at once: exactly one 200, seven 409, 3 rows, 1 event. It does not isolate which of the two 409 paths fired for the losers.
Event `assessment.quiz_answered` `{quizId, classId, token}`; none on any refusal (db test).
Exposes after answering (this is the only place the key is returned, and only for the caller's own answers): per question questionId, questionText, selected (the body's `option` as an int, 0 unless numeric), selectedText (echo), correctText, isCorrect; total, answered (= total), correct, percent (float over total).
Deviations: a NUL in selectedText is dropped; selectedText over 1000 characters is 400 (PHP: 500 "Failed to save responses"); an array or object selectedText is stored as "Array" without PHP's warning text in the body (PHP prints the warnings into the JSON). Missing/null selectedText is stored NULL (as PHP). Question read cap 5000.
Empty POST body: Hurl sends no Content-Length and the new gateway's nginx answers 400 with no body (PHP's gateway passes it); the contract uses `{}` instead. Gateway, not the slice (a request with `-d ''` reaches the slice: 400 "Payload requires non-empty responses").

### 3. GET /mcq/by-code/{code}: `features/quiz-by-code/`, `domain/QuizRules.cs` (state machine, pure, unit tested first), `spec/tests/quiz-by-code.hurl`; PHP pass, new pass; db test
PHP mcq.php:67, McqModel resolveLink (:1010), getByCode, isLinkCode. Order: quizzes:take (403) only: NO gender check (a member without gender gets the answer).
States in PHP's order: not_found (code not 1 to 32 ASCII letters/digits, or no quiz; the match ignores case: `code` is citext), not_eligible (not a current student, status A and not removed, of the quiz's class: the same answer for a draft, a deactivated or a live quiz, so a link reveals nothing more),
not_released (draft), attempted (the caller has any response, even when deactivated now), open, closed (deactivated, not answered). `quizId` only for open and attempted. A closed class's quiz is open to its students (the class status is not read).
Exposes only state and quizId (no name, topic or class). One query with `exists` subqueries; two quizzes with one code (no unique index in PHP either): the lowest id.

### 2. GET /mcq/open: `features/open-quizzes/`, `spec/tests/open-quizzes.hurl`; PHP pass, new pass; db test (25 quizzes, the limit, callers who must not see them)
PHP mcq.php:79, McqModel openForStudent (:1042). quizzes:take only (403), no gender check. Listed: published, not deactivated, the caller a current student of the quiz's class (status A, not removed) and no response of the caller; newest published first (published_at desc, id desc); limit fixed at 20.
The class code comes from `classes.v_classes` (inner join, no status filter, as PHP). Exposes per quiz: id, code, name, topic (null when empty), classCode. Body `{items: [...]}`.

### 1. GET /classes/{class_id}/mcq/quizzes: `features/class-quizzes/`, `spec/tests/class-quizzes.hurl` + `class-quizzes-new-api.hurl`; PHP pass, new pass; db test
PHP mcq.php:153, McqModel listForStudent (:1076). The one route whose permission has a class target: `quizzes:take` on the class (access's `enrolled` scope = current student, status A, not removed, of an ACTIVE class) so a student who left, one with status I, the teacher, a stranger,
another class's student, a closed class's own student and a class that does not exist are all 403 "You do not have permission to do that", never the 404 (found by running PHP first, as the advisor warned). Then gender (400), then PHP's own enrolment check (404 "Class not found or not enrolled"; behind access's check it cannot be reached over HTTP).
List: published quizzes of the class (drafts excluded, deactivated included), newest first; total counts published quizzes; page/pageSize as PHP (size 1 to 100, default 20), hasNext = offset + rows < total.
Per quiz: id, code, name, topic, classId, publishedAt, questionCount, attempted; score/total/percent are the CALLER's and null unless attempted with at least one question (score null when none; percent float round(score / questions * 100, 2) of the decimal value). A quiz with no questions that was somehow answered: attempted true, score null.
Deviation: a page number beyond PHP's SQL offset range gives PHP a fatal error page; here an empty page (`class-quizzes-new-api.hurl`).

### 8. GET /classes/{class_id}/my-scores: `features/class-my-scores/`, `domain/ScoreRows.cs` (shared with route 9), `spec/tests/class-my-scores.hurl`; PHP pass, new pass; db test
PHP mcq.php:449, McqModel getStudentScoresByClass (:1192). Order: quiz-scores:read with NO class target (403), gender (400), current student of the class (404 "Class not found or not enrolled": left, status I, teacher, stranger, other class; the class status is not read).
Body: bare array, newest attempt first (order by the member's highest response id), each quizId, quizName, topic (null when empty), attemptedAt (the last response's time `Y-m-dTH:i:s`), score (their correct count), total (the quiz's question count), percent (float, 0.0 with no questions). Drafts are not listed (published only), deactivated ones are. Row cap 5000.
Dates (quirk copied, found by probing PHP): the bounds apply to each RESPONSE's own `created_at`, a quiz is listed when one response is in the range and its score is the whole score. A bound is read as MariaDB reads a date (`PhpDateBound`; a bare date is its midnight, so `end_date=2026-02-03` excludes a response at 11:00 that day).
Text MariaDB cannot read becomes the zero date there: an unreadable `start_date` bounds nothing, an unreadable `end_date` lists nothing (B1's classes routes ignore both; this is closer). Only readable forms and `abc`, `2026-13-45` were probed on PHP. A NUL byte in a date is unreadable, never reaches SQL (db test, direct to the API: nginx answers 400 to `%00` before it).
PHP crash not copied: `start_date[]=x` makes PHP answer 200 with a fatal error page; here the last value of the repeated parameter is read as text.

### 9. GET /me/children/{child_token}/classes/{class_id}/scores: `features/child-scores/`, `spec/tests/child-scores.hurl`; PHP pass, new pass; db test
PHP children.php:117, GuardiansModel getChildScores (:939), isActiveGuardian, isChildEnrolled. children-performance:read (403), NO gender check; then one 404 "Child or class not found" unless an ACTIVE link from the caller to the child (`membership.v_guardian_links`, status active, tokens above 0) AND any enrolment row of the child in the class (`classes.v_enrolments`, status and removal not read; same two checks as classes' child routes, re-written here over the views).
Quirk copied and flagged: a child REMOVED from the class still passes (200, usually an empty list) and a closed class passes. A parent whose link was revoked, a parent of another child, a stranger, the child itself and a teacher get the 404.
Body: bare array, newest attempt first, snake_case: quiz_id, quiz_name, score, total_questions, percentage (float, ONE decimal place, 0.0 with no questions), attempted_on (`Y-m-d H:i:s` with a space, empty text when none). The same rows and the same per-response date rule as route 8 (`ScoreRows`).
Not tested over HTTP: the 403 (every signed-in member holds children-performance:read) and "a parent with no gender gets 200" (no fixture parent without gender).

## Event
`assessment.quiz_answered` `{quizId, classId, token}` written by POST /mcq/quizzes/{quiz_id}/responses in the transaction of the answers; no consumer; no answers in the payload.

## Migrations and views
None. Read through `classes.v_enrolments`, `classes.v_classes` (class code), `membership.v_members` (gender), `membership.v_guardian_links`. The published assessment views are untouched.

## Deferred
- `PhpFloat`, `RequestBodies` moved to `shared/api` and the date reader added as `PhpDateBound` (classes now calls it); classes' own copies of the `(int)` query reader and gender check remain separate from assessment's.
- `mb_strtolower` full case mapping (final sigma and similar) is not reproduced; `ToLowerInvariant` is used.
- The empty-body POST through the new gateway (see route 6), and a NUL in a path or query through nginx (400 there, before the API), are gateway behaviour.
- The other assessment routes (manage, copy, publish, offline, sheet, reports, admin quiz, standard MCQs) stay planned.

## Process slips
- `QuizResult` and `AnswerBody` unit tests were written after the code (they passed first time, so no red run); `QuizRules`, `PhpDateBound` were written test first and seen red on assertions.
- For routes 4 and 5 the first red (501) run was on the new side before the rebuild of the test stack, for the later routes too; the 501 red of each route is the first new-side run.
- I did not isolate which 409 path (the pre-check or the unique index) answered the losers in the 8-way concurrent db test; both give 409 and the rows and the event are asserted. I did not prove the tests by removing a line.
- Guessed `/classes/{id}/mcq/quizzes` would be 404 for non-students; PHP says 403 (access), found only by running PHP first.

## Review and fixes (main thread, 12 Nov 2026)

- Review verdict: no answer-key leak, no access hole looser than PHP, no double-submission flaw. The questions response never selects the answer and shuffles per request; the correct text appears only in the caller's own submit reply and my-score; the unique index (question, token) holds "answer once" and the loser gets 409.
- Fixed (unit tests red first, a FormatException): a date written in another script's digits (for example Arabic-Indic) passed `\d` and then threw in `int.Parse`: a 500 on my-scores and child scores, and already on the four classes date-bound routes, on class update (`startedOn` and the other dates) and on students/performance. `PhpDateBound`, `ClassUpdate.DateShape` and `ClassStudentsPerformance.DateShape` now use `[0-9]`. `class-update.hurl` has the case (runs on PHP too).
- Tightened: `AssessmentA1Tests.A_refusal_writes_no_response_and_no_event` pinned only "some 4xx"; each attempt is now pinned to its status and message (404 draft and not-enrolled, 409 deactivated, 409 already attempted, 400 missing/extra/too long, 422 bad JSON), so removing a guard fails its line.
- PHP looseness copied, to decide later: one throwaway submission returns the whole answer key, which a member can then share; a student who scored 0 can read the questions again; by-code tells a non-member whether a code exists (`not_found` versus `not_eligible`); a closed class's students can still take an open quiz (the class status is never read); a child removed from the class still passes the parent's check.
- Recorded, not changed: the shared date bound means "lists nothing" for an unreadable end date in the score routes and "no bound" in the classes attendance routes (MariaDB's reading not verified); a time without seconds is not read; `spot_quizzes.code` has no index (by-code scans); the current-student predicate is written four times and the attempt sub-queries twice; `AnswerBody` and the scoring half of `QuizRules` sit in `domain/` with one user; the simultaneous-submission test mostly exercises the earlier "already attempted" check, not the unique index.
