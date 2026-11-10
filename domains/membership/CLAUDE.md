# domains/membership/

Members' profiles, the class request form (registrations, languages, interests) and guardian links. Parity first: PHP's behaviour is
copied (facts: `docs/specs/initial-build/phase-3-membership-recon.md`; design: `phase-3-membership-design.md`; notes: `phase-3b-notes.md`).

## Status

| Part | State |
|---|---|
| Tables (schema `membership`): `member_profiles`, `class_registrations`, `class_registrations_languages`, `interest_options` (19 seeded), `student_interests`, `user_guardians` | built; migrations `Initial`, `SeedInterestOptions` |
| Sign-in profile sink (name and picture, same request) | built; `api/ProfileSink.cs`, supplies identity's `IProfileSink` |
| Public `MemberNames` (name by user ids, bounded) and port `IClassEnrolments` (default: not enrolled) | built |
| The ten HTTP operations: profile `GET` and `PATCH /me`, class request form `GET` and `POST /registration`, guardian self-service (links, inspect, accept, two revokes, parents) | built (task 3b-2), one slice each under `api/features/`; PHP parity proven by the Hurl files on both stacks. Gateway routes in `hosts/gateway/default.conf` |
| The other 16 operations (children list, staff parent links, waiting list, reject, reports, donors, cards) | wait for `classes` (design, "What is built now") |

## Owns

- Schema `membership` (above). `member_profiles` holds the profile columns PHP kept on `users`, keyed by identity's user id (plain integer, no
  foreign key). `gender` stays PHP's raw text (`'1'`, `'2'`, `'Male'`, `'Female'`, empty, NULL) so every PHP reading of it stays identical.
- Keys by member are plain integers; the one foreign key (`student_interests` to `interest_options`) stays inside the schema, as in PHP. Registrations
  have no unique token (duplicates exist; an update changes every row of a token). Guardian rules ("one active link per pair", "5 invites") have no key, only
  the lock the handlers take.
- PHP's enums and SET are text with CHECKs. The columns are `citext`, so a CHECK matches ignoring case (MariaDB's enums did too, but stored the listed spelling:
  a handler that stores a value must store the canonical spelling). The two JSON text columns are `jsonb`.
- Dependencies: `access`, `identity`, `platform` (`MembershipModule.Dependencies`). `classes` is not a dependency: it will supply `IClassEnrolments`.
- Events: none published, none consumed (PHP sends no notification and the search touch is deferred).

## Interfaces

| Interface | Direction |
|---|---|
| `MemberNames.ByUserIdsAsync(ids)` | public; users without a name are left out; more than 500 ids throws |
| `IClassEnrolments.IsEnrolledAsync(token)` | port declared here; `classes` supplies it; default `NoEnrolments` answers false |
| `IProfileSink` | declared by identity; `ProfileSink` here replaces identity's no-op. Register membership after identity |
| uses `UserDirectory` (identity: `ByTokenAsync`, `ByTokensAsync`, `ByIdsAsync`), `Geo`, `Lookups` (platform), `Permissions` (access: `CanAsync`, `RoleIdAsync`), `MemberRateLimit` (shared) | by the ten slices |
| advisory lock class 3001 (`pg_advisory_xact_lock(3001, child_user_id)`) | membership's guardian lock; no other code may use class 3001 |

## Where things are

| Need | File |
|---|---|
| A slice (endpoint, handler) | `api/features/<slice>/` (profile-get, profile-update, registration-get, registration-save, children-links, children-link-inspect, children-link-accept, children-link-revoke, parents-list, parent-revoke) |
| PHP's rules without a database (casts, validation, the form, link rules, views) | `api/domain/` (`PhpText`, `PhpValue`, `JsonBody`, `ProfileFields`, `PlaceRules`, `RegistrationForm`, `GuardianRules`, `GenderLock`, `LinkRowView`...), tests beside them |
| What a capability does today, with every quirk copied | `capabilities/profile.md`, `class-request.md`, `guardian-links.md` |
| Words, contract | `spec/glossary.md`, `spec/api.yaml`, `spec/tests/*.hurl` |
| The decisions and the findings of 3b-2 | `docs/specs/initial-build/phase-3b-notes.md`, `php-parity-feedback.md` ("Membership batch 3b-2") |

## Rules for this domain

- Parity first: PHP's answer, text, order and quirks are copied, never fixed here; a quirk is listed in the capability document and in `php-parity-feedback.md`.
- Slices are internal and never call each other; they share only `api/domain/`. Other domains are reached through `UserDirectory`, `Geo`, `Lookups` and `Permissions` only.
- Guardian writes that check then act take `GuardianLock` inside a transaction. "One active link per pair" and "five pending invites" have no key.
- A body is read with `BodyReader` and `JsonBody` (PHP's `api_body`, 1 MiB cap), never with minimal-API binding: a malformed body must be 422 `Invalid JSON body`.
- The 403 text is PHP's (`Refusals.NotPermitted`), not the shared `Problem.Forbidden`.
- Deferred: the search touch of `PATCH /me` (no `outbound_messages` table here), `TSR_PUBLIC_WEB_BASE` (arrives with the staff operation that builds an invite link), erasure on account deletion.

## Checks

```
dotnet test domains/membership/api/tests   # the pure rules, with PHP's edge cases (casts, validation, the form, link rules, the gender lock with a fake port)
dotnet test db/tests                       # schema, the sink, the ten operations through the API as the limited role, the lock, the role's rights (Docker)
tools/membership-contract.sh dev           # the ten Hurl files on the dev stack (resets the fixtures first); also: parity
tools/parity-php/membership-fixtures.sh    # only the fixture reset on the PHP parity stack (db/synthetic/membership-fixtures.sql holds the same rows for the new API)
```
