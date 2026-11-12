# Build-out lanes (12 Nov 2026)

Mode decided by Asif on 12 Nov 2026: port every remaining route from the PHP reference first, prove afterwards. A lane works in its own git worktree, commits to its own branch, and its gate is a clean build (0 warnings) plus the structure tests in `hosts/api/tests` and the touched domains' unit tests. No Hurl files, fixtures, database tests, reviews or stack use during build-out. Each lane leaves `lane-<name>-notes.md` here with its assumptions, suspected PHP holes and what the test phase must prove. "Ported" and "proven" are counted separately; the test phase (contract tests against PHP, database tests for writes, security review) follows per domain.

| Lane | Routes | Domain(s) | Depends on |
|---|---|---|---|
| A2 manage quizzes (main checkout, full proof) | 12 | assessment | |
| A3 scores, offline, sheet, publish | 5 | assessment | A2, the notify command |
| mcq-reports | 8 | classes (moved from assessment) | |
| sheets: standard MCQ update, quiz competition admin | 9 | assessment | |
| identity: debug token, deletion requests (member and admin) | 9 | identity | |
| access: permission grants, class access rules | 10 | access | |
| notify-core: devices, inbox, broadcast, class notifications | 14 | notifications | |
| whatsapp: reminders, runs, link (proxy to the notifier service) | 10 | notifications | |
| small: holy quran, access log and download, quran leaderboard and download | 5 | content, platform, classes | |
| later: pending nudge (1), search (1), `/me/guides` (2, not in the PHP copy) | 4 | | notify-core; an Elasticsearch decision; a fresh PHP copy |

Shared rules for every lane: PHP reference at `/Users/asifshakir/Projects/tsr-app/build/parity-php/src/` (read-only); nothing real is sent outward (push, WhatsApp, Google, Firebase admin calls go behind an interface whose real implementation is unverified and inert without its setting); the dev database is never touched; no lane edits the root `CLAUDE.md` or any count (the main thread does at merge).

## Result (12 Nov 2026)

All lanes are merged on `build-out`: 211 of 213 operations have a slice. 136 are proven against PHP (everything before the build-out, batch A1 and nine routes of A2); 75 are ported only. The two left are `/me/guides` and `/me/guides/{slug}` (not in the PHP copy under `build/parity-php/src/`). `hosts/api/spec/planned-surface.hurl` and the Hurl counts in the root `CLAUDE.md` are stale until the test phase: no Hurl file was run or written for the ported routes. Findings and open design points: `build-out-findings.md`.
