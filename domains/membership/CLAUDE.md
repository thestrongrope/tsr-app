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
| Batch B4b, nine more operations: `GET /me/children`, the five staff parent-link routes (create invite, list, cancel, candidate, add by token), `POST /registrations/{id}/reject`, `GET /admin/donors`, `GET /subscribers/{token}` | built, one slice each under `api/features/` (`me-children`, `member-parent-link-create`, `member-parent-links`, `member-parent-link-cancel`, `member-parent-candidate`, `member-parents-add`, `registration-reject`, `admin-donors`, `subscriber-card`); notes `docs/specs/initial-build/fill-b4b-notes.md`. Fixtures `db/synthetic/membership-b4b-fixtures.sql` and `tools/parity-php/membership-b4b-fixtures.sql` (tokens 9011xx, classes 9561 to 9563), loaded by `tools/membership-contract.sh` |
| Batch B5b: `GET /reports/registrations` (the waiting list; slice `report-registrations`, Hurl `report-registrations.hurl`) and `GET /students/{token}` (slice `student-card`, shared rules `domain/CardRules.cs`; the level name comes from `classes.v_classes.level_name`); fixtures `db/synthetic/membership-b5b-fixtures.sql` and `tools/parity-php/membership-b5b-fixtures.sql` (tokens 9018xx); notes `docs/specs/initial-build/fill-b5b-notes.md` | built |
| Batch B5d: the three downloads `GET /reports/registrations/download`, `/reports/registrations/allocated/download` and `GET /admin/donors/download` (xlsx or PDF through platform's `ReportExport`; slices `report-registrations-download`, `report-registrations-allocated-download`, `admin-donors-download`; shared `domain/WaitingRegistrations.cs`, `AllocatedRegistrations.cs` (rules unit tested), `DonorList.cs`; Hurl files beside the others (the PDF cases in `*-new-api.hurl`); B5D fixtures `db/synthetic/membership-b5d-fixtures.sql` and `tools/parity-php/membership-b5d-fixtures.sql`, tokens 9021xx, the coordinator `b5d_coord`; db tests in `db/tests/ReportsB5dTests.cs`; notes `docs/specs/initial-build/fill-b5d-notes.md`). **Reach copied exactly:** the waiting list (screen and file) has no row scope beyond the gender, so a coordinator sees every waiting person of their gender (pinned by `ReportsB5bTests`, `ReportsB5dTests` and case 6 of `report-registrations.hurl`); the placed file gives a super or gender administrator every placed person of the gender, a coordinator only registrations naming a class of people placed in their assigned classes; the donors file lists every member in an active class with email and mobile (PHP applies no limit) | built |

## Owns

- Schema `membership` (above). `member_profiles` holds the profile columns PHP kept on `users`, keyed by identity's user id (plain integer, no
  foreign key). `gender` stays PHP's raw text (`'1'`, `'2'`, `'Male'`, `'Female'`, empty, NULL) so every PHP reading of it stays identical.
- Keys by member are plain integers; the one foreign key (`student_interests` to `interest_options`) stays inside the schema, as in PHP. Registrations
  have no unique token (duplicates exist; an update changes every row of a token). Guardian rules ("one active link per pair", "5 invites") have no key, only
  the lock the handlers take.
- PHP's enums and SET are text with CHECKs. The columns are `citext`, so a CHECK matches ignoring case (MariaDB's enums did too, but stored the listed spelling:
  a handler that stores a value must store the canonical spelling). The two JSON text columns are `jsonb`.
- Dependencies: `access`, `identity`, `platform` (`MembershipModule.Dependencies`; platform for `Geo`, `Lookups` and `ReportExport`). `classes` is not a dependency: it will supply `IClassEnrolments`.
- Events (outbox, same transaction as the change; none consumed; a refusal or no-op writes none):

| Event | Payload | Written by |
|---|---|---|
| `membership.member_created` | token | `MembershipCommands.CreateProfileAsync` |
| `membership.member_contact_changed` | token, nameChanged | `MembershipCommands.ChangeContactAsync` |
| `membership.parent_invite_created` | inviteId, childToken, createdBy (never the code) | POST /members/{child_token}/parent-links |
| `membership.parent_invite_cancelled` | inviteId, childToken, cancelledBy | DELETE /members/{child_token}/parent-links/{id} |
| `membership.parent_link_added` | linkId, parentToken, childToken, relationship, createdBy | POST /members/{child_token}/parents |
| `membership.registration_rejected` | registrationId, token, rejectedBy | POST /registrations/{id}/reject |

  PHP sends no notification for any of them.

