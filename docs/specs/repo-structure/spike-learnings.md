# Learnings from the spikes (2026-11-09)

What the `tsr-app` sample (one real slice, `POST /feedback`) tells us about the plan in
`docs/specs/repo-structure.md`. Planning input only: nothing here is built or decided.

Evidence sources: the sample's files (paths below are relative to `tsr-app/` unless they start
with `tsr-account/`), the results recorded in `docs/handover.md` (verified 2026-11-08), and today's
navigation trial. Nothing was rebuilt or rerun for this review.

## Top 3 recommendations

1. **The central Stage 2 claim has not been tested.** That claim is "the same contract tests
   pass on PHP and on the new API". The 7 contract tests have run only against the new API. The
   gateway's PHP fallback is a hard-coded 404 (`hosts/gateway/default.conf:29-32`). Running the
   existing tests against tsr-account is the next spike, and it is smaller than anything else on
   the list. The code already shows likely divergences (section 2).
2. **Shrink `spec/` to what earns its place.** Keep `glossary.md` and the HTTP-only contract
   tests. Make `api.yaml` either generated from code, or hand-written and checked by a tool. Drop
   `events.yaml` (AsyncAPI) and `schemas/` until something consumes them. Drop "types are
   generated from the spec" as a current claim.
3. **Grow structure on demand, not up front.** Delete the empty scaffolding (78 `.gitkeep` files
   across 8 unbuilt domains and 5 unbuilt hosts). Remove the navigation pointers to files that do
   not exist. Replace handover step "CLAUDE.md + spec stubs for the other 8 domains" with "a
   folder appears with its first real file".

## 1. What the spikes proved works

| Claim in the plan | Evidence | Verdict |
|---|---|---|
| Modular monolith, one project per domain, module boundaries checked by a test | `hosts/api/tests/ModuleBoundaryTests.cs` checks assembly references against `<Context>Module.Dependencies` and builds DI with only the listed modules (`ValidateOnBuild`). 10 boundary tests pass. | Works. Rules 2.4/9 are now tool-enforced for C#, not review-only. |
| Vertical slice in one file | `domains/platform/api/features/submit-feedback/SubmitFeedback.cs` (120 lines) holds the request, endpoint, handler and event. It reads top to bottom: 401, 403, 422, act. | Works and is easy to review. |
| Value objects carry validation; `Result<T>` for expected failures | `api/domain/ClientId.cs`, `FeedbackText.cs`, `shared/api/Result.cs`. 15 unit tests sit next to the code (`*.Tests.cs`, compiled by `api/tests/*.csproj` with `Compile Include="../**/*.Tests.cs"`). | Works. Co-located tests are a good fit for agents. |
| Outbox in the same transaction | `SubmitFeedback.cs` `InsertAsync` plus `shared/api/Outbox.cs`. | Written only. No relay exists and no test reads the outbox. |
| Identity fails closed | `domains/identity/api/IdentityModule.cs` throws outside Development. `hosts/api/tests/IdentityFailsClosedTests.cs` covers it. | Works. The Firebase verifier is now the real gate for Stage 2 going live. |
| Root pub workspace (review finding 2) | Root `pubspec.yaml` (`name: _`, 3 members). Per the handover, a debug APK and an iOS `--no-codesign` build were made from it. | Proven. Close the open point in the plan, section 6. |
| Flutter package boundaries can be checked | `depend_on_referenced_packages` is in `lints` core (`lints-6.0.0/lib/core.yaml:19`), which `flutter_lints` includes. | Free import check, like the C# test: it enforces "declared", not "allowed". |
| Docker build context with Flutter beside the API (review finding 13) | `.dockerignore` patterns `domains/*/app`, `shared/app`, `hosts/app`. | Works. Pick the pattern option and close the finding. |
| nginx gateway, one block per moved path | `hosts/gateway/default.conf`; BusyBox `wget` healthcheck in `docker-compose.dev.yml`. | Works. Close the nginx-or-Caddy open point with nginx. |
| Zero warnings and central package versions | `Directory.Build.props` (`TreatWarningsAsErrors`, `latest-recommended`), `Directory.Packages.props`. Build: 0 warnings. | Works. Central versions made the NuGet audit fix a one-file change. |
| Agent navigation via handover plus domain `CLAUDE.md` | Trial: the handover led straight to the right files. | Partly works (section 2). |

