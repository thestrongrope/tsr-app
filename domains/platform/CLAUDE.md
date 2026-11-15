# domains/platform/

The domain for things every member touches but no other domain owns: health, feedback, app version,
release notes, geo (countries, postal codes, cities), lookups, the audit log, the delivery queue and report downloads.
This is the **one implemented example**: copy its layout when you build another domain (`domains/CLAUDE.md`).

## Status

Every platform operation is built (`api/Planned.cs` is gone).

| Slice | Route | State |
|---|---|---|
| `health` | `GET /health` | built; process is up, does not check the DB |
| `submit-feedback` | `POST /feedback` | built; mirrors the PHP route in tsr-account |
| review feedback (issue 891) | not designed | `feedback:review:all` exists in the catalog; no slice yet |
| `app-version` | `GET /app-version` | built; public; reads a JSON file, fails open; same answers as PHP |
| `release-notes` | `GET /release-notes` | built; public; same file and rules |
| `geo-countries`, `geo-postal`, `geo-cities` | `GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities` | built; signed in, rate limited |
| `admin-access-log`, `admin-access-log-download` | `GET /admin/access-log`, `.../download` | built; `audit-log:read`; shared query `api/domain/AccessLog.cs` |
| `lookups` table, public `Lookups` and `Geo` read interfaces | - | built (no route); `membership` uses them |
| `ReportExport` (public): xlsx and PDF report downloads for every domain | - | built; no route of its own; used by 9 classes and 3 membership download routes |
| Tables `admin_access_log`, `genders`, `languages`, `outbound_messages` | - | built (tables only, no route; migration `AddQueueAndLookupTables`) |

## What it owns

