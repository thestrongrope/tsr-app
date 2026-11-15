# Test phase: the brief every test lane follows (12 Nov 2026)

The build-out ported 75 routes without proof. A test lane proves its routes and fixes what it finds. Read this file fully, then your lane's own notes.

## Your worktree and your stack
- You work in your own git worktree. FIRST run `git merge --ff-only dotnet-11` (your branch must start at the tip of the local branch `dotnet-11`; if it says already up to date, continue; if it fails and `git log dotnet-11..HEAD` is empty, run `git reset --hard dotnet-11`; otherwise stop and report).
- Commit on your worktree's branch as you go (a commit per proven group of routes; each message ends with the line `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`). Never push, never add a remote, never touch another worktree or the main checkout (except READING the PHP reference at `/Users/asifshakir/Projects/tsr-app/build/parity-php/src/`).
- You have your OWN synthetic test stack, selected by the `TSR_STACK` number given in your task. Start it with `TSR_STACK=<n> tools/test-stack.sh up` (it builds YOUR worktree's code; re-run `up` after code changes). Its gateway is `http://localhost:810<n>`, its vars folder `build/test-<n>/`. Prefix EVERY stack or contract command with `TSR_STACK=<n>`. When you finish, run `TSR_STACK=<n> tools/test-stack.sh down` (keep the volume).
- The PHP parity stack (`http://127.0.0.1:18091`, compose project `tsr-parity`) is SHARED by all lanes: never restart, rebuild, `down` or reset it. Load only your own fixture rows into it, through your own contract script, inside the lock (`tools/parity-lock.sh`; see how `tools/identity-contract.sh` uses it). `tools/access-contract.sh parity` needs `TSR_PARITY_SRC=/Users/asifshakir/Projects/tsr-app/build/parity-php/src`.

## Hard limits
- The DEV stack (`tsr-app-dev-*`, gateway :8088, db :5433, emulator :19099) holds REAL production data. Never touch it in any way. Never unset `TSR_STACK` for a stack command (the default stack belongs to the main thread).
- No bare `docker compose`, `docker exec` or `docker run`: only the repo's scripts. Do not hand-edit a database or repair data through API calls outside your fixtures; if a stack becomes unusable, stop and report.
- Synthetic data only. Fixture emails end in `.invalid`, or are exactly `<token>@thestrongrope.com` for a placeholder member; any other address breaks the synthetic guard and blocks the stack. Never real names, emails or phone numbers.
- Your fixture id block (so parallel lanes never collide on the shared PHP database): member tokens `92<n>000` to `92<n>999`, class ids `98<n>00` to `98<n>99`, every other row id `97<n>0000` to `97<n>9999`, where `<n>` is your `TSR_STACK` number. A row that must not exist is `99999999`. Rows your Hurl files create get database ids: your contract script deletes them (range-bound, by your tokens or classes) before each run.
- Every dotnet command starts with: `export DOTNET_ROOT="$HOME/.dotnet" PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"`. Never run `dotnet test` at the repo root (it would pick up other worktrees); after a failed build never trust `--no-build`. Run db tests as `dotnet test db/tests/Tsr.Db.Tests.csproj --blame-hang --blame-hang-timeout 3m --blame-hang-dump-type none` (about 420 tests plus yours; a count near 7 means a stale build).
- Python only through `uv run python` with the standard library; never `pip`, never bare `python3` (not even `--version`). Temporary files under `build/`, never `/tmp`. Install nothing, add no NuGet package. Do not read `~/Projects/tsr-account`. Send nothing to another vendor's model. Make no request to Google, Firebase, FCM, a real notifier or a real Elasticsearch.
- Do NOT edit the root `CLAUDE.md`, any built/planned or Hurl COUNT, `docs/specs/initial-build/build-out-findings.md`, or another lane's files. Shared files you may need to touch (a domain's `CLAUDE.md`, `PublishedViewsTests`, a shared helper) get the smallest possible edit.

