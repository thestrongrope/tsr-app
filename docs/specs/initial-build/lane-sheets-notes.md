# Lane sheets: notes for the test phase

Build-out, 12 Nov 2026. PHP reference under `build/parity-php/src/web/` (`api/mobile/routes/standard_mcqs.php`, `routes/quiz_admin.php`, `models/mcq.php`, `models/quizadmin.php`, `functions.php`). Nothing here was run against a database, a stack or Google: the gate was the build and the unit tests only.

## Routes (all `api_authenticate(true)`, the slice folder is under `domains/assessment/api/features/`)

| Route | PHP | Slice | Reads | Writes |
|---|---|---|---|---|
| GET /standard-mcqs/sources | standard_mcqs.php:40 | `standard-mcq-sources` | nothing (static lists) | nothing |
| POST /standard-mcqs/update | standard_mcqs.php:51; mcq.php:260-500 | `standard-mcq-update` | the source sheet (tab `<Language>-<Level>!A2:M`, all before any write) | per pair, in a savepoint: delete and insert `standard_mcqs`, `standard_mcq_questions`; outbox `assessment.standard_mcqs_updated` |
| GET /admin/quiz | quiz_admin.php:233; quizadmin.php:560 | `admin-quiz` | state documents; `membership.v_members`, `classes.v_enrolments`, `classes.v_classes` once participants exist | nothing |
| POST /admin/quiz/settings/refresh | :241; quizadmin.php:800-960 | `admin-quiz-settings-refresh` | settings sheet (Technical!A1:B, Functional!A1:D), old settings doc | `settings` doc; on not-live to live: `notifications.notifications`, `user_notifications`, `platform.outbound_messages` through `NotificationsCommands.AnnounceAsync`; outbox |
| POST /admin/quiz/download | :264; quizadmin.php:997-1087 | `admin-quiz-download` | responses sheet (`Form Responses N!<response_range>` per episode), member views | `participants`, `quiz_day`, `timestamps`, `scoreboard` docs; outbox |
| POST /admin/quiz/winners/generate, /regenerate | :286, :294; quizadmin.php:1752-2105 | `admin-quiz-winners-generate`, `-regenerate` (shared `domain/QuizDrawFlow.cs`) | winners, scoreboard, participants docs, member views | `winners`, `timestamps`, `winners_replaced` docs; outbox |
| POST /admin/quiz/publish | :302; quizadmin.php:2108-2290 | `admin-quiz-publish` | winners, scoreboard docs | ranges of the public Google sheet; `timestamps` doc; outbox. Mega quizzes only |
| POST /admin/quiz/reset | :332; quizadmin.php:360-400 | `admin-quiz-reset` | winners doc | `winners_replaced` (append), deletes the five cycle docs; outbox |

