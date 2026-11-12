# Build-out findings to settle in the test phase

Found while porting (12 Nov 2026 on). Nothing here is proven or fixed yet; each item needs a check against PHP, a test, and a fix or a decision. The lane notes (`lane-*-notes.md`) hold the per-route detail.

## Security and privacy

| # | Where | Finding | Source |
|---|---|---|---|
| 1 | identity `features/admin-deletion-complete/AdminDeletionComplete.cs` | Completing a deletion reads ONE `users` row of the token (`order by id limit 1`) and deletes that row's Firebase account, then anonymises EVERY row of the token. A token is not unique: a second row's Firebase account would survive with its sign-in. Check what PHP does; fix: delete every distinct Firebase account of the token, stop on a failure. | automated commit review |
| 2 | identity `GoogleFirebaseAccounts.cs` | With no stored Firebase uid the client looks the account up BY EMAIL and deletes whichever account owns that address. Irreversible, and the address may belong to someone else by then. Check PHP; fix: delete by stored uid only, otherwise refuse or require the operator. | automated commit review |
| 3 | classes quran leaderboard | Row scope uses the `reports:read` assigned-only list, so a caller holding only `quran-leaderboard:read` may see every class (as PHP). | lane small |
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
## Design points to confirm

| # | Point | Source |
|---|---|---|
| 1 | Identity cannot reference membership (cycle), so erasure of the profile goes through a port `IMemberErasure` that membership implements. | lane identity |
| 2 | Account deletion erases other domains' rows through their published commands in one transaction and also writes `identity.member_erased`; rule 11 of `domains/CLAUDE.md` planned event-only erasure. | main thread assumption |
| 3 | The quran leaderboard (2 routes) is built in classes, by the reasoning of the MCQ reports decision. | main thread assumption |
| 4 | Google clients (Firebase accounts, FCM, Sheets) are each written by a different lane: merge them onto one service-account token provider in `shared/api`. | main thread |
| 5 | Required or new settings: `TSR_NOTIFIER_URL` (no default; without it every WhatsApp route is 502), `TSR_GOOGLE_SERVICE_ACCOUNT_B64` (optional; without it Firebase deletion, push and Sheets are inert). | lanes |
