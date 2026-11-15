# Lane whatsapp: notes for the test phase

Ten `/admin/whatsapp/*` routes of notifications, built 12 Nov 2026 as proxies to the notifier. PHP: `web/api/mobile/routes/whatsapp_reminders.php` (R), `web/models/whatsappreminders.php` (M). Notifier source WAS in the copy: `notifier/server.js`, `reminder-fields.js`, `mobile.js`, `db.js` (N); the contract below is read from it.
Code: `domains/notifications/api/features/whatsapp-*/`, `domain/Notifier*.cs`, `WhatsAppRoutes.cs` (`MapWhatsApp`, called from `NotificationsModule.MapNotifications`). Contract: `domains/notifications/spec/api.yaml` (the paths block is the whatsapp lane's).

## Settings
- `TSR_NOTIFIER_URL` (PHP `NOTIFIER_URL`, default `http://notifier:3000`). Optional. Present: must be absolute http(s), a host, no user info, query or fragment, else the API refuses to start. Absent or empty: the API starts and every call answers as an unreachable notifier (NO default to `http://notifier:3000`; the compose files must set it where PHP's default was relied on).
- Client: 30 s timeout (PHP curl 30 s), 1 MB answer cap, redirects not followed.

## Common behaviour (all ten)
Order: caller (401), `whatsapp:manage` via `Permissions.CanAsync(.., AccessTarget.None)` (403 "You do not have permission to do that"), then limits, body, notifier. A notifier answer of 400 or more becomes the SAME status with `{"detail": <notifier error text>}` or "The reminder service could not do that. Please try again." when it has no text (R `api_whatsapp_ask`). Unreachable (refused, timeout, over 1 MB, setting absent) is 502 `notifier unreachable` (PHP appended curl's error text; dropped here). Below 400, the body is used only when it decodes to a JSON array or object, else empty.
Ids: the path segment is read as PHP `(int)` (numeric prefix, else 0), then sent as an integer: `12/../x` becomes 12. Dependencies added: `access`, `platform`. No table, no migration, no outbox event (PHP records nothing locally for these; it only writes `log_event` lines, ported as structured logs without secrets).

## Per route
| # | Route | PHP | Slice | Notifier call | Mapping |
|---|---|---|---|---|---|
| 1 | GET /admin/whatsapp/reminders | R:92 | whatsapp-reminders | GET /reminders | rows cast like `api_whatsapp_reminder`; `{reminders}` |
| 2 | PUT /admin/whatsapp/reminders/{id} | R:106 | whatsapp-reminder-update | PUT /reminders/{id} `{fields:{snake_case}, updated_by: token}` | id <= 0: 400 "missing or invalid id" (M:forward), no call; notifier 400/404 pass; 200 `{reminder}`. Keys present (even null) are sent; NUL or over 500 chars: 422 (deviation) |
| 3 | POST /admin/whatsapp/reminders/{id}/run | R:163 | whatsapp-reminder-run | POST /run-weekly `{reminder_id, dry_run, triggered_by: token}` | dry run unless `dryRun` is the literal false; notifier 400/409 pass; 202 `{runId, dryRun}` (id 0 is sent, notifier answers 400 as in PHP) |
| 4 | GET /admin/whatsapp/runs | R:130 | whatsapp-runs | GET /recent-runs?limit=&reminder_id= | digits only, max 18 (deviation), last repeated key; `{runs}` |
| 5 | GET /admin/whatsapp/runs/{id} | R:145 | whatsapp-run | GET /runs/{id} then GET /runs/{id}/messages | id <= 0: 400; notifier 404 "run not found" passes; `{run, messages}` |
| 6 | POST /admin/whatsapp/test | R:176 | whatsapp-test | POST /send-test `{mobile, message, triggered_by: token}` | trimmed strings else ""; notifier 400/409/500 pass; `{runId, status}` (status default "sent") |
| 7 | GET /admin/whatsapp/link | R:207 | whatsapp-link | GET /status | `no-store` first; 90/min bucket `whatsapp_link_read`; not 200 or not JSON: 503; state connected / waiting (`awaiting_qr`) / offline using PHP `empty()` |
| 8 | GET /admin/whatsapp/link/qr | R:225 | whatsapp-link-qr | GET /qr | `no-store`; 90/min same bucket; notifier 404: qr null, not stale; no qr text or not 200: 503; age unknown, negative or over 60: qr null, stale true |
| 9 | POST /admin/whatsapp/link/relink | R:255 | whatsapp-link-relink | POST /relink `{}` | `no-store`; 6/min bucket `whatsapp_link_change`; audit row BEFORE the call; not 200: 502 "Re-link failed. ..."; `{ok:true}` |
| 10 | POST /admin/whatsapp/link/logout | R:265 | whatsapp-link-logout | POST /logout `{}` | same, "Logout failed. ..." |

`no-store` is set by the route precheck, so it is on 401 and 403 too (PHP sends it first). Audit row: `PlatformCommands.RecordAdminAccessAsync` through the notifications context (only for privileged roles, as PHP).

## Assumptions
1. Notifier contract is N's `server.js` as of the parity copy; `/status` answers `{connected, awaiting_qr, last_seen}`, `/qr` `{qr, generated_seconds_ago}`, dates as `Y-m-d H:i:s` strings (`dateStrings: true`) in UTC.
2. Rate-limit key is the caller's token (PHP: `user<id>`); in memory per process (MemberRateLimit), not shared across API instances.
3. A non-object element in a list answer is skipped (PHP would raise a TypeError, 500).
4. The audit for routes 9 and 10 runs after the rate limit, as PHP; no other PHP audit exists for this file.
5. Caps (query digits 18, text fields 500, mobile 40, message 4096) are mine, not PHP's: confirm against the notifier and the app.
6. No outbound pairing: the notifier's `/send` (queue sender) is not called by these routes.

## Security and privacy flags found in PHP (copied, not fixed)
- PHP forwards the notifier's `error` text on every status, including its 500s (`e.message` of a database or Baileys error), to the admin. Copied (only to whatsapp:manage holders).
- PHP stores the acting member's token (`triggered_by`/`updated_by`) in the notifier's tables, not users.id.
- `POST /test` sends a real message to any number an admin types: no allowlist, no per-member limit (PHP none; consider one).
- PHP's `NOTIFIER_URL` default points at a plain-http, unauthenticated service; the notifier has no auth of its own.
- The 502 text of PHP leaked curl's error (host name); dropped here (deviation).

## The test phase must prove
- [ ] Every route: 401 without sign-in, 403 without `whatsapp:manage`, before any notifier call (stub notifier receives nothing).
- [ ] A malformed or missing `dryRun` (absent, null, "false", 0, [false], invalid JSON) NEVER sends: the notifier receives `dry_run: true` or no call (422 on invalid JSON).
- [ ] Ids cannot steer the proxied path: `12/../../send`, `..`, `%2e%2e`, `12?x=1`, huge digits, empty: the notifier sees only `/runs/<int>` or no call.
- [ ] Query injection on runs (`limit=5&x=1`, `reminderId=7%26y`) reaches the notifier only as digits.
- [ ] Notifier absent (setting unset), refusing connections, timing out (30 s), answering over 1 MB, answering non-JSON, answering 3xx: the answers in the table, never a 500, no internals in the body.
- [ ] Notifier errors: 400 text, 404, 409 (run in progress), 500 pass with their status and text; empty error text gives the fallback.
- [ ] The QR never appears in logs; `Cache-Control: no-store` on 200, 401, 403, 429, 503 of routes 7 to 10; a stale or ageless QR is withheld.
- [ ] Rate limits: 90/min on 7 and 8 (shared bucket), 6/min on 9 and 10 (shared), 429 text; a refused call is not counted.
- [ ] Routes 9 and 10 write one `admin_access_log` row before the notifier call, also when the notifier fails; none on 403 or 429.
- [ ] Update: only present keys forwarded, names mapped to snake_case, `updated_by` is the token; NUL or overlong text is 422, never 500.
- [ ] Test message: non-string mobile or message is sent as "" (notifier 400); NUL or overlong is 422; the number and text are in no log line.
- [ ] Date mapping: `updated_at`, `started_at`, `finished_at`, `sent_at` with a Z; zero dates null; `from_date`/`to_date` as is.
- [ ] PHP parity of all ten responses on the parity stack against the same notifier.
