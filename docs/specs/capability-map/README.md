# Capability map (15 Nov 2026)

What The Strong Rope's product does today, where each capability lives, and how far the new stack covers it.
It answers one question: **what must exist before each of today's systems can be switched off?**

Read from code, not run. The detail, one row per capability, is in three inventories beside this file:

| Inventory | Covers | Rows |
|---|---|---|
| [`php-web.md`](php-web.md) | the PHP web application (tsr-account `web/`, 110 pages) | 86 |
| [`flutter-app.md`](flutter-app.md) | the Flutter app (tsr-account `mobile/`, 1.6.0), with a web and desktop readiness section | 104 |
| [`website-and-background.md`](website-and-background.md) | the public website (tsr-web), and every scheduled or background job | 45 + 24 |

## Today's systems and their replacements

| Today | What it is | Replaced by | State of the replacement |
|---|---|---|---|
| PHP mobile API | 219 operations | the API in this repository | All 219 built; contract tests on both sides, database tests. Outside services faked. Not deployed |
| PHP web app | 110 pages, 86 capabilities | Flutter Web (the same app) on this API | Not started. The app does not start in a browser as written |
| Flutter app | 104 capabilities, Android and iOS | the same app, pointed at this API | Patrol journeys pass against this API on Android (reviewer 20 of 20, personas 33 of 36). iOS not run |
| Scheduler (cron, 6 jobs) and notifier (WhatsApp) | sends and index upkeep | this API's worker mode | 4 workers built; the WhatsApp runner is not |
| Public website (Next.js) | pages, search, lectures, CMS, JSON API | static site and API routes here | 6 Library routes ported and compared. No page, no search |

## The map

"Web", "App" and "Site" say where a person can do it today. "API here" is the new API; "verified" there always means
contract and database tests with fakes at outside services, never a real send.

| Area | Capabilities | Who | Web | App | Site | API here | What is missing |
|---|---|---|---|---|---|---|---|
| Sign-in and account | sign in, profile, account deletion request | everyone | yes (Google only, session cookie) | yes (Google, Apple, email) | | built | Web sign-in in Flutter needs Firebase's web setup |
| Join and registration | open a join link, register for a class, parent invite | members, parents | yes | yes | redirects | built | Link paths must reach the app when it is served on the web |
| Registrations | review, place, reject, download | admins, coordinators | yes | yes | | built | Downloads use phone files in the app |
| Classes | list, create, edit, roster, bulk add, deactivate, transfer | admins, coordinators | yes | yes | | built | "Extra students" clean-up has no route: ask if still needed |
| Teachers | list, training levels, import, look one up | admins | yes | yes | | built | |
| Conduction | record and correct a session, attendance, recitation | teachers, class MCQ admins | yes | yes (queues offline) | | built | |
| MCQs | write, publish, copy, print, paper answers, take, scores | teachers, students | yes | yes | | built | A printed sheet is a file in the app |
| Standard MCQ bank | refresh from the spreadsheet | super admin | yes | yes | | built | Real Google Sheets never called |
| Reports | weekly, monthly, conduction, sessions, subjects, students, MCQ, teachers, leaderboard, This week, pending | report readers | yes (16) | yes (14) | | built | **Dashboard** (17 data calls, "Person 360"), **subject summary**, **all-TSR summary**: web only, no route |
| Quiz competition (Grand, Mega) | status and schedule, admin, scores, winners, publish | members; quiz admins | yes | yes | | admin routes built | **`quiz_info`**: the app calls it on the account site and it is not in the route catalog. **Settings editing** and the **winners reveal screen**: web only |
| Notifications | send a push, inbox, devices, scheduled class notifications, calendar | admins, teachers, members | part (send, browser push) | yes | | built | FCM never called for real. Web push in Flutter is not set up |
| WhatsApp | link the account, reminders, run now, history | super admin | yes | yes | | admin routes built | **The runner that sends** is not built; the Node notifier uses the old database |
| Guides and syllabus | read and edit guides, syllabus topics and PDFs | teachers, admins | yes (guides) | yes | | built | Syllabus PDFs come from Google Drive: a browser may not fetch them |
| Access administration | permission grants, class-access rules | super admin | **no** | yes | | built | Nothing: already app only |
| Parent links | link a child, revoke; list across members | parents, admins | yes | yes (per child) | | per-child routes built | The cross-member admin list has no route |
| Donors, access log, deletion queue | lists, downloads, work the queue | super admin, finance | yes | yes | | built | Firebase account deletion never called for real |
| Search (members, classes) | search across records | admins | part (dashboard) | yes | | built | Proven on a real Elasticsearch on the test stack |
| Library | articles, categories, tags, publications, videos | everyone, guests | | yes | yes | built (6 routes) | The app also calls the website's **article search** and **lecture search**, and the old WordPress API: not ported |
| Website pages | home, articles, pages, publications, lectures, self-reflection, donate, about | the public | | | yes | no | Every page; old-link redirects; app-link files; the privacy policy page the stores link to |
| Website editing | Decap CMS, GitHub sign-in | editors | | | yes | no | Owner: Decap is unused. Content arrives by commit |
| Website search analytics | record searches and clicks, report | editors | | | yes | no | Decide whether to keep |
| Content pipelines | lectures, captions, translations, article drafts | the owner, on a laptop | | | feeds the site | not in scope | They write content files; nothing to port unless the file layout changes |

