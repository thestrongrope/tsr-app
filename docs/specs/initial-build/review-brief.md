# Security and quality review of the build-out: the brief every reviewer follows (12 Nov 2026)

Read-only. Do not edit, create or delete any file; put ALL findings in your reply.

## What you are reviewing
A C#/PostgreSQL API rebuilt to parity with a PHP/MariaDB API. PHP is the reference: its quirks are copied on purpose, so "differs from good practice" is not a finding by itself; "LOOSER than PHP" is. Between commit `cc83a55` and `HEAD` of branch `dotnet-11`, 75 routes were ported quickly ("build-out"), then tested by separate agents. You review ONE area of that change, named in your task. See it with `git diff cc83a55..HEAD -- <paths>` and by reading the files at HEAD.

- The rules: `CLAUDE.md` (root) rules 1 to 8, `domains/CLAUDE.md` rules 1 to 12, the `CLAUDE.md` of each domain you review, `docs/specs/initial-build/fill-phase-design.md` (D1 to D8).
- The PHP reference: `build/parity-php/src/web/` (`api/mobile/index.php` is the router, handlers in `api/mobile/routes/`, models in `models/`, helpers in `functions.php` and `api/mobile/lib/`).
- Do NOT read `docs/specs/initial-build/lane-*-notes.md`, `test-*-notes.md` or `build-out-findings.md`: they are the authors' and testers' own accounts, and your view must not be anchored on them.

## What to look for (tests already prove status codes and shapes for the cases they contain; look for what they cannot)
1. **Authorization and row scope.** For every route: caller → `Permissions.CanAsync` → validate → act, in PHP's order; the permission, target and reach (gender, assigned classes, class admin, own data only) exactly as PHP. Can any caller read or change another member's data, or data outside their reach, through a path id, a query parameter, a body field, a sub-query, an export, or a published command another domain calls? Separate "new code LOOSER than PHP" (a hole) from "PHP itself is loose" (copied; list it as such).
2. **Irreversible or outward effects.** Deletions, anonymisation, pushes, WhatsApp sends, sheet writes: can they fire for the wrong member, twice, on a refusal path, or with attacker-influenced targets? Is anything real reachable when the credential setting is absent?
3. **Injection and request forgery.** SQL is parameterised (no name or fragment built from caller input)? HTML sent to the PDF renderer fully encoded? A proxied or outbound URL (the WhatsApp notifier, Google, FCM, Elasticsearch) built only from configuration plus validated, encoded segments: can a caller steer the path, host or query? Search query text passed as a value, never as query syntax?
4. **Secrets and personal data.** Service-account keys, access tokens, device tokens, QR or pairing codes, mobile numbers, emails: never logged, never in an outbox payload, never returned to a wider audience than PHP returns them to; `Cache-Control: no-store` where PHP sets it.
5. **Writes.** One transaction per change; no partial write on failure; races (two callers at once), locks and their timeouts; exactly one outbox event per state change and none on a refusal; exceptions caught too broadly, or a failure turned into a success.
6. **Inputs that reach a 500 or unbounded work.** NUL bytes, huge or non-numeric ids, wrong JSON types, oversized bodies and lists, absurd dates; a query or a loop without a bound; anything a low-privilege caller can make expensive.
7. **Case sensitivity.** Every string column is `citext`; a C# string parameter is sent as `text`, and `citext_column = {value}` then compares case-sensitively unless cast `{value}::citext`. Flag each such comparison where PHP would match without regard to case (some are already known and being fixed: still list what you see).
8. **Cross-domain boundaries.** Reads of another domain only through `v_*` views; writes only through the owner's published command on the caller's transaction; a view exposing more than its readers need; a migration that does more than it says.
9. **Tests that prove nothing.** Name the guards in your area that no test would catch if deleted (read the tests in `db/tests/Test*Tests.cs` and the lane's Hurl files).
10. **Simplicity.** Duplicated logic, dead code, a second abstraction where one would do, only where it raises the cost of the next change.

## Limits
- You may run `dotnet build TsrApp.slnx` and unit tests of single projects (prefix every dotnet command with `export DOTNET_ROOT="$HOME/.dotnet" PATH="$HOME/.dotnet:$PATH"`; never `dotnet test` at the repo root).
- Do NOT run Hurl, contract scripts, `tools/test-stack.sh`, `dotnet test db/tests`, docker or compose commands, and do not query any database or make any network request: the dev stack on :8088/:5433 holds real production data and must not be touched.
- Do not read `~/Projects/tsr-account`. Python only via `uv run python`. Send nothing to another vendor's model.

## Report (in your reply; at most 1100 words)
Start with one line: whether you found an authorization, row-scope, data-exposure, injection or irreversible-action hole. Then findings ordered by severity (blocker / should-fix / note). For each: file:line, the concrete input or sequence that triggers it, what PHP does in the same case (file:line), and how sure you are. Then: PHP looseness that was copied (short list); guards no test would catch; what you did not check.
