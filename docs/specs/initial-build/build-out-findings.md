# Build-out findings to settle in the test phase

Found while porting (12 Nov 2026 on). Nothing here is proven or fixed yet; each item needs a check against PHP, a test, and a fix or a decision. The lane notes (`lane-*-notes.md`) hold the per-route detail.

## Security and privacy

| # | Where | Finding | Source |
|---|---|---|---|
| 1 | identity `features/admin-deletion-complete/AdminDeletionComplete.cs` | Completing a deletion reads ONE `users` row of the token (`order by id limit 1`) and deletes that row's Firebase account, then anonymises EVERY row of the token. A token is not unique: a second row's Firebase account would survive with its sign-in. Check what PHP does; fix: delete every distinct Firebase account of the token, stop on a failure. | automated commit review |
| 2 | identity `GoogleFirebaseAccounts.cs` | With no stored Firebase uid the client looks the account up BY EMAIL and deletes whichever account owns that address. Irreversible, and the address may belong to someone else by then. Check PHP; fix: delete by stored uid only, otherwise refuse or require the operator. | automated commit review |
| 3 | classes quran leaderboard | Row scope uses the `reports:read` assigned-only list, so a caller holding only `quran-leaderboard:read` may see every class (as PHP). | lane small |
| 3a | membership waiting list (`GET /reports/registrations` and its download) | Row scope is the gender only, as PHP: a coordinator sees every waiting person of their gender with email, mobile and address. The stricter scope decided on 11 Nov 2026 (only people who asked for an assigned class) was reversed by the owner on 14 Nov 2026. | owner decision |
| 3b | classes transfer history and deactivated classes (`GET /admin/transfers/history`, `GET /admin/deactivated-classes`) | The right is the only gate, as PHP: a holder limited to assigned classes sees every transfer (student names, class codes, reasons) and every closed class with its log. The stricter scope decided on 11 Nov 2026 (assigned classes only) was reversed by the owner on 14 Nov 2026 and removed on 15 Nov. | owner decision |
| 4 | platform access log | Name, email, IP, device and referrer go to every `audit-log:read` holder (as PHP). | lane small |
| 5 | notifications whatsapp | PHP forwards the notifier's own error text to the caller, including its 500s (copied). | lane whatsapp |
| 6 | classes MCQ summary CSV | Student names go to every `reports:read` holder (as PHP). | lane mcq-reports |
| 7 | identity deletion | Database role grants for the cross-schema deletes and updates of a completion are unchecked. | lane identity |
| 8 | assessment `domain/QuizEligibility.cs` (quiz competition admin) | The winners feasibility check tries every subset of the started quiz days (2^n, capped at 20 days: about a million subsets, each building a set) and runs on every `GET /admin/quiz`. Only `quiz:admin` holders can reach it. Check how PHP does it; fix: a bipartite matching in place of the subset search, or a lower cap, and compute once per download, not per read. | automated commit review |
| 9 | notifications `features/device-register/DeviceRegister.cs` | Registering a device deletes any OTHER member's row with the same `device_id`. A signed-in member who knows or guesses another member's device id can remove that member's push registration (they stop receiving pushes; nothing is exposed). Likely PHP's behaviour for a phone that changes hands: check PHP; consider a rate limit and an audit row, or keying on the push token the device itself holds. | automated commit review |
| 10 | access permission grants | A super admin can grant themselves any `:all` permission (as PHP). | lane access |
| 11 | access class-access rules | A gender admin can manage rules on other admins of their own gender; level conditions are not limited by city (as PHP). | lane access |
| 12 | platform push queue | Dedupe keys use SHA-256 where PHP uses SHA-1 (the analyzer rejects SHA-1): keys PHP already queued will not match during a cut-over. | lane sheets |
| 13 | assessment quiz competition | PHP's `force_quiz_mode` setting is not ported; timestamps use a fixed +05:30; limits PHP lacks were added (30 episodes, 20 ids per list, a winner-count cap). | lane sheets |
| 14 | search `features/search/Search.cs`, `domain/SearchEngine.cs` | Teacher results: a caller who may look up teachers of one gender only through the teacher-gender target is treated like one who may see every member of that gender; and the database re-check of teacher hits only confirms the member still exists, not their current gender or that they still teach, so a stale index can expose a hit it should hide. No published view carries teacher status. Check PHP's re-check; fix: a classes view for active teachers and a gender re-check. | automated commit review, lane search |
| 15 | assessment quiz code | `spot_quizzes.code` has no unique index, in PHP or here; the generator checks "not exists" and retries, racy exactly as PHP's trigger. Decide on a unique index (existing data may hold duplicates). | batch A2, main thread |
| 16 | assessment edit a quiz | Editing a published, answered quiz deletes and re-inserts its questions: students' answers are orphaned and their scores change (as PHP; pinned by a db test and Hurl). | batch A2 |
| 17 | notifications device and broadcast | Knowing a push token is enough to move a device to another member; the cleanup route pushes a visible "System Check" to every device; a member with a non-numeric gender gets inbox rows for pushes they never received (all as PHP). | lane notify-core |

## Design points to confirm

