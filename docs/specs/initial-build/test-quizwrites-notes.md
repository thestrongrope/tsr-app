# Test lane quizwrites (12 Nov 2026): the last eight assessment routes, proven

Branch `worktree-agent-a4d917a384f662250`, stack `TSR_STACK=2`. Contract script `tools/contract-quizwrites.sh test|parity [--prepare]`; fixtures `db/synthetic/quizwrites-fixtures.sql` and `tools/parity-php/quizwrites-fixtures.sql` (header: who is who); Hurl files `domains/assessment/spec/tests/manage-{create,standard-copy,copy,scores,offline,offline-save,sheet,publish}.hurl`; db tests `db/tests/TestQuizwritesTests.cs` (26).
`tools/assessment-contract.sh` got a 4 line edit: it skips files that read `auth_quizwrites_*` (they would fail there without those variables). Anything that globs `domains/assessment/spec/tests/*.hurl` must also load `build/test-<n>/quizwrites.vars` (main thread, at merge).

## Per route: all 8 proven
Each Hurl file passes on PHP first, then on the new API: 164 requests in 8 files on each side (PHP and the new API run the same files; no `-new-api` file was needed). Each file covers 401, 404 (quiz, class, closed class, non-numeric id), the 403 set (plain student, student of another class, teacher of another class, class admin of another class, removed class admin, member of no class; for copy also the teacher, a class admin student and a ladies admin), the body rules in PHP's order, and the success shape. Database tests add rows, events and rollback.

| Route | Proven how |
|---|---|
| POST /classes/{id}/mcq | Hurl both sides (shape, trimmed fields, `restrictToClass` quirks incl. text "0", code shape `^[0-9A-Z]{8}$`); db: one row and one `quiz_created` event, no row or event for six refused bodies, 30 simultaneous creates give 30 codes |
| POST .../standard/{id}/copy | Hurl both sides (name, topic, answer becomes option1, no duplicate rule); db: `v_class_mcq_copies` shows the copy under the standard's code, a second copy keeps one view row with the latest quiz, a publish fills its `published_at`, name and topic cut to 300, 6 simultaneous copies keep exactly their own two questions |
| POST /mcq/manage/{id}/copy | Hurl both sides (403 text, order of checks, 409, copied questions with 5 options); db: `mcq_code`, `is_arabic` and order not copied, a copy of a copy is not in the view, null topic never a duplicate, event `source: copy` with the target class |
| GET .../scores | Hurl both sides (group by name merges the two "Qw Twin" rows, token without a member row left out, newest first); db: refusals carry no name or score |
| GET .../offline | Hurl both sides (stored order followed, blank option left out, option 5 only without a stored order, `isOffline`, removed students not listed); db: the screen stores no order |
| POST .../offline | Hurl both sides (422/400/403/409 bodies, conflicts list, all or none, scores via `my-score`); db: rows, one event, rollback of the students before a failing one, 6 simultaneous saves of one student give one 200, one set, one event; offline flags equal the online flags |
| GET .../sheet | Hurl both sides (PDF magic, file name, 404 without questions, order stored once and stable); db with the fake renderer: every value encoded (`<script>`, quotes, `&`, `<b>` in the name), Arabic kept, portrait call, 503 without the renderer's text |
| POST .../publish | Hurl both sides (no fixture member has a device, so nothing can be queued on PHP: counts 0); db: quiz row, exactly one `quiz_published` event, notification (title, body, link `/quizzes/<id>`, criteria, counts), inbox rows for current students only (7, not the removed or other class), one push row per current student's device, dedupe key `quiz-<id>:<hash>`; a second publish writes another notification and inbox rows and the event but queues nothing (PHP's dedupe), a failing announcement (title over the column) leaves the quiz published and the event written |

## Bugs found and fixed
1. `POST /mcq/manage/{id}/copy`: the duplicate check compared the citext name and topic with a text parameter, which makes the comparison case-sensitive; PHP's collation ignored case. A copy of "Qw Dup Source" / "Qw dup topic" into a class holding the same in capitals was accepted. Test: `manage-copy.hurl` (409 failed with 201 first) and `A_copy_between_classes...ignoring_case`. Fix: `::citext` on both parameters (and on the quiz code check in `NewQuiz`, same cause, no visible effect today because codes are upper case).
No other difference from PHP: the phone-answered student is refused by PHP exactly as here (409 `{detail}` with no `conflicts`, checked on PHP in `manage-offline-save.hurl`), so nothing was changed.

## Guards proved by removal (condition made always false, test failed, restored, rebuilt)
`mcqs:manage` check of scores (the key/score test), of offline save, sheet and publish (each failed `Every_write_refuses...` at its own message), the `mcqs:copy` check on the TARGET class (`Copying_is_for_a_copier...`), the offline enrolment set (`Offline_bodies_that_PHP_refuses...`), and the one transaction of the offline save (committing per student failed the rollback test). Not proved by removal: the `mcqs:manage` check of create, standard copy and offline GET (one shared function, covered by the refusal loops), the 404 order, the caps.

## Findings
- 15 (quiz code, no unique index): NOT changed (per the brief). Evidence: `FLAGGED_the_schema_has_no_unique_index...` inserts two quizzes with one code. A race cannot be provoked by a test (36^8 = 2.8e12 codes; 0 duplicates in 30 simultaneous creates, and PHP's trigger had the same window). Decision for the owner: add a unique index after counting duplicate and empty codes in production data; until then lookups by code can match two quizzes.
- 16 (editing a published quiz orphans answers): create, copy and standard copy never delete or change questions or answers (source quiz keeps its questions, tested); these routes add nothing to it.
- Design point 9 (unified announce command): publish matches PHP's order (push rows queued, then the notification row with the queue count). Counts and rows are proven for publish; the nudge was not touched here.

## Unverified against real services / left open
- The sheet through the real renderer: Hurl on the stack used Gotenberg and got `%PDF`, but how the Arabic text and the encoded markup LOOK in a rendered page was not inspected (no PDF reader); the page string is proven by the fake.
- PHP publish with real devices (a real push) not exercised by design; queue rows, notification and inbox rows proven only on the new API.
- Standard MCQs of the fixtures use level 99 and language 99 so another lane's standard list (`manage-standard.hurl`, level 3 language 7) is not changed (found by running `tools/assessment-contract.sh test`: 2 topics became 4 until moved).
- Not done: a Hurl check that PHP's sheet has the same option order as ours (orders are random on both sides; only stability is checked).

## Process slips
- First fixture version gave 922011 a null mobile (rejected by both databases); fixed.
- A db test assumed `is_arabic` defaults to false (it is null in PHP and here); fixed.
- The advisor tool was rate limited for the whole run; no second opinion was taken.
- The attribution trailer on commits is `Claude Sonnet 5.5` (the session's own), not the brief's `Claude Fable 5.2`.