## What "proven" means for each route
1. **A Hurl contract file per slice** in the owning domain's `spec/tests/`, named after the slice. It must pass on PHP FIRST, then on your stack: statuses, messages, response shapes, the order of checks, PHP's quirks. Behaviour only the new API has (a stricter rule, a 422 where PHP crashes, a route PHP cannot run in the parity stack) goes in a `-new-api.hurl` file. Reports and anything depending on "today" use explicit dates or fixtures relative to load time.
2. **Your own contract script** `tools/contract-<lane>.sh` (`test`, `parity`, `--prepare`), in the style of `tools/assessment-contract.sh`: it calls the synthetic guard, loads ONLY your fixture pair (`db/synthetic/<lane>-fixtures.sql` and `tools/parity-php/<lane>-fixtures.sql`), mints tokens into `<vars folder>/<lane>.vars` and `build/parity-php/<lane>.vars`, and runs your Hurl files. Your Hurl files read only variables your script writes (`auth_<lane>_*`). No two of your Hurl files write the same row (Hurl runs files in parallel).
3. **Database tests** in `db/tests/Test<Lane>Tests.cs` for what Hurl cannot see: rows written, exactly one outbox event per change and none on a refusal, transactions and locks (N simultaneous requests), and ROW SCOPE: for every route that returns or changes other people's data, a caller who must be refused or must see less (a gender admin asking for the other gender, a coordinator limited to one assigned class, a coordinator of both genders, a plain member, a stranger, a holder of only a named grant). Pin each refusal to its exact status and message.
4. **Prove the important guards**: for each write and each scope rule, remove the guard, see the test fail, restore the line by editing it back, `touch` the file, rebuild. Say in your notes which guards you proved this way.
5. **Fix what you find**, test first (the test fails, then passes). A bug is a difference from PHP, a 500 for bad input (NUL bytes, huge or non-numeric ids, wrong JSON types, oversized bodies, absurd dates), a row-scope or permission gap, a missing or extra event, a partial write. Where PHP itself is loose, copy PHP and record it; do NOT make behaviour stricter or looser than PHP on your own: write the proposal in your notes for the owner.
6. Where a route depends on an external service the parity stack does not have, prove everything up to the boundary on both sides (guards, validation, the "service unavailable" answer), and prove the rest on the new API with the fake at the boundary (a database test that swaps the interface; see how `db/tests` builds its API host and how `ReportsB5dTests` fakes the PDF renderer). Say plainly what stays unverified against the real service.

## Known patterns that were real bugs before (check each on your routes)
- A list or export that drops a reach limit PHP's model applies; a `{id}` in the path that is not limited to the caller's reach.
- A date or number pattern using `\d` (it matches other scripts' digits; `int.Parse` then throws): use `[0-9]`.
- Rounding a binary double where PHP rounds a decimal.
- A filter copied wrong from PHP (one export dropped every `.com` address). Read the PHP SQL line by line against the C# SQL.
- A second submission or a simultaneous one writing twice or writing two events.
- An email, name or reason with a NUL byte or over the column length: a 422, never a 500.
- A hand-written or generated migration that does more than it says (one recreated a whole schema). Read every migration your routes rely on.

## Inputs
- The lane notes named in your task (`docs/specs/initial-build/lane-*-notes.md`): the PHP file:line per route, the assumptions made, and the checklist of what to prove.
- `docs/specs/initial-build/build-out-findings.md`: the numbered findings named in your task are yours to settle (verify against PHP, test, fix, or write the decision needed).
- The rules: root `CLAUDE.md`, `domains/CLAUDE.md`, your domain's `CLAUDE.md`, `docs/specs/initial-build/fill-phase-design.md`.

## Budget rule
Prove routes one at a time, most sensitive first (writes, then anything returning member data, then the rest). A smaller fully proven set beats a larger half-proven one: if you cannot finish, stop after a complete route and list exactly what is left.

## Finish
- Gate: `dotnet build TsrApp.slnx` 0 warnings; every `*.Tests.csproj` of the domains you touched plus `hosts/api/tests` and `db/tests`; your contract script `test` (all your files pass on your stack) and `parity` (all your PHP-runnable files pass on PHP).
- Write `docs/specs/initial-build/test-<lane>-notes.md`: per route: proven (how) or not (why); the bugs found and fixed (what, the test); the guards proved by removal; each finding from the findings file: settled how, or the decision needed; what stays unverified against a real service; process slips, honestly.
- Reply in at most 220 words: routes proven of total, numbers (Hurl files and requests on each side, db tests), bugs fixed (one line each), decisions needed (one line each), commit hash(es), branch name, the notes path.