| # | Point | Source |
|---|---|---|
| 1 | Identity cannot reference membership (cycle), so erasure of the profile goes through a port `IMemberErasure` that membership implements. | lane identity |
| 2 | Account deletion erases other domains' rows through their published commands in one transaction and also writes `identity.member_erased`; rule 11 of `domains/CLAUDE.md` planned event-only erasure. | main thread assumption |
| 3 | The quran leaderboard (2 routes) is built in classes, by the reasoning of the MCQ reports decision. | main thread assumption |
| 4 | Google clients (Firebase accounts, FCM, Sheets) are each written by a different lane: merge them onto one service-account token provider in `shared/api`. | main thread |
| 5 | Required or new settings: `TSR_NOTIFIER_URL` (no default; without it every WhatsApp route is 502), `TSR_GOOGLE_SERVICE_ACCOUNT_B64` (optional; without it Firebase deletion, push and Sheets are inert). | lanes |
| 6 | The pending nudge (1 route) is built in classes and its push is queued, not sent: `sent:true` means recorded and queued; a 12-month cap on its range was added. | lane nudge |
| 7 | Missing workers, none of them an API route: the push-queue drain, the scheduled class-notification sender, the search-index feeder, the WhatsApp reminder runner. | lanes |
| 8 | Two lanes each made a `v_class_levels` view; the later copy was removed from its (never applied) migration at merge. | main thread |
| 9 | `NotificationsCommands.AnnounceAsync` was extended by two lanes and is now one command (flat optional fields, `AnnounceCountedAsync` with `AnnounceResult`). The push is queued before the notification is written (both PHP paths act first, then record; the quiz publish needs the queue count). Two small changes for the nudge: its queued rows are created by the sender (the nudge lane used the system), and its push data no longer carries a null `action_link` (PHP sent only type, sent_at, class_ids). | merge |

## Case-sensitive comparisons (found in the test phase, 12 Nov 2026)

Every `string` column is `citext` by convention (`shared/api/TsrConvention.cs`), to match MariaDB. A C# `string` parameter is sent as `text`, and `citext_column = {value}` then compares as text: CASE-SENSITIVE unless the SQL says `{value}::citext`. Two test lanes each found one such bug (the device id in notifications, the quiz name duplicate check in assessment; both fixed). A read-only sweep of all 162 files that run SQL (about 400 comparisons read) lists these as still open; fix each test-first once the test lanes are merged:

| # | Where | What goes wrong | Reach |
|---|---|---|---|
| C1 | `domains/platform/api/PlatformCommands.cs` (`recipient = any({values})`), called by identity's deletion completion | A queued message whose stored recipient differs in letter case from the erased member's mobile or device id is NOT redacted | privacy; admin action. FIXED (`::citext[]`), test `TestDeletionTests.A_queued_message_whose_recipient_differs_only_in_letter_case_is_redacted_and_a_similar_recipient_is_not_CASE_C1` |
| C2 | `domains/notifications/api/NotificationsCommands.cs` (`FindNotificationAsync`: title, body, action_link) | The "same announcement already recorded" lookup misses a case variant: a duplicate inbox entry | low. FIXED, test `TestNotifyTests.An_announcement_is_found_again_when_its_title_body_and_link_differ_only_in_letter_case_CASE_C2` |
| C3 | `domains/classes/api/features/class-create/ClassCreate.cs` (`link = {link}`) | The "link already taken" check is case-sensitive while joining by link is not: a new class can get a link that differs only by case from an existing one, and a join by that link is then ambiguous | a PROVEN route (B2). FIXED (check moved to `ClassCreateSlice.LinkTakenAsync`), test `AdminB4aWritesTests.A_class_link_is_taken_when_an_existing_class_has_it_in_another_letter_case_CASE_C3` |
| C4 | `domains/identity/api/domain/DeletionRequests.cs` (`r.status::text = {status}::text`) | A status filter in another letter case matches nothing | NOT A BUG: PHP matches `?status=` against its list with strict `in_array`, so another letter case selects nothing and shows all; the C# list does the same (ordinal) before the SQL, so the SQL never sees another case. No change |
| C5 | `domains/assessment/api/domain/QuizStateStore.cs` (`name = {name}`) | Latent: the names are lower-case constants | none today. FIXED (also `DeleteAsync`, `= any(text[])`), test `TestQuizwritesTests.A_quiz_state_document_is_found_and_deleted_by_its_name_in_another_letter_case_CASE_C5` |
| C6 | `domains/assessment/api/features/manage-standard-copy/ManageStandardCopy.cs` (`mcq_code = {standard.Code}`) | The questions of a standard MCQ whose code differs in case between its two tables are not copied | low. FIXED, test `TestQuizwritesTests.A_standard_copy_takes_the_questions_whose_code_differs_from_the_standards_only_in_letter_case_CASE_C6` |

Not covered by the sweep: view bodies in the raw-SQL migrations, grouping or ordering over a `::text` cast, and most EF LINQ string comparisons (EF is believed to send the parameter as the column's type; one confirmed site to check: `domains/identity/api/domain/MemberDirectory.cs`, `u.Email == user.Email`). EF check done: `u.Email == user.Email` sends the parameter as citext, so it is fine (pinned by `SignInTests.An_EF_comparison_of_an_email_matches_a_row_that_differs_only_in_letter_case_LINQ_CHECK`). The guard is `hosts/api/tests/SqlCitextCastTests.cs` (fixed column-name list; limits in its summary).
