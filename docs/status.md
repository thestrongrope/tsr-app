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

## Workers and outside services

Built workers, what is not built and what is unverified are in "Background workers on the stacks" of `docs/testing.md` (one text, kept there because it also says which stack may run which worker).

## The PHP reference

**The PHP reference moved (12 Nov 2026), and the new API followed.** `build/parity-php/src/` is tsr-account `develop` at `819093ea` (the copy the first 211 routes were ported from is kept beside it as `src-before-2026-11-12`); every contract script passes against it. Ported from it the same day: `GET /me/permissions` version 5 (`revision`, `navigation`, ETag and 304, 503 when unreadable), the header `X-Permissions-Revision` on every signed-in response (`domains/access/api/PermissionsRevisionHeader.cs`; it resolves the caller's permissions before the route: PHP spends 7 queries, the new API 2 commands), and the calendar: six routes and two tables in `notifications` (`GET /me/calendar`, `PUT /me/calendar/settings`, `GET|POST|PATCH|DELETE` on `/classes/{class_id}/scheduled-events`; `tools/contract-calendar.sh test|parity [--prepare]`). The catalog `operations.csv` now lists 219 operations, all built. **Moved again on 15 Nov 2026** to `c78ff6b4` (app 1.6.1; the copy before it is `src-before-2026-11-15`): no new route; ported are the one wording of the pending C-form reminder (`report-pending-nudge`) and the teacher's number in full on This week (`report-this-week/DialableNumber.cs`, PHP's `phonenumber.php`). Not ported, because their owners are not built here: the weekly WhatsApp wording (`weeklyMessage`, the Node notifier) and the web page `api_conduction_report.php`. When PHP moves again: archive `develop` into a fresh `src/`, run every `parity` script, and diff `web/api/mobile/index.php` for new routes.

## Last measured

| What | Result | When |
|---|---|---|
| Every Hurl file on the new API (default test stack) | 250 files, 3,344 requests, 0 failed | 15 Nov 2026, `develop` at `2b02cd8` |
| Every contract script on PHP at `c78ff6b4` | 14 scripts, 218 files, 0 failed | 15 Nov 2026 |
| Database tests | 1,355 passed | 15 Nov 2026 |
| Host tests | 97 passed | 15 Nov 2026 |
| Website parity | 67 cases and 501 articles, none failed | 13 Nov 2026 (`docs/specs/website-port/parity-results.md`) |
| Patrol on Android against the new API | reviewer 20 of 20; personas 33 of 36 | 14 Nov 2026 |
| Load test | `docs/specs/load-test/results.md` | 14 Nov 2026 |