## 2. What hurt or surprised us

**PHP parity is assumed, not shown.** All of these are visible without running anything:
- The permission port has a different shape. PHP calls `api_require('feedback:create')`
  (`tsr-account/web/api/mobile/routes/feedback.php:13`), which reaches
  `PermissionsModel::can($userId, 'resource:action', $target)` with scope targets
  (`tsr-account/web/models/permissions.php`). C# `Permissions.CanAsync(caller, 'feedback:create:self')`
  takes the full catalog name and has no target
  (`domains/access/api/features/check-permission/Permissions.cs`). Scopes, the gender rule and the
  class-active rule are all missing. Today's port could not carry a scoped check. That port is
  the most important interface in the plan, and it is still a guess.
- Malformed fields are untested. PHP returns 422 for a non-string `clientId` or `text`
  (`!is_string`). `api.yaml` promises "malformed → 422, never 400". ASP.NET minimal-API binding
  usually returns 400 for a JSON type mismatch, and no contract test sends `{"clientId": 123}`.
  I could not run it, so this is an untested claim, not a confirmed bug.
- Coverage has a gap. PHP's `tsr-account/tests/mobile-api/FeedbackSubmitTest.php` checks that the
  same clientId from a different member creates a new message. The contract tests use one member
  (`spec/tests/Target.cs`), so they cannot check it.
- Auth differs. PHP needs a Firebase bearer token (`tsr-account/web/api/mobile/lib/auth.php:108-115`).
  The sample uses `X-Dev-Token`. `Target.cs` has `TSR_AUTH_HEADER`/`TSR_AUTH_VALUE` for this, and
  tsr-account has `tools/auth-emulator`, but nobody has wired them together.

**The plan says spec-first, but the code came first.** `SubmitFeedback.cs:12` pointed to
`spec/api.yaml` before the file existed. The spec was written afterwards from the code. For a
solo developer working with agents, that is evidence of how work actually happens. A spec-first
rule that nobody follows is worse than no rule.

**The spec written after the code already drifts, and nothing catches it.**
- In `spec/schemas/feedback.json`, `ClientId` has `pattern ^[A-Za-z0-9-]{1,36}$`. The server
  trims first (`ClientId.cs`, and PHP `feedback.php:25`), so `" abc "` is valid on the wire but
  invalid by the schema. The schema's description admits this in prose.
- `FeedbackText` `minLength: 1` cannot express "not only spaces". The description says so too.
- The 2000 limit is written in 5 files in tsr-app (`FeedbackText.cs`,
  `send_feedback_view_model.dart`, `glossary.md`, `feedback.json`,
  `SubmitFeedbackContractTests.cs`), and in 2 more in tsr-account. The spec added copies; it did
  not remove any.
- No tool reads `api.yaml`, `events.yaml` or `feedback.json`. The contract tests do not load
  them. The C# records and the Dart repository (`json['id'] as int?`) are hand-written.

**Navigation files point to things that do not exist.**
- Root `CLAUDE.md` routes to `hosts/CLAUDE.md`, `shared/CLAUDE.md`, `db/CLAUDE.md`,
  `legacy/CLAUDE.md`, `tools/CLAUDE.md` and `.claude/skills/`. None exist; `.claude/skills/` is
  empty.
- `AGENTS.md`, `domains/CLAUDE.md` ("Adding a slice: `.claude/skills/add-slice`") and the
  `PlatformModule.cs` comment repeat these pointers.
- A dangling pointer costs an agent a wasted call and some trust in every other pointer.