Order everywhere as PHP: 401, `quiz:admin` (403), body (422), unknown target (422), settings loaded (409), kind offered (404), lock (409), act. `quiz:reset` is checked inside reset (403 with PHP's text). The three actions `standard-mcqs:update`, `quiz:admin`, `quiz:reset` exist in the access catalog (`CatalogFromPhp`).

## State documents (`assessment.quiz_state(name, document jsonb, updated_at)`)

- `settings`: object. Technical tab rows: key and value; a row of other width: key and the list of cells after it. Functional tab: key and value rows, and tables (header row, then rows: `settings[header0][rowKey][header_i] = cell`; the header list keeps growing across tables, as PHP). Keys read: `mode` (live reads plain keys, other modes the prefix `<mode>_`), `total_quizzes`, `quiz_type` (MEGA or Grand), `response_range`, `response_token_column`, `response_score_column`, `<prefix>responses_sheet_id`, `<prefix>scores_sheet_id`, `scores_range`, `updatedon_range`, `winners_range`, `mega_winner_range`, `mega_student_winner_range`, `daily_winner_counts`, `winner_labels`, `min_score_percent`, `mega_winner_minimum_count`, `excluded_countries`, `excluded_tokens`, `validation_chunks`, `today_override`, `episodes`, `quiz_title`, `quiz_series`, `quiz_registration`, `quiz_stop`, `color_*`.
- `participants`: `{"1": [{token, score}], "2": [...]}`, token and score as typed in the sheet. `quiz_day`: a number. `timestamps`: `scoreboard_downloaded_at/by`, `last_run`, `last_validated`, `scoreboard_generated_at`, `download_summary{by_day{N:{submissions}}, completed_days, total_quizzes}`, `winners_generated_at/by`, `winners_reset_at/by`, `winners_updated_at/by`, `mega_winner_*`, `mega_student_winner_*`, `scoreboard_updated_at/by`, `min_score_percent_used`. `scoreboard`: list of `[counter, token, Name, "City, Country"|null, score per episode]`.
- `winners`: `{"1": [{episode, prize, token, name, city}], "mega": {episode:"MEGA", prize:"MEGA", token, name, city}, "mega_student": {...}}`. `winners_replaced`: list of `{at, by, kind: daily|grand|mega|mega_student|delete_all, episode, winners}`.

## Decisions and ASSUMPTIONS (PHP unclear or changed)

1. Notification command: `NotificationsCommands.AnnounceAsync(db, Announcement(Title, Body, ActionLink, DataType, DedupeKey, Tokens?), ct)`: `Tokens` null means every registered member (a device, demo cohort `%@demo.invalid` left out), otherwise exactly those tokens (the class-students lane passes theirs). It finds or creates the system inbox copy, fans it out, and calls the new `PlatformCommands.QueueMessagesAsync` for the push rows. Nothing is sent.
2. The push dedupe key is `first 150 chars of key : first 20 bytes of SHA-256(device) in hex`. PHP used SHA-1 (analyzer CA5350 refuses it): a key PHP queued is not recognised. Harmless once PHP stops queueing.
3. Timestamps: PHP shifts by the env `timeoffset` (IST in production). Here a fixed +05:30 wall clock; a `today_override` date keeps `+00:00` as PHP's `DateTime` did. `Last updated on` line uses the wall clock with 24-hour hours and AM/PM, as PHP's `H:i A`.
4. The actor stamp is `Name (token)` with the name read from `membership.v_members` (PHP: the session user). The app strips the ` (token)`.
5. Limits PHP lacks: at most 30 episodes (`total_quizzes`; 409 "The quiz settings need between 1 and 30 episodes."), at most 20 ids per list in standard MCQ update (422 "Too many ids"), winner counts summing over 10000 or negative are 409, 50000 rows per sheet range, 20 MB per sheet response, 30 s per sheet call, more than 20 started episodes fails the cross-day check with a reason.
6. Missing cells for NOT NULL text columns of the standard MCQ tables are saved as empty strings (PHP's MariaDB behaviour is unknown). A NUL or over-length text fails that pair's save ("The save failed and nothing was changed"), as PHP's strict mode would.
7. `today_override` that is not a date is ignored (PHP throws, a 500).
8. PHP's `force_quiz_mode` (an env override of the mode) is not ported. The settings sheet id is the setting `TSR_QUIZ_SETTINGS_SHEET_ID`.
9. A missing sheet id or range in the settings is treated as a sheet failure (PHP: undefined index, then a Google error).
10. The advisory lock is taken inside a transaction that stays open while the sheets are read or written (bounded by the 30 s call timeout), so a slow Google call holds one connection.
11. The refresh and the draws read the settings before taking the lock (for the pre-checks) and again inside; a refresh landing in between is the only race and PHP had it too.
12. PHP caches the settings for 60 seconds for non-admins (`get_quiz_settings`, member routes). Those routes are not in this lane.

## Google client: unverified (could not be run: no credentials, no network)

- JWT: header `{"alg":"RS256","typ":"JWT"}`, claims `iss` (client_email), `scope` (`https://www.googleapis.com/auth/spreadsheets`), `aud` (the key's `token_uri`, default `https://oauth2.googleapis.com/token`), `iat`, `exp` (+1 h); signed with `RSA.ImportFromPem` + SHA-256 PKCS#1. Unit tests prove the flow against a stub handler with a generated key only.
- Token exchange: POST form `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=<jwt>`; reads `access_token` and `expires_in`; cached until expiry less a minute.
- Read: `GET https://sheets.googleapis.com/v4/spreadsheets/{id}/values/{range}` with the range URL-escaped (including `!` and `:`), answer `{values: [[...]]}`, `values` absent for an empty range; default value rendering (formatted text). Whether Google accepts `%21` and `%3A` in the range segment is unverified (it is expected to).
- Write: `PUT .../values/{range}?valueInputOption=RAW` with body `{range, majorDimension: "ROWS", values}`; PHP's library sends the same. An empty list is sent as one empty row, as PHP's helper did.
- Sheet failure texts: PHP's are ours, never Google's. Same here.

## Looks like a security or privacy hole in PHP (copied, flagged)

- The standard MCQ update and the quiz admin are guarded only by `standard-mcqs:update` and `quiz:admin`; a holder can overwrite the whole question bank. Copied.
- The responses sheet ids, scores sheet ids and Google credentials are shared by every environment through settings; the sheets hold member tokens, names and cities. Copied; nothing is logged here.
- Scoreboard and winners carry member names and cities into the state documents and the public sheet (publish writes names and cities to a public sheet). Copied.
- Member tokens are typed in the Google form by participants (`intval`); nothing proves a participant is the token's owner. PHP's design; copied.
- The announcement goes to every registered member's devices; no opt-out. Copied.

## Checklist for the test phase

Standard MCQs
- [ ] 403 without `standard-mcqs:update`; sources lists 3 and 3.
- [ ] Update: 422 for an empty or non-int list; 409 while another transaction holds lock 5001 (`pg_try_advisory_xact_lock(5001)`); unknown id gives a failed row "Unknown language or level" and every other pair "Not updated: another sheet could not be read"; a sheet failure changes nothing; an empty tab gives "The sheet has no MCQs..."; a good pair replaces the rows (level saved as id + 1), counts quizzes, writes the event; a failing save rolls back only its pair (savepoint).
- [ ] No credential configured: the API starts; update answers `results` with "The sheet could not be read".

Quiz admin
- [ ] Each route: 401, 403 (no `quiz:admin`), reset 403 without `quiz:reset`; 409 while lock 5002 is held; 409 before settings are loaded.
- [ ] Refresh: 502 text without sheet id or credential and an empty settings doc is created; not-live to live writes one inbox row, fan-out rows and one queued push per device; a second refresh of the same quiz writes none (dedupe, inbox copy found again); a failing announcement does not fail the refresh (savepoint).
- [ ] Download: 502 names the episode and nothing is written; quiz day 0 saves only participants, day and timestamps; scoreboard sorted by token with normalised city; Grand ignores `today_override`, Mega honours it.
- [ ] Eligibility funnel numbers against PHP's `feasibilityFromData` for the same data (parity on the overview `eligibility` and `gates`).
- [ ] Draws: nobody wins twice in a cycle; the Mega winner needs every episode drawn; TSR student pool is enrolled students only; regenerate archives the replaced winners first and a blocked or empty draw changes nothing; a Grand quiz refuses `daily` (404) and a Mega quiz `grand`.
- [ ] Publish: Grand 404; 409 with no winner; `mega_student` with no range answers rows 0, changed false; the scoreboard's second write failing answers the partial 502 text and saves no timestamp.
- [ ] Reset: archives non-empty winners as `delete_all` (Mega as a one-element list), clears the five documents, keeps `settings` and `winners_replaced`.
- [ ] Overview never contains sheet ids, token lists or the replaced record; `can_reset` follows `quiz:reset`.
- [ ] Migration `QuizState` applies on a fresh database and on top of the others; `db/tests` table lists (if any) now include `quiz_state`.
- [ ] Real Google: the unverified shapes above, with a throwaway service account and sheet.
