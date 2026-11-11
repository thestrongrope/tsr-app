| Tables `admin_access_log`, `genders`, `languages`, `outbound_messages` (schema phase) | - | built (tables only, no route; migration `AddQueueAndLookupTables`) |
# domains/platform/

The domain for things every member touches but no other domain owns: health, feedback, app version,
release notes and geo (countries, postal codes, cities), and (later) lookups and the audit log. This is the **one implemented
example**: copy its layout when you build another domain (`domains/CLAUDE.md`).

## Status

| Slice | Route | State |
|---|---|---|
| `health` | `GET /health` | built; process is up, does not check the DB |
| `submit-feedback` | `POST /feedback` | built; mirrors the PHP route in tsr-account, contract tests pass |
| review feedback (issue 891) | not designed | `feedback:review:all` exists in the catalog; no slice yet |
| `app-version` | `GET /app-version` | built; public; reads a JSON file, fails open; same answers as PHP (Hurl on both) |
| `release-notes` | `GET /release-notes` | built; public; same file and rules |
| `geo-countries` | `GET /geo/countries` | built; signed in, rate limited |
| `geo-postal` | `POST /geo/postal` | built; signed in, rate limited |
| `geo-cities` | `POST /geo/cities` | built; signed in, rate limited |
| `lookups` table, public `Lookups` and `Geo` read interfaces | - | built (no route); `membership` uses them | 
| `ReportExport` (public): xlsx and PDF report downloads for every domain | - | built (batch B5d); no route of its own; used by 9 classes and 3 membership download routes |
| access log (`GET /admin/access-log` and its download) | - | not started; PHP still serves it (waits for the report generator: phase-3-platform-design.md) |

## What it owns