**Writing a spec needed facts that `domains/CLAUDE.md` does not reach.** These were the outbox
envelope (`shared/api/Outbox.cs`), the error body (`shared/api/Problem.cs`), the dev auth header
(`DevTokenVerifier.cs`) and the table (`db/migrations/2026_11_09_feedback.sql`). Finding them took
about 6 tool calls. These are the cross-cutting conventions every slice uses.

**Scaffolding without content.**
- 78 `.gitkeep` files hold up empty `spec/`, `api/` and `app/` trees for 8 domains.
- Five hosts (`calendar`, `media`, `scheduler`, `site`, plus the `push-worker`/`worker`/`indexer`
  folders) have no files.
- An agent reading the tree cannot tell what is real.

**The cost of adding a module is spread out.** A new domain is edited into `hosts/api/Program.cs`,
`hosts/api/Modules.cs` and the `Register()` switch in `ModuleBoundaryTests.cs`, plus
`TsrApp.slnx`. Each domain carries up to 3 csproj files and 1 pubspec, about 27 build files at
nine domains (plan section 5 already names this cost).

**Environment traps** (from the handover):
- OrbStack owns port 8080, so the gateway runs on 8088.
- The NuGet audit fails on old pins.
- Code-point counting was needed to match `mb_strlen`.
- A nested bind mount littered `db/migrations`; seeding now goes through `db/dev-init/load.sh`.

These are cheap once written down. Keep them in the README and the handover, not in the plan.

**Table ownership is not checked by any tool.** `db/migrations/2026_11_09_feedback_permissions.sql`
is platform's migration, but it inserts into `permissions` and `role_permissions`, which belong to
`access`. That is reasonable, since a domain registers its own permissions, but rule 4 ("every
table has one owner") is review-only. The plan should say so, or name this exception.

## 3. Plan decisions to revisit

| # | Decision (plan section) | Evidence | Recommendation |
|---|---|---|---|
| D1 | `spec/` holds glossary, OpenAPI, AsyncAPI, JSON Schema and contract tests (2.3) | Section 2: the spec was written after the code, already drifts, and nothing reads it. The glossary's "Words we do not use" and its JSON/column mapping (`spec/glossary.md`) are information found nowhere else. | **Change.** Keep `glossary.md` and `tests/`. Keep one `api.yaml` (see D2). Drop `events.yaml` and `schemas/` until a relay and a consumer exist. Put event shapes as a short table in the domain `CLAUDE.md` until then. |
| D2 | "Types are generated, rules are proven"; generated clients for Dart, C#, Go and PHP (2.3) | No generator exists. The types are 2 fields each. PHP's published `api-docs.json` is already generated from code (the route table), not hand-written. | **Change.** Make it "rules are proven by contract tests; the published OpenAPI is checked against the code". Asif chooses between (a) generating OpenAPI from the C# endpoints and committing a snapshot with a CI diff, and (b) a hand-written `api.yaml` with a check that every route exists in both. Both need a spike (S3). Drop type generation until there is a second consumer of a contract. |
| D3 | Spec-first for each domain (Part 1.1, 2.3) | Code came first in the only slice. | **Change** to "contract-tests-first". The HTTP tests are the executable spec and the thing PHP parity depends on. |
| D4 | Every domain has `spec/`, `api/` and `app/` scaffolded (tree, 1) | 78 `.gitkeep` files, 8 empty domains. | **Drop the scaffolding.** Keep the domain list as a table (`domains/CLAUDE.md` already has it). A folder is created with its first real file. Delete the `.gitkeep` files. |
| D5 | One `CLAUDE.md` per area plus skills (3.4, root `CLAUDE.md`) | 6 dangling routes. The trial needed 6 calls for shared conventions. | **Change.** Route only to files that exist. Add one short "Slice conventions" block to `domains/CLAUDE.md`: error body, outbox call, auth in dev, migration naming and location, the 401→403→422 order. Write a skill only after the same task has been done by hand twice. `add-slice` comes after slice 2. |
| D6 | The `access` `can()` port is "the one dependency every domain lists" (2.1, 2.4) | The sample's `CanAsync(caller, fullName)` has no target or scope. The PHP model is `can(userId, action, target)`. | **Keep the decision, but treat the port's shape as unproven.** It needs a slice with a scoped check before the plan calls it settled (S4). |
| D7 | Module-boundary test; tool open until the API language is chosen (2.4, 6) | Built and passing in C#. Dart lint gives the Flutter side for free. | **Keep.** Close the open point. Make `Modules.All` the one list that `Program.cs` and the test both read, so adding a domain is one edit. |
| D8 | Per-domain Flutter packages in a root workspace (2.2) | Store builds work. The import lint comes free. Cost: one pubspec and one `analysis_options.yaml` per domain. | **Keep**, but create a domain's package only when it gets its first screen (the plan's "gradually" already says this). |
| D9 | One csproj per domain plus a co-located test project (2.1) | It is what makes D7 possible. | **Keep.** Accept the build-file count. |
| D10 | Gateway: nginx or Caddy (3.1, 6) | nginx works with BusyBox healthcheck. | **Keep nginx**, close the open point. |
| D11 | Hosts for scheduler, site, calendar, media drawn in the tree (3.1) | All empty. | **Keep in the plan as text, drop from the tree** until each has code. |
| D12 | `platform` as a domain (4) | It works as a home for one slice, but its `CLAUDE.md` lists audit log, geo, lookups and release notes: a grab bag. | **Keep for now.** Revisit when a second, unrelated slice lands there. |
| D13 | Outbox in Stage 1 before any consumer (Part 1, Stages) | The sample writes rows that nothing reads (`2026_11_10_outbox.sql`: "rows simply accumulate"). | **Keep**, since it is cheap. Add a contract test or integration test that one row is written per new submission and none per replay. Today that rule (glossary "Submitted") is untested. |

