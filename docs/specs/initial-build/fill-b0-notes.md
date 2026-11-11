# Fill batch B0 notes (11 Nov 2026)

Built: test stack, nine published views, the SQL-boundary test, the helper move, the slice template (`GET /class-levels`), rules text.

## Test stack
- `tools/test-stack.sh up|down|remove|status`: `docker-compose.dev.yml` under project `tsr-app-test` with `TSR_GATEWAY_PORT=8089`,
  `TSR_DB_PORT=5434`, `TSR_EMULATOR_PORT=19100` (compose defaults stay 8088, 5433, 19099, so dev is unchanged).
- No collision with dev (`tsr-app-dev`): container, network (`tsr-app-test_default`) and volumes (`tsr-app-test_db-data`,
  `_emulator-cache`) are prefixed by the project name; the three host ports were free and differ. The read-only bind mounts are shared files.
- `up` builds `hosts/api/Dockerfile` (the .NET 11 images build and run), migrates, seeds, waits for `/health` on :8089.
- Contract scripts have a `test` target (`tools/{identity,access,membership,platform}-contract.sh test`; tokens in `build/test/`).
  `dev` and `parity` are unchanged in behaviour. `mint-token.sh` reads `TSR_EMULATOR_PORT`.
- Dev has not been touched. Its `migrate` job would apply the views the next time it is run: that is Asif's call.

## Views (one `PublishedViews` migration per domain, hand-written, no designer file)
Created in registration order, so `membership.v_members` (left join of `identity.v_users` to `member_profiles`) follows identity.
Not exposed: `link` (class join code), guardian invite `code`, `created_by`-type columns, member email beyond `identity.v_users`.
`assessment.v_quiz_results`: per (class, member, quiz) `correct` and `max_marks` (questions of the quiz); `quiz_id`, `published_at` added.
`classes.v_classes.city/country` use the geo collation, so `db/tests/SchemaGuardTests.cs` lists them beside the table columns.

## SQL-boundary test (`hosts/api/tests/SqlBoundaryTests.cs`)
Reads string literals that contain a SQL word, plus `schema:` arguments in migrations. Watched it fail on a deliberate
`select ... from membership.member_profiles` in classes, then removed the violation. Frozen list (applied migrations that hold
cross-schema foreign keys; never grows): access `Initial`, platform `Initial` and `DropIdentityForeignKeys`.
Limit: SQL built from non-literal pieces, or a schema-qualified name outside a literal, is not seen.

## Helper move (D4)
`PhpValue`, `PhpText`, `JsonBody` and their tests moved from membership to `shared/api` (now `public`). Two changes forced by that:
`PhpValue.Int` is `ToInteger` (CA1720 on a public name; 5 callers), and platform's own smaller `PhpText` was merged into the shared
one (it clashed by name; `ToUpperAscii` and its test moved, nothing else changed).

## Slice template
`domains/classes/api/features/class-levels/ClassLevels.cs`: one static class, `SqlQuery<T>`, no handler. Auth stays `create`
(`api_authenticate(true)`, as the csv already said). The PHP parity stack was not up, so the Hurl file ran on the new API only.
Not done: a `glossary.md` for classes.

## Checks
See the report: build 0 warnings; every test project green; 23 Hurl files, 290 requests on :8089.

## B0 fix round
- Contract scripts: `tools/require-synthetic-stack.sh <project>` (one read-only count, the rule of `tools/data-load/test/require-synthetic.sh`) runs before any write on `dev` and `test`; `tools/prove-stack-guard.sh` proves it on the TEST stack only (passes, then refuses with a temporary non-.invalid user row, which it removes). Parity (MariaDB) is synthetic by construction and has no guard.
- Ports: dev ports are literal; `docker-compose.test.yml` overrides them for the test stack, so no shell variable moves either.
- Views are read-only for the API role (`DomainContexts.cs` revokes then grants SELECT on every view); db test added.
- Views were trimmed to the columns in each domain's `CLAUDE.md` "Published views" table. The `PublishedViews` migrations were edited in place (they are applied only to the test stack and Testcontainers, never to dev) and the test database was recreated (`remove`, `up`). `v_registrations` columns are a best reading of recon: re-check in B4.
- SqlBoundaryTests also catches quoted names and scans `shared/` and `hosts/` (no exemptions needed).
