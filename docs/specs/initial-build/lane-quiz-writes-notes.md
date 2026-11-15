# Lane quiz-writes notes (12 Nov 2026, build-out): the last eight assessment routes, ported from PHP and NOT yet proven

All eight are built; `domains/assessment/api/Planned.cs` is gone (nothing is a placeholder in assessment now). No Hurl, fixture or db test was written (build-out mode). Gate: `dotnet build TsrApp.slnx` 0 warnings 0 errors; `hosts/api/tests`, `domains/assessment/api/tests`, platform's and notifications' unit tests pass.
PHP reference: `build/parity-php/src/web/` (`api/mobile/routes/mcq_admin.php`, `models/mcq.php`, `models/mcqsheet.php`, `functions.php`).

## Routes
| # | Route | PHP | Slice | Reads | Writes |
|---|---|---|---|---|---|
| 1 | POST /classes/{class_id}/mcq | mcq_admin.php:118, McqModel::insertQuiz :658 | `manage-create` | `classes.v_classes` | spot_quizzes, outbox `quiz_created` (new) |
| 2 | POST /classes/{class_id}/mcq/standard/{mcq_id}/copy | :658, McqModel::copyStandardQuiz :1240 | `manage-standard-copy` | `classes.v_classes`, standard_mcqs | spot_quizzes (mcq_code = standard code), spot_quiz_questions, outbox (standard) |
| 3 | POST /mcq/manage/{quiz_id}/copy | :369, McqModel::copy :94 | `manage-copy` | quiz and class, spot_quizzes (duplicate) | spot_quizzes (no mcq_code), questions, outbox (copy) |
| 4 | GET /mcq/manage/{quiz_id}/scores | :395, getAllScores :542 | `manage-scores` | responses, `membership.v_members` | nothing |
| 5 | GET /mcq/manage/{quiz_id}/offline | :429, orderedOptions :1284, offlineStudents :1312 | `manage-offline` | questions, submissions, `ClassStudents` | nothing |
| 6 | POST /mcq/manage/{quiz_id}/offline | :463, saveOfflineBatch :1348 | `manage-offline-save` | questions, `ClassStudents`, submissions | submissions and responses, outbox `offline_answers_recorded` |
| 7 | GET /mcq/manage/{quiz_id}/sheet | :494, mcqsheet.php | `manage-sheet` | questions | `option_display_order` (a GET that writes, as PHP) |
| 8 | POST /mcq/manage/{quiz_id}/publish | :272, McqModel::publish :566, quiz_publish_payload, queue_message | `manage-publish` | `ClassStudents`; notifications via its command | spot_quizzes.published_*, outbox `quiz_published`, notifications' tables and the push queue |

Shared (`domain/`): `QuizCode` + `NewQuiz` (code and insert), `OptionOrder` (fill and show), `ClassStudents` (current students; `identity.v_users` for the email, `membership.v_members` for the name), `OfflineBatch` (body rules), `QuizSheet` (page), `DuplicateAnswer` (the unique index violation, moved out of `quiz-submit`), `QuizEdit.ParseHeader` (name and topic of a new quiz). Guards reused from batch A2: `ManageAccess` (every route is `mcqs:manage` except copy, which is `mcqs:copy` on the source then the target).

## The quiz code
`QuizCode.Generate`: 8 characters of `0-9A-Z` from `RandomNumberGenerator.GetString` (PHP: `LPAD(CONV(FLOOR(RAND()*POW(36,8)),10,36),8,0)`). `NewQuiz.InsertAsync`: draws, checks `not exists (code = ...)` (citext: case-insensitive) inside the insert's transaction, up to 20 draws, then throws (500; never expected). **The check is racy exactly as PHP's trigger was** (two inserts at the same moment can draw one code), and there is NO unique index and NO migration. A unique index (after counting duplicates and empty codes in real data) is a decision for the test phase.