## Background work

| Job today | Trigger | Here | State |
|---|---|---|---|
| Send queued pushes | cron, every minute | worker `push-drain` | built; FCM unverified |
| Queue due class notifications | cron, every minute | worker `class-schedules` | built |
| Keep the search index current, rebuild nightly | cron, every minute and nightly | worker `search-feed` (rebuild every 10 minutes) | built; proven on a real index |
| Refresh the Library copy | (the website reads files on request) | worker `content-refresh` | built |
| Start due WhatsApp reminders; send them | cron, every minute; the notifier | none | **not built** |
| Send queued WhatsApp messages | cron, every 2 minutes | none | not built; the inventory found nothing that queues them |
| Apply migrations | container start | the stack's migrate step | built for the local stacks; production not written |
| Purge expired deletion contact details | when an admin opens the page | unsure | check before cut-over |

## What each switch-off needs

**1. The PHP mobile API** (the store apps move to this API)
- A production deployment, and members' data moved from MariaDB to PostgreSQL.
- Real FCM, Firebase account deletion and Google Sheets proven once each.
- `quiz_info` served somewhere the store builds can still reach, or ported.
- The WhatsApp runner, or the Node notifier pointed at the new database for a while.

**2. The PHP web app** (Flutter Web takes over)
- The app starts in a browser: Firebase for web, then the files, push and link items of `flutter-app.md`.
- The few web-only capabilities get a route and a screen: the dashboard, subject summary, all-TSR summary, quiz settings, winners reveal, the parent-links list. Most of the web app already has both.
- A wide-screen layout: the app is built for a phone in portrait.

**3. The public website**
- Every page as static pages, the redirects, the app-link files, the privacy policy.
- Article search and lecture search as API routes (the owner's direction: blended into the app's API).

## Findings worth a decision

1. **The web app is mostly a second front end, not a second product.** Of its 86 capabilities, 66 have a route in the mobile API; 20 do not clearly (8 "no", 9 "unsure", 3 "partly"), and most of those are small (sign out, page-view counting, the API reference). The real features without a route are about six, listed under switch-off 2. Replacing the web app is mainly a Flutter Web job, not an API job.
2. **Flutter Web is the largest unknown now.** Nothing was built; the inventory lists what cannot work as written.
3. **`quiz_info` is outside the route catalog** and the store builds depend on it (confirmed in the app's code).
4. **12 PHP pages look dead.**
5. **Three documents in tsr-account are stale** (the app's features and roles, the parity document, the roadmap). The three inventories here replace them as the current picture.

## Not verified

- Everything here is from reading. No inventory ran the software.
- "Has a route" was matched by route name against `docs/specs/initial-build/operations.csv`, not by comparing behaviour.
- PHP pages were read in excerpt; a page may do more than its row says. Models, most JavaScript and all data folders were not read.
- The Flutter app's screens were read by search; its web and desktop assessment is from the plugin list, not a build.
- Counts of "web only" capabilities are the inventory's "unsure" and "no" rows, checked by hand for `quiz_info` only.
