# Initial build: reaching the baseline (draft, 2026-11-10)

Draft for Asif to review. Nothing here is started. It changes the "Order of work" in
`../repo-structure/migration-from-tsr-account.md` (see "What this changes"); that file is not edited
until this draft is agreed.

## Goal

Build the new API and the static site locally until they do what tsr-account does today, then
publish once. tsr-account keeps running and shipping until then.

**Baseline means:** every path in tsr-account's API (191 today) answers the same way from the new
API; the store-live Flutter app works against it unchanged; the static site replaces tsr-web's
public pages. No new features. The Flutter app is not restructured.

## What this changes

| | Agreed earlier today | This draft |
|---|---|---|
| How routes arrive | one at a time in production, through the gateway | built in bulk locally |
| Postgres | PHP is ported to Postgres first (3 to 5 weeks) | PHP is never ported; data moves once, at cutover |
| First production change | the Postgres cutover | the publish |

The saving is real: the PHP SQL is not ported twice. The price is one larger cutover day.

## Decisions for Asif

1. **Cutover: all at once, or in groups?** All at once is what "PHP never touches Postgres" needs,
   because the two APIs cannot share a database. Recommended: all at once, behind the gateway, after
   a full rehearsal, with rollback to PHP and MariaDB inside a short window. If you want groups,
   PHP must move to Postgres first and the earlier order stands.
2. **Local git.** Recommended: `git init` locally with no remote. The build needs it (diffs for
   review, worktrees for the developer sub-agent, undo; today there is no backup). At publish the
   public repo starts from one baseline commit, so none of this history is published.
3. **Tracking.** Recommended: no GitHub issues or projects before the baseline. The checklist at
   the end of this file is the tracker. Spec, plan and PR per change start after the baseline.

## How parity is proven

- **Hurl contract tests, written against PHP first.** For each path: write the Hurl file, make it
  pass against tsr-account running locally on synthetic data, then build the slice until the same
  file passes on the new API. A path is done when both pass.
- **Permission matrix.** For each role and each path, the same allow or deny on both. This is the
  highest risk: `PermissionsModel::can()` mixes scopes, the teacher gender rule and class state.
- **The real app.** The current Flutter build runs its main flows against the local stack.
- **Drift.** tsr-account's `web/api-docs.json` is pinned at a commit. A weekly diff lists paths
  that changed; their Hurl files are rerun against PHP and the slice is fixed.

## Phases

0. **Ground.** Move the sample to the decided stack (Postgres with `citext`, EF Core and Npgsql,
   NUnit, Hurl). Decisions 1 to 3.
1. **Parity harness.** tsr-account runs locally on synthetic data; `POST /feedback` Hurl passes on
   both. This closes the open point "the contract tests have never run against PHP".
2. **Foundation.** `identity` (Firebase verifier, emulator locally), `access` (`can()` with scopes
   and the gender rule, with the permission matrix), the gateway, the outbox relay.
3. **Domains,** each to full parity before the next: `platform`, `membership`, `classes`,
   `assessment`, `notifications` (with its workers), `content`, then the MIS reports last.
4. **Site.** Public pages from `content`, replacing tsr-web's.
5. **Rehearsal.** Data move from a synthetic MariaDB copy to Postgres; the whole Hurl suite and
   the matrix; the Flutter app; the two Postgres guards from the migration file.
6. **Publish.** One baseline commit to the public repo. The production cutover (Dokploy, data,
   rollback) gets its own plan and Asif's approval; it is not part of this one.

## How the work is run

- Fable plans and checks. Haiku does recon, Sonnet (`developer`) builds one slice at a time test
  first, `qa` and `security` review the diff, and GPT (Codex) or Grok give a second opinion on
  serious findings.
- A checkpoint to Asif after each domain: paths done, tests, findings, spend.
- No real member data, ever. The data move is rehearsed on synthetic data only.

## First batch (phases 0 and 1), once this plan is agreed

Checked 2026-11-10: Hurl is not installed; a `postgres:16` image is present locally (the version to
target is not decided); tsr-account is on branch `docs/patrol-plan-ios-done` with 14 uncommitted files.

Needs Asif's yes before it starts:

- The first commit here (sub-agents work from diffs and worktrees).
- Installing Hurl (`brew install hurl`).
- A Postgres container in this repo's dev stack, replacing MariaDB there. The dev volume is reset.
- Starting tsr-account's own dev stack locally for the parity run. Its files are not edited.

| Task | Who | Done when |
|---|---|---|
| 0a Postgres, EF Core and Npgsql, `citext`, migrations for `feedback`, `articles`, outbox | Sonnet `developer` | build 0 warnings; unit and boundary tests pass |
| 0b xUnit to NUnit (done: 15 + 20 + 12 cases) | Haiku (mechanical) | same tests, same counts |
| 0c C# contract tests to Hurl files (done: 8 + 4 cases) | Sonnet `developer` | 7 + 4 cases pass against the stack |
| 1 Run the `POST /feedback` Hurl file against tsr-account's PHP | Sonnet `developer` | pass, or a list of differences |
| Review of the batch | `qa`, `security`; GPT (Codex) on serious findings | findings settled or reported |