## 4. Open questions only Asif can decide

1. **Spec authority:** should the OpenAPI be generated from code (like today's PHP
   `api-docs.json`) or hand-written and checked? This decides D2 and D3.
2. **AsyncAPI and JSON Schema:** drop them until a consumer exists (recommended), or keep them as
   documentation that nothing checks?
3. **Contract test language:** C# xUnit over HTTP (as now) is "any implementation" in practice.
   Is that acceptable, or must the tests be language-neutral (for example `.http` files or
   Hurl)? My recommendation is C#: it already runs.
4. **Scaffolding:** delete the empty folders and `.gitkeep` files now, and drop "stubs for the
   other 8 domains" from the handover's next steps?
5. **Permission naming in the port:** should callers pass `resource:action` plus a target (the
   PHP model) or the full `resource:action:scope` name (the sample)? This decides how every
   handler is written.
6. **Spike history:** this folder has no git on purpose. If the learnings should survive, should
   the sample move to a branch, or does only this note survive?

## 5. What to spike next, smallest first

| # | Spike | Size | Answers |
|---|---|---|---|
| S1 | Run the existing 7 contract tests against local tsr-account PHP, using `TSR_BASE_URL` and `TSR_AUTH_*` with a token from `tsr-account/tools/auth-emulator`. First check what auth the PHP dev stack accepts. | Hours; no new code | Whether the Stage 2 parity claim holds. It is the claim the whole migration depends on. |
| S2 | Add the missing contract tests: wrong type gives 422, and a second member with the same clientId gets a new id. Run them against both implementations. | Small | The 400/422 risk and the coverage gap. |
| S3 | Generate OpenAPI from the C# endpoints (built-in ASP.NET Core OpenAPI; not verified for this setup) and diff it against the hand-written `api.yaml`. | Small | D2: whether code-first gives a usable published contract and removes the hand-written copy. |
| S4 | Build one slice with a scoped permission or a cross-domain read, for example `GET /me/permissions` in `access`, or a gender-scoped list. | Medium | D6: the shape of the `can()` port, and whether rules 2, 3 and 9 survive a real dependency. `platform → access` only exercised a yes/no check. |

Not worth spiking before the plan is final: the scheduler or relay, the site generator, XR, and
per-domain hosts. The plan already defers them, and the sample adds no evidence about them.
