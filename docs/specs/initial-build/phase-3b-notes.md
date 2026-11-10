# Phase 3b-1 notes: foundations for `membership` (2026-11-10)

Built, no HTTP operation (those are task 3b-2). Design: `phase-3-membership-design.md`; facts: `phase-3-membership-recon.md` (sections 3, 4).

## Built
- **Domain `domains/membership/`** (`MembershipModule`, `MembershipContext`, `CLAUDE.md`, tests project); in `hosts/api` (`Modules.cs`, `Program.cs`, csproj), `TsrApp.slnx`,
  `ModuleBoundaryTests`, `PublicSurfaceTests`. Dependencies: access, identity, platform.
- **Tables** (EF `Initial`, generated, unedited): `member_profiles`, `class_registrations` (index on `token`, no unique), `class_registrations_languages`, `interest_options`,
  `student_interests`, `user_guardians` (unique `code`). Text is citext with length CHECKs; PHP's enums and the `interests` SET are CHECKs; the two JSON columns are `jsonb`.
  Migration `SeedInterestOptions` (hand written SQL, like access's `CatalogFromPhp`).
- **identity:** public `UserDirectory` (`ByTokenAsync` every match, max 50; `ByIdsAsync` max 500, more throws) and `UserRef`; port `IProfileSink` (default no-op) called from
  `MemberDirectory` on create and on a verified-email claim; `FirebaseIdentity` now carries the token's `name` and `picture`; migration `DropUserGender` (generated).
- **platform:** `lookups` table (`AddLookups` generated, `SeedLookups` hand written: 72 options copied from PHP's migration); public `Lookups` and `Geo` (the postal slice now answers from `Geo`).
- **shared/api:** `MemberRateLimit` (bucket + token, caller supplies limit and window); `GeoGate` uses it (bucket `geo`, 60 per 60 s, same wording); `GeoRateLimit` deleted. New test project `shared/api/tests`.
- **membership:** `IClassEnrolments` (default `NoEnrolments`), public `MemberNames`, internal `ProfileSink`, `ProfileText.Cut`.
- **Seed:** `db/synthetic/seed.sql` (members 900201 to 900222: each gender form, a shared token, guardians in every status, duplicate registrations, languages, interests; gender of 900001 to 900003 moved to profiles).
  Parity: `tools/parity-php/membership-fixtures.sql` and `.sh` (resets its rows, refuses if a fixture touches a class). `operation-domains.csv`: the two `registrations/{id}` rows (classes, place) now `classes`.

## The two findings the brief did not expect
1. **No cycle, nothing to STOP on for the gender drop.** Access's gender scope never reads `identity.users.gender`: `AccessEngine.GenderOfRole` derives it from role 3 or 4 (PERM-R7, `access/CLAUDE.md`).
   The only readers of the column were identity's `User.Gender` (unused), `seed.sql`, `GeoTests.cs` and `FeedbackTests.cs` (all updated). Searched all of `*.cs`, `*.sql`, `*.sh`, `*.hurl`, `*.vars`, migrations, tests, tools, hosts.
2. **`interest_options` has 19 rows, not 12.** 12 was the original seed (`DB/2025_12_08`) and the size of the `interests` SET; PHP and its parity database hold 19 (ids, names, order, active flags). Seeded those 19 with PHP's ids
   (the id is what a client sends as `interestIds`). Compared with the parity database: lookups (72) and interest options (19) are byte-identical, ids included.

## Decisions I had to make (correct me)
1. **The drop loses data on a populated database.** `DropUserGender` is the only step; no cross-schema copy. Acceptable because no deployed database holds the new API's data (dev and parity are synthetic; the data move is a copy from PHP into both tables).
2. **Sign-in profile write is a second DbContext call, not one transaction** with the user insert. If it fails after the user row is committed, the next sign-in finds the member by uid and does not retry the name. Same request, as asked; atomic only with a shared context.
3. **Name and picture are cut to fit** (200 and 2000 characters) instead of failing the sign-in (PHP's strict DB would). Picture got a 2000 limit (PHP: mediumtext); a longer real value would be cut.
4. **Non-text `name`/`picture` claims are ignored**; PHP passes any value on.
5. **`UserDirectory.ByTokenAsync` returns every match**, capped at 50 (token 0 matches every guest); the cap truncates silently, the id batch limit throws.
6. **`MemberNames` leaves out** members with no profile row or an empty name.
7. **`Geo` holds primitives only** (`HasCountriesAsync`, `CountryByNameAsync`, `ByPostalCodeAsync`, `FromPostalCodeAsync`). PHP's `check()` and the personal-data regex are NOT in it: that rule is `PATCH /me`'s (3b-2), which decides .NET versus PCRE regex.
8. **`Lookups.LabelsAsync` throws for an unseeded type** (PHP `labelsOrFail`, a 500).
9. **Lookup ids 1 to 72** follow insert order, equal to PHP's; no `HasData`. `interest_options` ids are explicit and the sequence is moved after them.
10. **Tokens of the seed in the 9002xx range** shift the next created member token (max + 1) from about 900109 to 900223; no Hurl file hard-codes such a token (all 173 requests pass).
11. A CHECK on citext matches ignoring case; MariaDB's enum stored the listed spelling. Handlers in 3b-2 must store the canonical spelling.
12. `jsonb` for `field_of_study` and `professional_courses`: PHP's json_valid CHECK is implied; `jsonb` rewrites whitespace (`["A", "B"]`). Readers decode, so no visible change.
13. **Extra index** on `class_registrations_languages.token` (PHP has none; the form deletes and selects by token).
14. **`MemberRateLimit.TryAddSingleton`** in both platform and membership, so each module starts alone and they share one instance in the host.
15. Test project `shared/api/tests` carries the same `CA1716` NoWarn as the shared project (the namespace has `Shared`). No other suppression, no test skipped.

## Not test-first (said plainly)
- Red first, seen failing for the right reason: `MemberRateLimit` (13, `NotImplemented` stub), `FirebaseVerifier` name and picture (2 failed), `ProfileText` (4), and every db test (schema tests failed before the migrations existed; `ProfileSink`, `UserDirectory`, `MemberNames`, `Geo`, `Lookups` tests failed against throwing stubs: 27 failures, plus 3 mistakes in my own test code that I fixed).
- NOT red first: `ModuleBoundaryTests` and `PublicSurfaceTests` entries (edited together with the module); the seed files (`seed.sql`, `membership-fixtures.sql`: checked by running them, twice for idempotence, and by diffing lookups and interest options against the PHP side); the `GeoPostalHandler` refactor onto `Geo` (covered by the existing `GeoTests` and the platform Hurl files, which pass on both sides); documentation.
- `A_claim_whose_token_carries_neither_writes_no_profile_row` and the "no uid write" tests passed on first implementation (they test the absence of a write).

## Deferred
- All HTTP operations (3b-2). Erasure of membership data on account deletion (identity's command is not built). The search touch on `PATCH /me`.
- The personal-data check of `LocationModel::check()`. Guardian locks. `TSR_PUBLIC_WEB_BASE`.
- `MemberRateLimit` is per process (several API instances would each allow the full limit).

## Checks run
`dotnet build TsrApp.slnx`: 0 warnings, 0 errors. Tests: shared/api 13, platform 205, identity 63, access 64, membership 4, hosts/api 20, hosts/site 12, db 170, all passed.
Dev stack rebuilt from an empty volume (migrate and seed ran; seed run twice, second run inserted nothing): all Hurl files, 173 requests, 11 files passed.
Parity stack (`tools/parity-php/membership-fixtures.sh` first): identity 34 requests, access 77, platform 58, all passed. Run once each, 60 s apart in effect (geo budget).

# Phase 3b-2 notes: the ten membership operations (2026-11-10)

Design: `phase-3-membership-design.md`; facts: `phase-3-membership-recon.md` (sections 1, 2); findings and every quirk copied: `php-parity-feedback.md` ("Membership batch 3b-2"); behaviour today: `domains/membership/capabilities/{profile,class-request,guardian-links}.md`. Nothing committed.

## Built
- **Ten slices** under `domains/membership/api/features/`: `profile-get`, `profile-update`, `registration-get`, `registration-save`, `children-links`, `children-link-inspect`, `children-link-accept`, `children-link-revoke`, `parents-list`, `parent-revoke`. PHP's rules without a database are in `api/domain/` (`PhpText`, `PhpValue`, `JsonBody`, `ProfileFields`, `ProfileColumns`, `PlaceRules`, `PlaceCheck`, `RegistrationForm`, `RegistrationParts`, `RegistrationView`, `GuardianRules`, `GenderLock`, `GuardianLock`, `GuardianRevoker`, `LinkLister`, `LinkRowView`, `ProfileView`, `ProfileAnswer`, `BodyReader`, `Refusals`).
- **On other domains (public, because membership needs them):** `Permissions.RoleIdAsync` (access; `roleid` of `GET /me`), `UserDirectory.ByTokensAsync` and `MaxTokenMatches` (identity; one query for the names of a list's tokens).
- **Contract:** ten Hurl files in `domains/membership/spec/tests/` (one per slice), `spec/api.yaml`, `spec/glossary.md`, three capability documents, `tools/membership-contract.sh dev|parity [--prepare]`, gateway routes in `hosts/gateway/default.conf`, `MapMembership` in `hosts/api/Program.cs`.
- **Fixtures:** `db/synthetic/membership-fixtures.sql` (new file, `seed.sql` includes it) and `tools/parity-php/membership-fixtures.sql` hold the same 27 members and rows, and both RESET the rows they own (the contract files change them). Added: `accept.*`, `revoke.*`, `prevoke.*`, `profile.*`, `registrant.update`, a first name for `child.invited`.
- **db tests:** `RegistrationTests` (21), `GuardianTests` (25, including two concurrent accepts of two invites for one pair: exactly one 200, and it FAILS without the lock, checked by removing it), `ProfileTests` (36), `MembershipRightsTests` (6: the `tsr_app` role may read, insert, update and delete every table and take the advisory lock, may not change the schema; duplicates per token; unique code), `UserDirectoryTests` (+3). Unit: `domains/membership/api/tests` 274 (was 4).

## Decisions I had to make (correct me)
1. **`TSR_PUBLIC_WEB_BASE` not added**: none of the six guardian operations builds an invite link (that is the staff operation 10). It arrives with it.
2. **Search touch deferred**: PHP queues `outbound_messages` (channel search); that table does not exist here and nothing reads it. The platform `outbox` would be a different contract, so no row is written.
3. **`PhpText` and the JSON body reader are copied into membership**, not moved to `shared/api`: platform's are internal to platform (a slice or domain may not reach another domain's internals) and moving them is churn in a finished domain. Two small copies; worth a shared home when a third domain needs them.
4. **Advisory lock class 3001**, `pg_advisory_xact_lock(3001, child user id)`, taken inside a transaction before the locked checks; written in `GuardianLock` and in `domains/membership/CLAUDE.md`.
5. **`roleid` through a public `Permissions.RoleIdAsync`**, not through `ForUserAsync` (which has no role).
6. **The seed now resets the membership rows on every start.** The 3b-1 note "a second seed run inserts nothing" no longer holds for those rows (they are deleted and inserted again; users, other tables and geo are as before).
7. **The root all-files Hurl command needs a prepare step** (`tools/membership-contract.sh dev --prepare`) and `--variables-file build/dev/membership.vars`: the files accept invites and change profiles. 21 files, 273 requests.
8. **One fixture member per changed file.** Hurl `--test` runs files in parallel; `registration-save` first shared a member with `registration-get` (found in review, fixed with `registrant.update`).
9. **Lists capped at 200 rows, bodies at 1 MiB** (both new bounds, listed under deliberate differences).
10. **The inspect rate limit is in `MemberRateLimit` (per process)**, bucket `parent_invite_inspect`, 60 per 3600 s, PHP's wording.

## Deliberate differences (details in `php-parity-feedback.md`)
1 MiB body cap (413); 200-row cap and id tie-break on the guardian lists; first registration row by lowest id and interest ids ordered by id (PHP has no ORDER BY); gender lock reads the caller's profile by user id (PHP: by token, first row); .NET's HTML entity table; float text with 14 digits; postal regex on .NET with a 250 ms timeout; no member token in log lines; PHP's 403 text instead of the shared `Not allowed`; the 500s PHP renders as HTTP 200 with HTML are 500 here.

## Not test-first (said plainly)
- **Red first, seen failing for the right reason:** `UserDirectory.ByTokensAsync` (stub throwing: 3 failed); `PhpText`, `PhpValue`, `JsonBody`, `ProfileFields`, `PlaceRules`, `ProfileView`, `RegistrationForm`, `RegistrationParts` and `RegistrationView`, `GuardianRules`, `LinkRowView`, `ProfileColumns`, `GenderLock` (stubs throwing `NotImplementedException`: 76, 94, 45, 20, 21 and 13 failed before each was implemented); the `db/tests` for registration (18 of 21 failed with 404), guardians (23 of 25 failed with 404), profile (all 36 failed with 404). The lock is also proven by removing it (the concurrent test fails in round 0).
- **NOT red first:** the ten Hurl files (written after the code; run on PHP first as the oracle, then on the new API: green on the first run on dev, after fixing my own mistakes in the files, which PHP rejected: Hurl cannot compare arrays or objects, `nth` is wrong on a single filter match); `MembershipRightsTests` (written after the code); the gateway blocks, the fixtures and `tools/membership-contract.sh` (checked by running them); the documents.
- **My own test mistakes, fixed:** Iran is not in the geo fixtures (the regex-vouching case is db/tests only); 19 interest options are seeded but 16 are active; a label was "Doctorate (PhD / DPhil)"; a held-code case used a zip that the country regex matched; a JSON number read as `long`, not `int`; the `access.user_roles` column is `roleid`.
- Nothing skipped, no suppression added; the migrations' generated `#pragma` are 3b-1's.

## Deferred
- `TSR_PUBLIC_WEB_BASE`; the search touch; erasure of membership data on account deletion; the other 16 operations (`GET /me/children`, the staff parent-link operations 10 to 14, the registrations reports, place, reject, donors, cards, the access log).
- The gender lock against real enrolments (no classes): a fake port in NUnit, a host-level fake in `db/tests`, no Hurl case.
- The permission 403 end to end: nothing can deny a member-set permission, so only the code path exists.

## Checks run (this turn, final code)
`dotnet build TsrApp.slnx`: 0 warnings, 0 errors. NUnit: shared/api 13, platform 205, identity 63, access 64, membership 274, hosts/api 20, hosts/site 12, db 261, all passed.
Dev stack (rebuilt): membership 10 files and 100 requests, run twice, passed; all-files command (after the prepare step) 21 files, 273 requests, passed.
Parity stack: `tools/membership-contract.sh parity` 10 files, 100 requests, run twice, passed; identity 34 requests, access 77, platform 58 (60 s after the previous geo run), all passed. The parity stack was stopped afterwards; dev was left running. The inspect limit (60 an hour per member, kept by PHP across runs) allows about 15 more parity runs of the membership files an hour before `children-link-inspect.hurl` gets a 429.