0a goes first; 0b and 0c follow it, one at a time (they touch the same files). Task 1 can run beside
them. Budget: five sub-agent runs and one review pass, then a checkpoint with the spend.

## Not known yet

- **Size.** 191 paths and 43 PHP models, with the 3,464-line MIS model the largest single piece.
  No estimate until `platform` and one larger domain are done and the pace is measured.
- Whether tsr-account's dev stack accepts the synthetic members and the auth emulator as-is.
- How much behaviour lives in PHP pages and cron jobs outside the 191 paths.
- Rollback after cutover loses writes made on Postgres unless they are replayed; needs a design.

## Checklist

- [ ] Decisions 1 and 3 (decision 2 done 2026-11-10: local git, no remote)
- [x] Phase 0: sample on Postgres, EF Core, NUnit, Hurl
- [x] Phase 1: parity harness, `POST /feedback` green on both
- [x] Phase 2: identity, access with the permission matrix (2026-11-10; the outbox relay is deferred to its first consumer, no gateway change needed before production)
- [ ] Phase 3: platform · membership · classes · assessment · notifications · content · MIS
- [ ] Phase 4: site
- [ ] Phase 5: rehearsal
- [ ] Phase 6: publish (cutover planned separately)

## Checkpoint 1 (2026-11-10): phases 0 and 1

Done and re-run by the orchestrator: Postgres 18 with EF Core and Npgsql, `citext` by convention with
a guard test; NUnit 15 + 20 + 12; Hurl contract files (2 files, 14 requests) pass on the new API;
`submit-feedback.hurl` passes 10 of 10 on PHP (tsr-account `develop` at `ed72cd9`, synthetic data,
`tools/parity-php/`). Build 0 warnings. Not committed. Choices to confirm: `phase-0-design.md`.

Review findings to settle (qa and security, Sonnet):

- [x] Dev ports bound to every interface: bind 5433 and 8088 to `127.0.0.1`.
- [x] The API connects as a database superuser: a limited `tsr_app` role for the API, the owner for
      migrations only.
- [x] `--migrate` fails outside Development (identity refuses to start): must work without the dev
      verifier, with a test.
- [x] No test proves the outbox row is written in the feedback transaction, or that a replay writes
      none. Needs a database-backed test (the stack names Testcontainers).
- [x] Guard 2 reads the EF model, not the Postgres catalog; no check that the model matches the
      migrations.
- [x] Hurl is weaker than the C# tests in two places: one published slug exactly; pin the
      `publishedAt` format (`+00:00`) in the file and in `api.yaml`.
- [x] `README.md` says no Bash is needed, but `db/add-migration.sh` is a shell script.
- [ ] Images are not pinned by digest (low): declined: local dev only.

Checked and dismissed: the reported change of `publishedAt` from `Z` to `+00:00`. The old code
produced `+00:00` too (run in isolation); behaviour is unchanged.

Rule to reword: synthetic tokens "900000+" holds for this repo's seed, not for tsr-account's
generator (tokens from 1). The `.invalid` email is the guard that holds in both.

## Checkpoint 2 (2026-11-10): phase 2

Design: `phase-2-design.md` (approved, four decisions as recommended). Built by Sonnet, reviewed by
`qa` and `security` (no high or critical finding), fixed, and re-run by the orchestrator on a fresh dev
database: build 0 warnings; NUnit platform 15, identity 60, access 64, API boundary 17, site 12,
database 69; Hurl 6 files, 125 requests on the new API. On PHP (run by the build agent): identity 34 of
34, access 77 of 77. Catalog: 102 permissions, 7 roles, 88 role permissions, identical to PHP.

Open after phase 2:

- [ ] `hosts/app/lib/main.dart` still sends the removed `X-Dev-Token`: the Flutter app cannot sign in.
- [ ] Class-dependent permission paths are unit-tested only; parity needs `classes` fixtures (phase 3).
- [ ] Rule matching ignores case but not accents; MariaDB ignores both (`php-parity-feedback.md`).
- [ ] Platform's `Initial` migration has two foreign keys into `identity.users` (allow-listed in
      `db/tests/SchemaGuardTests.cs`); remove with a platform migration.
- [ ] Not built: grant and rule admin routes, name and picture writes on sign-in, `/auth/debug-token`,
      the account deletion command.
- [ ] `POST /auth/link` with no body needs `Content-Length: 0` through the gateway: check what the app sends.
- [ ] `hosts/api` is not a NativeAOT build; turning it on shows 37 EF and JSON warnings. Decide.
- [ ] `tsr_app` can write every table, the permission tables included: production setup undecided.
- [ ] 5 `unknown` cells in `permission-map.csv`.