- Tables `feedback`, `geo_countries`, `geo_postal_codes`, `geo_cities`, `lookups` (the 7 class request lists, 72 options, seeded from PHP), in schema `platform` (`api/PlatformContext.cs`; migrations in `api/Migrations/`).
- Permissions `feedback:create:self`, `feedback:review:all` (seeded by access's first migration; the catalog itself belongs to `access`).
- As platform tables with no domain: `outbox`, `outbound_messages`, `admin_access_log` (PHP's `schema_migrations` is not ported: EF's history tables replace it). `outbox` holds domain events and is written inside the caller's transaction by `shared/api/Outbox.cs`; `outbound_messages` is the delivery queue (push, WhatsApp, search), its `payload` JSON kept as text.
- `genders` and `languages` are their own tables here, not rows of `lookups`: other tables store their ids, so a straight copy is simpler (design decision 5).
- The geo tables hold public GeoNames data (CC BY 4.0), never member data; the dev seed holds a small synthetic set (`db/synthetic/geo-fixtures.sql`, shared with the PHP parity stack). The full GeoNames loader is not built.
- `feedback.user_id` and `handled_by` are plain integers (no foreign key to identity, rule 3).

## Public routes (no sign-in), and why

`GET /app-version` and `GET /release-notes` are marked `security: []` in `api.yaml` (domains/CLAUDE.md rule 4): an app
build old enough to need updating may hold an expired token, so the update prompt must not need one (PHP's reason,
kept). They return only the contents of one catalog file (setting `TSR_APP_VERSIONS_FILE`): no member data. Both fail
open: a missing or half-edited file gives permissive defaults, never an error. Details: `capabilities/app-version.md`.

## Geo: the written exception to "every text column is citext"

Three columns (`geo_countries.name`, `geo_postal_codes.postal_code`, `geo_cities.name`) use the ICU collation `geo_ci_ai`
(`und-u-ks-level1`, nondeterministic: ignores case AND accents, as MariaDB's collation did), because the lookups must
find "Zürich" for "zur" and sort accented names among plain ones. PostgreSQL 18 limits: no ILIKE, regex or
`starts_with` on these columns; LIKE and indexes work. Proof: `docs/specs/initial-build/phase-3-collation-proof.md`;
guard test `db/tests/SchemaGuardTests.cs`. The collation lives in schema `public` (a column definition names it
unqualified). The geo rate limit (60 calls a minute per member, bucket `geo`) is `MemberRateLimit` in `shared/api` (in
memory, per process); `GeoGate` supplies the limit and the wording.

## Published commands

Static methods of `PlatformCommands`; the doc comment of each states its SQL and PHP source.

- `RecordAdminAccessAsync(db, httpContext, userId, token, roleId, ct)` (`api/PlatformCommands.cs`): PHP's `api_log_admin_action`. One `admin_access_log` row for a caller whose role is 1, 3, 4, 5 or 7, written outside a transaction; a failed write is logged and never fails the request. Used by `classes`; proved by `db/tests/AdminAuditTests.cs`.
- `QueueMessagesAsync` (queues `outbound_messages` rows, sends nothing; used by `notifications`), `EraseFeedbackAsync` and `RedactRecipientsAsync` (account deletion; used by `identity`): same file.
- `ClaimMessagesAsync`, `MarkSentAsync`, `MarkFailedAsync`, `ReleaseMessageAsync`, `MarkDeadAsync` (`api/PlatformCommands.Queue.cs`): the delivery queue, below. Used by `notifications` (the push drain); proved by `db/tests/TestPushDrainTests.cs`.

**The delivery queue for a worker** (column `outbound_messages.claimed_at`, migration `AddOutboundClaimedAt`). Each
command is ONE statement on the caller's connection, outside a transaction (a claim commits before anything is sent; a
claim is two statements); the clock is passed in. Decisions that differ from PHP:

- A row left `sending` with `claimed_at` older than 10 minutes (`ClaimLease`) is reclaimed. PHP leaves a crashed claim stuck for ever; we reclaim it and accept a rare duplicate (the owner's decision). A `sending` row with no `claimed_at`, from before the column, is never reclaimed.
- A stale `sending` row that has already used its 5 attempts becomes `dead` with `reclaim_exhausted` instead of being claimed again.
- Every result command is guarded on `status = 'sending'` AND the `attempts` the claim returned, so a worker whose row was reclaimed changes nothing (false or null).
- `error` holds a short reason code only.

The backoff (60, 300, 900, 3600 s; dead after the 5th) and the rest: the doc comments in `api/PlatformCommands.Queue.cs`.

## Report downloads (`ReportExport`)

PHP's `ReportExportModel` and `api_send_report_download`, one public class (`api/ReportExport.cs`; with `ReportFormat` and `ReportSection(heading, headers, rows)`). The report downloads of every domain go through it.

A download route calls `ReportExport.TryGetFormat` (and passes `ReportExport.FormatRefusal` as `RequireMember(precheck:)`, so a bad `?format=` is 422 BEFORE the sign-in, as PHP), then `export.DownloadAsync(format, title, sections, filenameBase, ct)`, which answers 200 with PHP's headers (`attachment; filename="X.xlsx"`), or 503 `{"detail": ...}` when the PDF renderer is down (PHP has no such answer). A file name is cut to letters, digits, space, `.`, `_`, `-`.

- **xlsx**: ClosedXML 0.105.1 (MIT; the only project that references it). Layout as PHP; ints and floats are numbers, everything else text (so a leading `=` is text, never a formula). The layout and the three differences from PHP (a cell cut at 32767 characters, control characters dropped, an empty sheet name is "Report"): `api/domain/ReportXlsx.cs`.
- **PDF**: `domain/ReportHtml.cs` builds the page PHP gave Dompdf with every value HTML-encoded and no external resource; `domain/GotenbergRenderer.cs` posts it to Gotenberg (A4 landscape, 60 s, 50 MB) through the one boundary interface `IPdfRenderer` (internal; the db tests swap it for a fake).
- Setting `TSR_GOTENBERG_URL` is **required**: the API refuses to start without an http(s) URL (the `--migrate` job needs none). The compose service `gotenberg` (image `gotenberg/gotenberg:8`, no published port, curl healthcheck) is in `docker-compose.dev.yml`.
- Tests: `domain/ReportXlsx.Tests.cs`, `ReportHtml.Tests.cs`, `GotenbergRenderer.Tests.cs`, `GotenbergSettings.Tests.cs`, `api/ReportExport.Tests.cs`; `hosts/api/tests/GotenbergSettingTests.cs`; the real renderer is proved by the Hurl download files on the test stack. Notes: `docs/specs/initial-build/fill-b5d-notes.md`.

## Public read interfaces

`Geo` (`HasCountriesAsync`, `CountryByNameAsync`, `ByPostalCodeAsync`, `FromPostalCodeAsync`, with `GeoCountryInfo` and `GeoPlace`) is the one geo lookup code: the postal code slice answers from it and `membership` validates a profile with it. A missing geo table answers "nothing" (logged), as PHP. `Lookups.LabelsAsync(type)` returns the active labels in display order and throws for an unseeded type (PHP `labelsOrFail`).

## Dependencies

`access`, `membership`, `identity` (`PlatformModule.Dependencies`). `access`: feedback (`Permissions.CanAsync(caller, "feedback:create", AccessTarget.None, ct)`; an action has no scope) and the access log (`audit-log:read`). `membership` and `identity` are read through their views only, by the access log (`membership.v_members` for the name, `identity.v_users` for the email). The app-version, release-notes and geo slices check no permission (PHP does not either: geo is open to any signed-in member). The caller comes from `identity`'s middleware through `HttpContext.GetCaller()`; that is shared plumbing, not a dependency.

## Where things are

| Need | File |
|---|---|
| What a capability does today | `capabilities/*.md` |
| Words to use (Feedback, Client id, Replay ...) | `spec/glossary.md` |
| The HTTP contract, field shapes and limits | `spec/api.yaml` |
| Behaviour over HTTP, any implementation | `spec/tests/*.hurl` (needs the test stack up) |
| The same contract on the new API or on the PHP parity stack | `tools/platform-contract.sh test` or `parity` |
| Module: registration, routes, dependencies | `api/PlatformModule.cs` |
| One use case end to end | `api/features/submit-feedback/SubmitFeedback.cs` |
| App version and release notes rules (the catalog file) | `api/domain/AppCatalog.cs`, `AppCatalogSource.cs` |
| Geo rules (body, fields, postal tries, LIKE, entities, rate limit) | `api/domain/Geo*.cs`, `PhpText.cs` |
| Report downloads (xlsx, PDF) | `api/ReportExport.cs`, `api/domain/ReportXlsx.cs`, `ReportHtml.cs`, `GotenbergRenderer.cs` |
| Rules shared by slices | `api/domain/` (`ClientId`, `FeedbackText`) |
| The feedback screen (Flutter) | `app/lib/features/submit_feedback/` |
| Background notes (the access log) | `docs/specs/initial-build/lane-small-notes.md` |

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
hurl --test --variable base_url=http://localhost:8089 --variables-file build/test/token.vars domains/platform/spec/tests/submit-feedback.hurl   # contract, test stack up (:8089)
flutter analyze domains/platform/app && (cd domains/platform/app && flutter test)
```

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_genders` | id, name | classes (class header, join preview) |
