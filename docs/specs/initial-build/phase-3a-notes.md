# Phase 3a notes: five platform operations to PHP parity (2026-11-10)

Built: `GET /app-version`, `GET /release-notes` (public), `GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities` (signed in,
rate limited), the collation proof, and a migration dropping platform's two foreign keys into `identity.users`.
Facts on PHP: `php-parity-feedback.md` (last section). The access-log operations wait (design, decision 6).

## Where things are
- Code: `domains/platform/api/domain/` (`AppCatalog*`, `Geo*`, `PhpText`), `features/{app-version,release-notes,geo-countries,geo-postal,geo-cities}/`.
- Migrations: `AddGeo` (three tables, collation `public.geo_ci_ai`), `DropIdentityForeignKeys` (hand-written SQL).
- Fixtures: `db/synthetic/geo-fixtures.sql` (one file for PostgreSQL via `seed.sql` `\ir`, and MariaDB via `tools/platform-contract.sh parity`),
  `domains/platform/spec/tests/app_versions.synthetic.json` (mounted by `docker-compose.dev.yml` and, new, `tools/parity-php/compose.parity.yml`).
- Contract: `tools/platform-contract.sh dev|parity`; Hurl `app-version`, `release-notes`, `geo-countries`, `geo-postal`, `geo-cities`.
- Docs: `capabilities/{app-version,release-notes,location-lookup}.md`, `spec/api.yaml`, `spec/glossary.md`, `domains/platform/CLAUDE.md`.
- Gateway: five new `location =` blocks in `hosts/gateway/default.conf`.

## Decisions and assumptions (correct me)
1. **Collation lives in schema `public`**, not `platform`: Npgsql writes `COLLATE geo_ci_ai` unqualified in column definitions, and the first
   attempt (in `platform`) failed at migrate with "collation does not exist" (search_path). The first, failed migration was removed before it was ever applied.
2. **Length checks for the three collated columns** are declared in `PlatformContext` (`TsrConvention` adds them only to citext columns); the shared convention is unchanged.
3. **Only the missing-table database error is kept** (PHP swallowed all): logged at error level, empty answer.
4. **Geo contract uses member 900002** (`member.ladies`), created on the parity side by the script, so it does not share the 60-calls-a-minute
   budget with the all-files command (900001). The three geo files spend about 35 calls; running one side twice inside a minute gives a 429.
5. **Fixtures REPLACE the geo tables' content** (`DELETE` then `INSERT`), in dev and parity only. A full GeoNames load into the dev database would be wiped by a re-seed.
6. **`WebUtility.HtmlDecode` plus a numeric-reference pass** instead of a full HTML5 entity table (2,231 names). Differences are listed in the parity doc.
7. **Platform capabilities:** three documents, not five: app version, release notes, and one "location lookup" for the three geo operations.
8. **Dropping the foreign keys** means deleting an `identity.users` row no longer clears `feedback.user_id`; erasure is identity's event (not built).
   The capability doc and the phase 0 design row say so.
9. The all-files Hurl command already in `CLAUDE.md`/`README.md` needed no change (the brief's version used the removed `X-Dev-Token`); only the platform script was added.

## TDD honesty
- Red first (stub throwing, run, saw failures, then code): `AppCatalog` (107 failing), `PhpText`, `GeoBody`, `GeoField`, `GeoLookup`, `GeoRateLimit` (71 failing),
  and the foreign key guard (emptied the allow-list, saw `fk_feedback_*` fail, then the migration).
- NOT red first: the three geo handlers and `db/tests/GeoTests.cs` (HTTP and database level) were written after the handlers, against behaviour
  already confirmed on PHP by Hurl. I checked they can fail with one mutation (rate-limit gate disabled: 2 tests failed), then restored it.
  The `SchemaGuardTests` allow-list entries and the collation guard test were added with the migration, not run red.
- Two tests passed first time that I expected to need work (BOM and duplicate keys in `AppCatalog`); both agree with PHP 8.5 run in the parity container.
- One unit test was wrong (the recon's `"  AB  "` count); fixed to PHP's real behaviour.

## Not done / deferred
- The full GeoNames loader; `lookups` (no route); the access-log operations (waiting for membership).
- A test for the catalog size cap and for an empty city name (number 0).
- Rate limit per process: several API instances would each allow 60.
- Flutter: untouched.
