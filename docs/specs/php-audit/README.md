# PHP outside the mobile router: what the new stack does not do (28 Nov 2026)

An audit of every PHP and Node file in tsr-account (`c78ff6b4`) that is not under `web/api/mobile/`. It answers one question: what would stop working if PHP were switched off today. The 219 routes of the mobile router are not covered here (`docs/status.md`).

**How it was made.** Four agents read the files and wrote one row per file; the high-risk findings and the app's own calls were then checked by hand against the source. Nothing was run. A verdict of "api-covered" means the capability was matched to routes by reading both sides, not field by field.

| File set | Rows | Detail |
|---|---|---|
| `web/*.php`, a to d | 35 | `web-a-d.csv` |
| `web/*.php`, e to m | 37 | `web-e-m.csv` |
| `web/*.php`, n to z | 38 | `web-n-z.csv` |
| `web/api` (not mobile), `web/cli`, `web/score`, `notifier/`, rewrite rules, scripts | 53 | `api-cli-score-notifier.csv` |

## Counts

| Verdict | 110 web pages | 53 other items |
|---|---|---|
| The capability exists as API routes or a worker (only the PHP screen is missing) | 70 | 13 |
| Only included by other PHP | 12 | 10 |
| Not needed (dead, development only, replaced) | 15 | 10 |
| Partly covered | 6 | 8 |
| Not ported | 7 | 9 |
| Unknown | 0 | 3 |

## The mobile app

Checked by hand: the app calls no PHP file outside the mobile router other than `quiz_info.php` (ported as `GET /quiz/info`). Every other `.php` name in `hosts/app/lib` is a comment. The app does open these addresses in a browser or as links: `account.thestrongrope.com` (join, link, mcq and guide links), and `thestrongrope.com` (`/articles/<slug>`, `/donate`, `/about`, `/accreditation`, four images under `/uploads/`). The `wp-json` address is dead code.

## High risk: members or the app are affected

| Gap | What breaks without it |
|---|---|
| The WhatsApp reminders: `web/cli/run_due_reminders.php`, the Node `notifier/` (weekly job, sender, link server) and its source `web/api_conduction_report.php` (read with an API key) | The weekly reminder to teachers about missing conduction reports stops. Nothing in tsr-app sends WhatsApp; the admin link routes are built but the sender behind them is not hosted. |
| The scheduler (PHP runs six cron jobs) | Four have a worker here (push drain, search drain, search reindex, class notifications), the WhatsApp drain is not needed (nothing queues to it), and the reminders are the row above. The production `workers` service runs none until `TSR_WORKERS` names them, so pushes and class notifications stop at a switch-over unless it is set. |
| `/.well-known/apple-app-site-association` and `assetlinks.json` on the account host | Links to `account.thestrongrope.com/join/...` no longer open the app on a phone. |
| `web/delete-account.php` | The public account deletion page that the Play listing points to (by the file's own header; the Play console was not checked). A broken address can get the app rejected. |

## Medium risk: an admin or teacher loses a tool, or a link shows nothing

| Gap | Note |
|---|---|
| The web pages behind `/join/<code>`, `/link/<code>`, `/mcq/<code>`, `/guide.php` for someone without the app | The data routes exist; no page is served. The gateway sends `/join/<code>` to the API, which answers JSON. |
| `web/api/quiz_info.php` at its old address | Released app builds call the PHP address; the new stack serves `/quiz/info` only. |
| `web/dashboard.php` (analytics and the one-member view) | No routes. |
| `web/subject_summary_report.php` | No route calls its figures. |
| `web/summary_report.php` | No view of both genders together. |
| `web/score/quiz_admin.php`: writing the scoreboard to the sheet | The other quiz admin actions are built. |
| `notifier/db.js` | Reads old MariaDB tables. |
| `tools/geonames/load.php` | The full place-name load has no counterpart. |

## Low risk

`web/app.php` (the `/app` store redirect behind the QR code), `web/parent_links.php` (admin list and revoke of other members' links), `web/send_notification.php` (a hand-picked device audience), `web/view_class_student.php` (the contact-detail rule may differ), `web/edit_class.php` (the "extra students" clean-up), `web/manage_guides.php` (editing guides not in English), `web/health-check.php`, `web/firebase-messaging-sw.php` (browser push).

## Not determined

- Whether the website calls `quiz_info.php`.
- Whether the Play listing really points at `delete-account.php`, and whether the `/app` QR code is in print.
- Whether an uptime monitor calls `health-check.php`.
- Whether the new API sets the security headers PHP's Apache config sets.
- The save helpers of the PHP web pages (`save_*.php`, `class_sessions_api.php`) were matched to routes by capability, not field by field.
- The Next.js website (tsr-web) is not part of this audit; only its six Library routes and article search are ported.