## Interfaces

| Interface | Direction |
|---|---|
| `MemberNames.ByUserIdsAsync(ids)` | public; users without a name are left out; more than 500 ids throws |
| `IClassEnrolments.IsEnrolledAsync(token)` | port declared here; `classes` supplies it; default `NoEnrolments` answers false |
| `IProfileSink` | declared by identity; `ProfileSink` here replaces identity's no-op. Register membership after identity |
| uses `UserDirectory` (identity: `ByTokenAsync`, `ByTokensAsync`, `ByIdsAsync`), `Geo`, `Lookups` (platform), `Permissions` (access: `CanAsync`, `ReachAsync`, `RoleIdAsync`), `MemberRateLimit` (shared) | by the ten slices |
| advisory lock class 3001 (`pg_advisory_xact_lock(3001, child_user_id)`) | membership's guardian lock; no other code may use class 3001 |

## Published commands

`MembershipCommands.RecordAcceptedRegistrationAsync(db, token, classId, ct)` (`api/MembershipCommands.cs`): PHP `writeEnrolment`'s first step. A member with no `class_registrations` row gets an Accepted one naming the class; a member with any row keeps it. Runs on the caller's transaction (it throws outside one). Used by `classes` (add, join, place); proved by `db/tests/EnrolmentWritesTests.cs`.

`MembershipCommands.ChangeContactAsync(db, token, name, mobile, clock, ct)` (`api/MembershipCommands.cs`): PHP `updateStudentInClass`'s write of name (only when given; null leaves it) and mobile (always overwritten, empty included) on every profile row of the token. Validates its inputs (`MaxNameLength` 200, `MaxMobileLength` 100, throws), runs on the caller's transaction, writes the event `membership.member_contact_changed` (token, nameChanged). Used by `classes` (edit a student); proved by `db/tests/StudentEditTests.cs`.

`MembershipCommands.CreateProfileAsync(db, token, name, gender, mobile, clock, ct)` (`api/MembershipCommands.cs`): the profile of a member just created by identity's `CreateMemberAsync`: name, gender (the class's number as text) and mobile (may be empty), nothing else. Throws for an unknown token, an over-long value or no transaction. Writes the event `membership.member_created` (token). Used by `classes` (bulk add); proved by `db/tests/BulkAddTests.cs`.

## Where things are

| Need | File |
|---|---|
| A slice (endpoint, handler) | `api/features/<slice>/` (the nine B4b slices above, link-account (`POST /auth/link`: `{"me": <the GET /me answer>}`, no permission checked, as PHP), profile-get, profile-update, registration-get, registration-save, children-links, children-link-inspect, children-link-accept, children-link-revoke, parents-list, parent-revoke) |
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
- Deferred: the search touch of `PATCH /me` (no `outbound_messages` table here), erasure on account deletion. `TSR_PUBLIC_WEB_BASE` (configuration; unset means no base, as PHP without `REDIRECT_URI`) prefixes the invite link of `POST /members/{child_token}/parent-links`.

## Checks

```
dotnet test domains/membership/api/tests   # the pure rules, with PHP's edge cases (casts, validation, the form, link rules, the gender lock with a fake port)
dotnet test db/tests                       # schema, the sink, the nineteen operations through the API as the limited role, the lock, the role's rights (Docker)
tools/membership-contract.sh test          # the 20 Hurl files (19 on parity) on the TEST stack (resets the fixtures first); also: parity
tools/parity-php/membership-fixtures.sh    # only the fixture reset on the PHP parity stack (db/synthetic/membership-fixtures.sql holds the same rows for the new API)
```

## Placeholders

Every operation of this domain is built, so there is no `api/Planned.cs` any more.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_members` | token, user_id, name, mobile, gender (raw text), city, state, country, zip | classes (teacher and student names, contact, gender), assessment (the caller's gender: api_require_identity), assessment reports, platform (access log: names) |
| `v_registrations` | id, token, for_classid, class_level, class_number, preferred_location, status, created_at | classes (waiting list, placement); columns to re-check in B4 |
| `v_guardian_links` | id, parent_token, child_token, status | classes (children routes: active link), assessment (the child scores route) |

This domain's SQL reads `classes.v_enrolments`, `classes.v_classes` (children's classes, waiting registrant, donors, reach, cards) and `identity.v_users`. `classes` already lists membership as a reader of its own views; `MembershipModule.Dependencies` is unchanged (`access`, `identity`, `platform`).
