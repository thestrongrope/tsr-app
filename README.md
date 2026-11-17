# tsr-app

The Strong Rope's software: one product (a Flutter app and a public site) on one API, organized by domain.
The API is a C# rebuild of today's PHP API: all 219 of its operations are built here and checked against PHP by shared contract tests.
It is not deployed yet. What is built and last measured: [`docs/status.md`](docs/status.md). What the product does and what is still
missing: [`docs/specs/capability-map/README.md`](docs/specs/capability-map/README.md).

Design: [`docs/specs/repo-structure.md`](docs/specs/repo-structure.md). Working rules for people and AI agents: [`CLAUDE.md`](CLAUDE.md).

## Run it (Windows or Mac)

You need Docker, the .NET 11 SDK, Hurl (contract tests) and Flutter (3.38 or later). No shared secret. The scripts need Bash, curl and jq
(Git Bash on Windows). Ports are published on 127.0.0.1 only. The test stack's data is synthetic.

```
dotnet build TsrApp.slnx                                 # zero warnings is the rule
dotnet test hosts/api/tests                              # module-boundary tests (no database)
dotnet test db/tests                                     # database-backed tests (Docker: a throwaway postgres:18)
tools/test-stack.sh up                                   # the synthetic test stack: PostgreSQL, API, gateway on :8089
tools/identity-contract.sh test                          # sign a synthetic member in and run the sign-in contract
tools/platform-contract.sh test                          # one domain's contract; every other script and the full run: docs/testing.md
flutter pub get                                          # the Dart workspace, at the root
dotnet run --project hosts/site                          # static site from the API, into build/site/
```

Contract tests run only against the test stack, never against a dev stack that holds real data (`CLAUDE.md`, "Stacks").

Windows: enable long paths for Git (`git config --global core.longpaths true`) before cloning.

## Layout

```
domains/<context>/   spec/ (defined once), api/ (one implementation), app/ (screens), site/ (site pages)
hosts/               what runs or ships: api, gateway, app, site (scheduler later)
shared/              plumbing only: DB, outbox, HTTP client, theme, site API reader
db/                  one PostgreSQL database: synthetic seed, the limited API role (`init/`), database-backed tests (`tests/`); migrations live in each domain
docs/                specs and templates
```

Folders appear with their first real file; the full planned layout is in
`docs/specs/repo-structure.md`. Today's PHP API stays in tsr-account until routes move here.

## Licence

The code in this repository is licensed under the GNU Affero General Public License, version 3: see [LICENSE](LICENSE).
If you run a modified copy as a network service, you must offer its source to the people who use it.