- Tables `feedback`, `geo_countries`, `geo_postal_codes`, `geo_cities`, `lookups` (the 7 class request lists, 72 options, seeded from PHP), in schema `platform` (`api/PlatformContext.cs`; migrations in `api/Migrations/`).
- Permissions `feedback:create:self`, `feedback:review:all`
  (seeded by access's first migration; the catalog itself belongs to `access`).
- Event `platform.feedback_submitted`.
- Also, as platform tables with no domain: `outbox`, `outbound_messages`, `admin_access_log` (PHP's `schema_migrations` is not ported: EF's history tables replace it). `genders` and `languages` are their own tables here, not rows of `lookups`: other tables store their ids, so a straight copy is simpler (design decision 5). `outbound_messages` stays beside the outbox: the outbox holds domain events, `outbound_messages` the delivery queue (push, WhatsApp, search); its `payload` is JSON kept as text. `outbox` is mapped by `PlatformContext` (schema `platform`) and written inside the caller's transaction by `shared/api/Outbox.cs`.
- The geo tables hold public GeoNames data (CC BY 4.0), never member data; the dev seed holds a small synthetic set
  (`db/synthetic/geo-fixtures.sql`, shared with the PHP parity stack). The full GeoNames loader is not built.
- `feedback.user_id` and `handled_by` are plain integers (no foreign key to identity, rule 3).

## Public routes (no sign-in), and why

`GET /app-version` and `GET /release-notes` are marked `security: []` in `api.yaml` (domains/CLAUDE.md rule 4): an app
build old enough to need updating may hold an expired token, so the update prompt must not need one (PHP's reason,
kept). They return only the contents of one catalog file: build numbers, public store URLs, release notes and one
announcement; no member data. Both fail open: a missing or half-edited file gives permissive defaults, never an error.
The file path is the setting `TSR_APP_VERSIONS_FILE`.

## Geo: the written exception to "every text column is citext"

Three columns (`geo_countries.name`, `geo_postal_codes.postal_code`, `geo_cities.name`) use the ICU collation `geo_ci_ai`
(`und-u-ks-level1`, nondeterministic: ignores case AND accents, as MariaDB's collation did), because the lookups must
find "Zürich" for "zur" and sort accented names among plain ones. Proof, with the PostgreSQL 18 limits (no ILIKE, regex or
`starts_with` on these columns; LIKE and indexes work): `docs/specs/initial-build/phase-3-collation-proof.md`. The guard
test `db/tests/SchemaGuardTests.cs` lists the three with the reason. The collation lives in schema `public` (a column
definition names it unqualified). The geo rate limit (60 calls a minute per member, bucket `geo`) is `MemberRateLimit` in `shared/api` (in memory, per process); `GeoGate` supplies the limit and the wording.

## Published commands

`PlatformCommands.RecordAdminAccessAsync(db, httpContext, userId, token, roleId, ct)` (`api/PlatformCommands.cs`): PHP's `api_log_admin_action`. One `admin_access_log` row for a caller whose role is 1, 3, 4, 5 or 7 (path, method, client address, user agent, referer cut to the column lengths, no session id), written on the caller's connection outside a transaction; a failed write is logged and never fails the request. Used by `classes`; proved by `db/tests/AdminAuditTests.cs`.

## Report downloads (`ReportExport`)

PHP's `ReportExportModel` and `api_send_report_download`, one public class (`api/ReportExport.cs`; with `ReportFormat` and `ReportSection(heading, headers, rows)`). A download route calls `ReportExport.TryGetFormat` (and passes `ReportExport.FormatRefusal` as `RequireMember(precheck:)`, so a bad `?format=` is 422 BEFORE the sign-in, as PHP), then `export.DownloadAsync(format, title, sections, filenameBase, ct)`, which answers 200 with PHP's headers (`attachment; filename="X.xlsx"`), or 503 `{"detail": ...}` when the PDF renderer is down (PHP has no such answer). A file name is cut to letters, digits, space, `.`, `_`, `-`.

- **xlsx**: ClosedXML 0.105.1 (MIT; the only project that references it). Layout as PHP: bold title at 14, per section a bold heading, a bold header row, the rows, a blank row; ints and floats are numbers, everything else text (so a leading `=` is text, never a formula); null and "" leave no cell; sheet name = title with `[]:*?/\` as spaces, 31 characters. Differences: a cell is cut at 32767 characters (ClosedXML throws), control characters XML cannot carry are dropped, an empty sheet name is "Report".
- **PDF**: `domain/ReportHtml.cs` builds the page PHP gave Dompdf with every value HTML-encoded and no external resource; `domain/GotenbergRenderer.cs` posts it to Gotenberg (`POST /forms/chromium/convert/html`, A4 landscape, 60 s, 50 MB) through the one boundary interface `IPdfRenderer` (internal; the db tests swap it for a fake). Setting `TSR_GOTENBERG_URL` is **required**: the API refuses to start without an http(s) URL (the `--migrate` job needs none). The compose service `gotenberg` (image `gotenberg/gotenberg:8`, no published port, curl healthcheck) is in `docker-compose.dev.yml`.
- Tests: `domain/ReportXlsx.Tests.cs`, `ReportHtml.Tests.cs`, `GotenbergRenderer.Tests.cs`, `GotenbergSettings.Tests.cs`, `api/ReportExport.Tests.cs`; `hosts/api/tests/GotenbergSettingTests.cs`; the real renderer is proved by the Hurl download files on the test stack. Notes: `docs/specs/initial-build/fill-b5d-notes.md`.

## Public read interfaces

`Geo` (`HasCountriesAsync`, `CountryByNameAsync`, `ByPostalCodeAsync`, `FromPostalCodeAsync`, with `GeoCountryInfo` and `GeoPlace`) is the one geo lookup code: the postal code slice answers from it and `membership` validates a profile with it. A missing geo table answers "nothing" (logged), as PHP. `Lookups.LabelsAsync(type)` returns the active labels in display order and throws for an unseeded type (PHP `labelsOrFail`).

## Dependencies

`access` only (`PlatformModule.Dependencies`). Only feedback uses it. The app-version, release-notes and geo slices check no permission (PHP does not either: geo is open to any signed-in member), so they call nothing in `access`. Feedback uses it for `Permissions.CanAsync(caller, "feedback:create", AccessTarget.None, ct)` (an action has no scope). The caller comes from
`identity`'s middleware through `HttpContext.GetCaller()`; that is shared plumbing, not a
dependency.

## Where things are

| Need | File |
|---|---|
| Words to use (Feedback, Client id, Replay ...) | `spec/glossary.md` |
| The HTTP contract, field shapes and limits | `spec/api.yaml` |
| Events this domain publishes | "Events" below |
| Behaviour over HTTP, any implementation | `spec/tests/*.hurl` (needs the dev stack up) |
| The same contract on the PHP parity stack | `tools/platform-contract.sh dev|parity` |
| Module: registration, routes, dependencies | `api/PlatformModule.cs` |
| One use case end to end | `api/features/submit-feedback/SubmitFeedback.cs` |
| App version and release notes rules (the catalog file) | `api/domain/AppCatalog.cs`, `AppCatalogSource.cs` |
| Geo rules (body, fields, postal tries, LIKE, entities, rate limit) | `api/domain/Geo*.cs`, `PhpText.cs` |
| Report downloads (xlsx, PDF) | `api/ReportExport.cs`, `api/domain/ReportXlsx.cs`, `ReportHtml.cs`, `GotenbergRenderer.cs` |
| Rules shared by slices | `api/domain/` (`ClientId`, `FeedbackText`) |
| The feedback screen (Flutter) | `app/lib/features/submit_feedback/` |

## Events

Written to the `outbox` table in the same transaction as the change (`shared/api/Outbox.cs`).
Nothing relays or reads them yet (the relay comes with the foundation step), so this table replaces an AsyncAPI file
until a consumer exists. Payloads are camelCase JSON, like the API, and carry ids, never member text.

| Event type | When | Payload |
|---|---|---|
| `platform.feedback_submitted` | A new feedback row commits. A replay of the same `clientId` publishes nothing. | `feedbackId` (int ≥ 1), `userId` (int ≥ 1, `users.id`), `submittedAt` (UTC date-time, the API's clock) |

## Rules specific to this domain

1. **Feedback text counts Unicode code points**, like PHP `mb_strlen`, so both implementations
   accept and refuse the same messages. Do not switch to `string.Length` or grapheme counts.
2. **A replay is not a duplicate.** Same member + same `clientId` returns the stored id with 201.
   The unique key `(user_id, client_id)` is what makes this safe under concurrent sends.
3. **Events carry no message text.** `FeedbackSubmitted` has ids and a time only; the text is
   member content and stays in the `feedback` table.
4. If you change a limit, an error or a field, change `spec/` and `spec/tests` in the same edit,
   and check the PHP route still passes the contract tests.

## Checks

```
dotnet test domains/platform/api/tests            # unit
dotnet test db/tests                              # feedback row + outbox row in one transaction (Docker)
hurl --test --variable base_url=http://localhost:8088 --variables-file build/dev/token.vars domains/platform/spec/tests/submit-feedback.hurl   # contract, stack up (:8088)
flutter analyze domains/platform/app && (cd domains/platform/app && flutter test)
```

## Placeholders

Operations of this domain not built yet are 501 placeholders in `api/Planned.cs` (after the sign-in check; they create nothing). Building one deletes its line there and flips its state in `docs/specs/initial-build/operations.csv`.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_genders` | id, name | classes (class header, join preview) |
