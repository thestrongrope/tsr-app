# Status

What is built and what was last measured. This page is dated history: update it when a count or a state changes, and keep it out of the instruction files.
Open decisions and findings: `docs/specs/initial-build/build-out-findings.md`. What the product does and what each switch-off needs: `docs/specs/capability-map/README.md`.

## The API surface

Today's PHP API stays in tsr-account until routes move here. Domains planned: `identity` (AuthN)
· `access` (AuthZ) · `membership` · `classes` · `assessment` · `content` · `notifications` ·
`platform` · `search` (read model). All nine exist and route the whole API surface: the **route catalog**
`docs/specs/initial-build/operations.csv` lists 219 operations (PHP's 213 of 10 Nov 2026 and the 6 calendar routes it gained) (method, path, domain, auth kind, state). A `built`
one has its slice; a `planned` one is a placeholder in its domain's `api/Planned.cs` that signs the caller in as the real
route will (never creating a member), then answers 501 `{"detail": "Not implemented"}`. **Building a slice replaces its
placeholder:** delete its line in `Planned.cs`, flip its state in `operations.csv` to `built` (the tests in `hosts/api/tests`
fail until both match; a gateway block per path already exists). Built today (12 Nov 2026): identity 9, access 13, platform 9,
membership 25 (with `POST /auth/link`, moved from identity on 13 Nov 2026: its `me` is the profile), classes 96, assessment 35, notifications 24, content 1, search 1 (213), plus 6 calendar routes in notifications (219), plus the 6 public Library routes under `/api/v1/` in content (13 Nov 2026; they come from the website, not PHP, so they are listed in `RouteCatalog.NotInPhp` and `docs/specs/website-port/operations.csv`, not in this catalog); none is planned (`/me/guides` and `/me/guides/{slug}` were built on 12 Nov 2026 from a fresh PHP copy). **All 213 have contract tests and database tests (test phase, 12 Nov 2026)**: 136 from the earlier batches, 75 from the build-out lanes proven afterwards by seven test lanes (`docs/specs/initial-build/test-*-notes.md`). Not verified against a real service (fakes at the boundary only): Google Sheets, Firebase account deletion, FCM push, the WhatsApp notifier. (Elasticsearch was on this list until 12 Nov 2026; `GET /search` and the feed are now proven against a real one on the test stack.) Open decisions and findings: `docs/specs/initial-build/build-out-findings.md`. The report downloads (xlsx or PDF) all go through platform's `ReportExport` (`domains/platform/CLAUDE.md`). Tables only, besides routes: `notifications`; `assessment` has 9 quiz routes (batch A1: a member takes a quiz and reads scores).
`search` has routes only. Which owns what: `domains/CLAUDE.md`.

## What the 219 does not cover (27 Nov 2026)

"All 219 built" means the routes of PHP's mobile router (`web/api/mobile/index.php`) and nothing else. It never meant "everything the app calls" or "everything PHP and the website do". Known gaps:

| Gap | Who depends on it | State |
|---|---|---|
| Quiz status for the home banner (PHP `web/api/quiz_info.php`, outside the mobile router) | the app | built here as `GET /quiz/info` on 27 Nov 2026 (`domains/assessment`); released app builds still call the PHP address |
| Article search and lecture search (the website's `/api/v1/search` and `/api/v1/lectures/search`; lecture search runs with the meaning layer on) | the app, the website | article search built on 28 Nov 2026 (`GET /api/v1/search`, `domains/search`; not compared with the live site, not run as a native image); lecture search not built; plan in `docs/specs/website-port/search-port-plan.md` (issue 22) |
| The website's search analytics (events, click route, report) | the website | not built; the events and the click route are in the search plan, the report route is not |
| The join link `account.thestrongrope.com/join/<code>` and the website links the app opens (`/articles/<slug>`, `/donate`, `/about`, `/accreditation`, `/uploads/...`) | the app | not checked against the new stack |
| `wp-json` calls in the app (`hosts/app/lib/features/wordpress/services/wordpress_service.dart`) | nothing serves them: there has been no WordPress site for over a year | code to delete, not to port; not traced whether a screen still reaches it |
| PHP web capabilities with no route (the reports dashboard, subject and all-TSR summaries, quiz settings editing, the winners reveal screen, the cross-member parent-links list, the "extra students" clean-up) | the PHP web app | not built (`docs/specs/capability-map/README.md`) |
| The WhatsApp runner that sends | members | not built |
| PHP files outside the mobile router, other than `quiz_info.php` | members (WhatsApp reminders, app links on the account host, the account deletion page), admins (some reports) | audited file by file on 28 Nov 2026 by reading, nothing run: 163 items, 16 not ported and 14 partly covered; the list by risk is `docs/specs/php-audit/README.md` |

Elasticsearch on the stacks holds one index, `tsr-search` (member and class search for admins). It holds no article or lecture index until the search plan is built.

## The app

`hosts/app` is the member app (package `the_strong_rope`, 1.6.1+24): the whole of tsr-account `mobile/` at `b2a5fc70`, moved here on 26 Nov 2026 (issue 26, PR 125) in place of the earlier shell, and a member of the root pub workspace. No screen has moved into `domains/*/app` yet. The store builds are still made from tsr-account. `hosts/app/Dockerfile` builds the web copy (Flutter Web behind nginx); the local stacks start it with `TSR_WITH_APP=1` (`docs/testing.md`). The production compose file has no `app` service.

## Releases

0.9.0 (26 Nov 2026): `main` at `b465aaa`, tag `v0.9.0`, deployed to production (the API answered healthy after the deploy; the migrate job's exit code and the image serving were not confirmed in Dokploy). The production database holds no members' data yet, and the store apps still call the PHP API.

## Workers and outside services

Built workers, what is not built and what is unverified are in "Background workers on the stacks" of `docs/testing.md` (one text, kept there because it also says which stack may run which worker).

## The PHP reference

**The PHP reference moved (12 Nov 2026), and the new API followed.** `build/parity-php/src/` is tsr-account `develop` at `819093ea` (the copy the first 211 routes were ported from is kept beside it as `src-before-2026-11-12`); every contract script passes against it. Ported from it the same day: `GET /me/permissions` version 5 (`revision`, `navigation`, ETag and 304, 503 when unreadable), the header `X-Permissions-Revision` on every signed-in response (`domains/access/api/PermissionsRevisionHeader.cs`; it resolves the caller's permissions before the route: PHP spends 7 queries, the new API 2 commands), and the calendar: six routes and two tables in `notifications` (`GET /me/calendar`, `PUT /me/calendar/settings`, `GET|POST|PATCH|DELETE` on `/classes/{class_id}/scheduled-events`; `tools/contract-calendar.sh test|parity [--prepare]`). The catalog `operations.csv` now lists 219 operations, all built. **Moved again on 15 Nov 2026** to `c78ff6b4` (app 1.6.1; the copy before it is `src-before-2026-11-15`): no new route; ported are the one wording of the pending C-form reminder (`report-pending-nudge`) and the teacher's number in full on This week (`report-this-week/DialableNumber.cs`, PHP's `phonenumber.php`). Not ported, because their owners are not built here: the weekly WhatsApp wording (`weeklyMessage`, the Node notifier) and the web page `api_conduction_report.php`. When PHP moves again: archive `develop` into a fresh `src/`, run every `parity` script, and diff `web/api/mobile/index.php` for new routes.

## Last measured

| What | Result | When |
|---|---|---|
| The API host (epic 95's outcome, lane 1 on an arm64 Mac) | a NativeAOT image on the chiseled `runtime-deps` base, 123 MB (asked: 220 MB or less; JIT was 330 MB); first `GET /api/v1/articles` after a start 17 to 29 ms in 6 restarts (asked: 30 ms or less; JIT about 310 ms); 68 MiB 15 s after a start (asked: 80 MiB or less; JIT 116 MiB); no domain uses Entity Framework at run time; the migrate job is the same host published JIT | 25 Nov 2026 |
| Every Hurl file on the new API (lane 1, native image) | 250 files, 0 failed (243 in the main run, 6 content with `content-refresh` on, search with `search-feed` on) | 25 Nov 2026, `develop` at `638eb21` plus the chiseled image, workstation GC and the connection warm-up |
| Every contract script on PHP at `c78ff6b4` | 14 scripts, 218 files, 0 failed | 15 Nov 2026 |
| Database tests | 1,534 passed | 25 Nov 2026 |
| Host tests | 314 passed | 25 Nov 2026 |
| Website parity | 67 cases and 501 articles, none failed | 13 Nov 2026 (`docs/specs/website-port/parity-results.md`) |
| Patrol on Android against the new API (the journeys of `hosts/app`, built from it and run by `tools/patrol-lane.sh`; native image on a lane; the cohort and persona fixtures still come from a tsr-account checkout) | reviewer 20 of 20; personas 35 of 38: `persona_ladies_admin_test` does not find the text "Managing" (cause not found), `persona_super_admin_whatsapp_link_test` fails because a lane has no WhatsApp sender, and `persona_super_admin_link_student_test` was run only on a fixture without its member (it needs tsr-account's `develop` fixture). | 26 Nov 2026 |
| The app in `hosts/app` | `flutter analyze` clean; `flutter test` 1,889 passed | 26 Nov 2026 |
| The web copy of the app on lane 2 | profile image (Auth emulator) 113 MB: Home loads and a synthetic member signs in by email and reaches profile completion; release image 97.7 MB: Home loads signed out. Not checked: any screen past profile completion, Google sign-in, exports, other browsers | 26 Nov 2026 |
| Load test | `docs/specs/load-test/results.md` | 14 Nov 2026 |