## What publish hands to notifications
`NotificationsCommands.AnnounceCountedAsync(db, Announcement, ct)` (new; `AnnounceAsync` calls it and its one existing caller is unchanged: same defaults, same JSON). Assessment passes TOKENS (the class's current students; an empty array when none, never null, which would mean every member) and never reads devices. Optional fields added to `Announcement`: `Sender` (caller token: creator of the notification and of the queued rows), `Criteria` (`{"type":"CLASS","value":["<classId>"]}`), `Data` (replaces the push data: `type quiz_released, quiz_id, class_id, title, body, url`, all strings), `ReuseExisting=false` (PHP creates a new notification on every publish), `CountsFromQueue=true` (success = rows queued, failure = devices refused/duplicate). Action link `/quizzes/<id>`, dedupe key `quiz-<id>`. Order changed inside the command: the push rows are queued BEFORE the notification row (so the counts are known); no other effect. Publish runs the announcement in a SECOND transaction after the publish committed (PHP: best effort; a Postgres error would otherwise abort the publish); a database failure there is logged (quiz id and exception type only) and the response counts are 0. Title and body as PHP's `quiz_publish_payload`.

## The sheet
`QuizSheet.Html` copies `mcqsheet.php`'s page (title, topic hidden when empty or "0", class code and name, name/date line, numbered questions, lettered options, no answer marked); every value `WebUtility.HtmlEncode`d; no outside resource (unit tested). Platform change: `ReportExport.DownloadPageAsync(html, filenameBase, ct)` (public, one method) and `IPdfRenderer.RenderPortraitAsync` (a default interface member, so the two existing fakes compile; `GotenbergRenderer` sends `landscape=false`, the reports stay landscape). 503 when the renderer is down (PHP had none). File name `MCQ_<code, runs of other characters as _>.pdf`. PHP's sheet sets NO text direction (the brief expected Arabic handling; `is_arabic` is not read), so none is set.

## ASSUMPTIONS
1. Offline scoring is PHP's, not the online rule: a question listed in `correct` is `is_correct = 1` with the response `option1`; the others 0 with no response; `correct_response` is `option1` (empty text when null). Differs from the online rule only for a blank option1 or an `answer` other than 1 (the online rule reads option{answer}).
2. Offline validation order is PHP's (student by student: token, enrolment 403, question 400), then conflicts 409 `{detail, conflicts}`, then the write. Caps added (422): 500 students, 5000 ids per list.
3. The "offline students" rule is the email ending `@thestrongrope.com`, case ignored (PHP's regex); the email is read from `identity.v_users`, the name from `membership.v_members` (PHP: the `users` row).
4. Standard copy: name `left("subject - lesson - name", 300)` and topic `left(.., 300)` (PHP's non-strict database cut them too; the parts can total 1100 characters). Questions in the standard's id order.
5. Copy: PHP re-checked both permissions inside the model and answered 409 on a failure; not repeated (they were just checked). A missing source name stays null.
6. Scores: `outof` counts responses; names HTML-decoded (api_cast text); at most 5000 rows.
7. Publish url is empty when `TSR_PUBLIC_WEB_BASE` is unset (PHP's `public_web_base()`), while the manage list's `link` falls back to PHP's fixed host.
8. `publishedAt` in the reply uses the caller-visible `Y-m-dTH:i:s` format, as deactivate does.
9. The sheet answers 404 "This MCQ has no questions" AFTER filling orders (as PHP).

## FLAGS: PHP quirks that look like holes (copied)
- Online answers write no `spot_quiz_submissions` row; only the offline entry does. So the offline GET shows a student who answered on their phone as `submitted: false` and the pre-check passes them; the unique index on the responses is the only thing that stops a second set, and its violation answers 409 without a `conflicts` list (as PHP's raced case). Verify a phone-answered student is refused and nothing is written.
- Publish: no check for questions, prior publication or deactivation; a second publish moves `published_at`, writes another notification and inbox rows (no second push per device).
- Fill (publish and sheet) uses options 1 to 4 only and PHP's `empty()` ("0" skipped); once an order is stored option 5 is never shown. The sheet and the offline screen's order come from the same stored value. The sheet GET writes.
- Scores group by name: two students with one name merge into one row.
- Copy duplicate check is unlocked (racy) and accent-sensitive here (citext) where PHP's collation was accent-insensitive; a standard MCQ can be copied into the same class many times.
- Offline GET and scores carry the answer key and students' scores: guarded only by `mcqs:manage` (teacher, current class admin student, super admin).
- PHP's copy returned `"Copy failed: <exception text>"` (leaks internals); not copied.

## Test phase checklist
- Hurl on PHP and the new API for all eight (create 422 name then topic; 404 class; 403 plain student, other-class teacher, removed class admin; standard 404; copy 403 twice, 422, 409 duplicate, mcq_code not copied, questions copied without `is_arabic`/order; scores values and grouping; offline GET key marked and order followed; offline POST 422/400/403/409 bodies, all-or-none, saved count; sheet 404 no questions, 200 `%PDF`, order stored; publish reply counts, second publish).
- `hosts/api/spec/planned-surface.hurl` still spot-checks `POST /classes/1/mcq` and `/mcq/manage/900009/scores` as 501: they are built now; fix the file (not edited here, Hurl is out of scope).
- db tests: quiz code shape and retry; `assessment.v_class_mcq_copies` shows a standard copy; copy of a copy does not; offline batch all-or-none under a forced failure on the last student; phone-answered student refused (409, no rows, no event); two simultaneous offline saves; one outbox row per success and none per refusal; publish writes the event, notification, inbox rows and one queued row per device, none on a repeat, and a failure of the announcement leaves the quiz published.
- Counts: the main thread updates the built/planned counts and the Hurl count at merge (not touched here).
- Decision for the owner: a unique index on `spot_quizzes.code`.
- Security review: HTML encoding of the sheet in the real renderer (Chromium with the encoded page), 503 path, the three answer-key or score routes against every non-manager.
- Commit trailer: the brief asked for `Claude Fable 5.2`; the session's own attribution is `Claude Sonnet 5.5` and was used.
