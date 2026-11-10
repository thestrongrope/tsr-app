# tsr-app

The Strong Rope's software: one product (a Flutter app and a public site) on one API, organized
by domain. This is a working sample of the target layout: `platform/submit-feedback` runs end to
end (spec, API slice, contract tests, Flutter screen, gateway); the other domains are structure.

Design: [`docs/specs/repo-structure.md`](docs/specs/repo-structure.md). Working rules for people
and AI agents: [`CLAUDE.md`](CLAUDE.md).

## Run it (Windows or Mac)

You need Docker, the .NET 10 SDK, Hurl (contract tests) and Flutter (3.38 or later). No Bash, no shared secret. Ports are published on 127.0.0.1 only.

```
docker compose -f docker-compose.dev.yml up -d --build   # PostgreSQL, API, gateway on :8088
hurl --test --glob "domains/*/spec/tests/*.hurl" --variable base_url=http://localhost:8088 --variable auth_header=X-Dev-Token --variable auth_value=900001   # contract tests (Hurl) against the stack
dotnet test domains/platform/api/tests                   # unit tests
dotnet test hosts/api/tests                              # module-boundary tests
dotnet test db/tests                                     # database-backed tests (Docker: a throwaway postgres:18)
flutter pub get                                          # the Dart workspace, at the root
cd domains/platform/app && flutter test                  # screen logic tests
dotnet run --project hosts/site                          # static site from the API, into build/site/
```

Try the API: `curl -X POST localhost:8088/feedback -H "X-Dev-Token: 900001" -H "Content-Type:
application/json" -d '{"clientId":"demo-1","text":"salaam"}'`. Token 900001 is a synthetic member.

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
