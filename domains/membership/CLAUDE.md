# domains/membership/

Members' profiles, the class request form (registrations, languages, interests) and guardian links. Parity first: PHP's behaviour is
copied (facts: `docs/specs/initial-build/phase-3-membership-recon.md`; design: `phase-3-membership-design.md`; notes: `phase-3b-notes.md`).

## Status

Every operation is built (no `api/Planned.cs`), one slice each under `api/features/`; each slice's header comment names its route, permission and PHP source. Shapes: `spec/api.yaml`. Gateway routes: `hosts/gateway/default.conf`.

| Group | Slices |
|---|---|
| First call after sign-in | `link-account` (`POST /auth/link`: `{"me": <the GET /me answer>}`, no permission checked, as PHP) |
| Profile, class request form, guardian self-service | 10; what each does today: `capabilities/profile.md`, `class-request.md`, `guardian-links.md` |
| A parent's children and the staff parent links | 6: `me-children`, `member-parent-*` |
| Staff reads and the reject | 5: `registration-reject`, `admin-donors`, `subscriber-card`, `student-card` (rules in `domain/CardRules.cs`; the level name comes from `classes.v_classes.level_name`), `report-registrations` (the waiting list) |
| Downloads (xlsx or PDF through platform's `ReportExport`) | 3: `report-registrations-download`, `report-registrations-allocated-download`, `admin-donors-download` |

**Reach copied exactly:** the waiting list (screen and file) has no row scope beyond the gender, so a coordinator sees every waiting person of their gender (pinned by `ReportsB5bTests`, `ReportsB5dTests` and case 6 of `report-registrations.hurl`); the placed file gives a super or gender administrator every placed person of the gender, a coordinator only registrations naming a class of people placed in their assigned classes; the donors file lists every member in an active class with email and mobile (PHP applies no limit).

## Owns

- Schema `membership`: `member_profiles`, `class_registrations`, `class_registrations_languages`, `interest_options` (19 seeded), `student_interests`, `user_guardians` (migrations `Initial`, `SeedInterestOptions`). `member_profiles` holds the profile columns PHP kept on `users`, keyed by identity's user id (plain integer, no
  foreign key). `gender` stays PHP's raw text (`'1'`, `'2'`, `'Male'`, `'Female'`, empty, NULL) so every PHP reading of it stays identical.
- Keys by member are plain integers; the one foreign key (`student_interests` to `interest_options`) stays inside the schema, as in PHP. Registrations
  have no unique token (duplicates exist; an update changes every row of a token). Guardian rules ("one active link per pair", "5 invites") have no key, only
  the lock the handlers take.
- PHP's enums and SET are text with CHECKs. The columns are `citext`, so a CHECK matches ignoring case (MariaDB's enums did too, but stored the listed spelling:
  a handler that stores a value must store the canonical spelling). The two JSON text columns are `jsonb`.

## Dependencies

`access`, `identity`, `platform` (`MembershipModule.Dependencies`; platform for `Geo`, `Lookups` and `ReportExport`). `classes` is not a dependency: it will supply `IClassEnrolments`.

This domain's SQL reads `classes.v_enrolments`, `classes.v_classes` (children's classes, waiting registrant, donors, reach, cards) and `identity.v_users`. `classes` already lists membership as a reader of its own views.

## Interfaces

| Interface | Direction |
|---|---|
| `MemberNames.ByUserIdsAsync(ids)` | public; users without a name are left out; more than 500 ids throws |
| `IClassEnrolments.IsEnrolledAsync(token)` | port declared here; `classes` supplies it; default `NoEnrolments` answers false |
| `IProfileSink` | declared by identity; `ProfileSink` here (`api/ProfileSink.cs`: name and picture at sign-in, same request) replaces identity's no-op. Register membership after identity |
| uses `UserDirectory` (identity: `ByTokenAsync`, `ByTokensAsync`, `ByIdsAsync`), `Geo`, `Lookups` (platform), `Permissions` (access: `CanAsync`, `ReachAsync`, `RoleIdAsync`), `MemberRateLimit` (shared) | by the slices |
| advisory lock class 3001 (`pg_advisory_xact_lock(3001, child_user_id)`) | membership's guardian lock; no other code may use class 3001 |

## Published commands (`api/MembershipCommands.cs`)

Each runs on the caller's transaction and throws outside one. The two that take a name and a mobile validate them and throw (`MaxNameLength` 200, `MaxMobileLength` 100). The doc comment of each says what it writes.

| Command | Used by | Proved by |
|---|---|---|
| `RecordAcceptedRegistrationAsync(db, token, classId, ct)`: PHP `writeEnrolment`'s first step | `classes` (add, join, place) | `db/tests/EnrolmentWritesTests.cs` |
| `ChangeContactAsync(db, token, name, mobile, clock, ct)`: PHP `updateStudentInClass`'s write of name and mobile | `classes` (edit a student) | `db/tests/StudentEditTests.cs` |
| `CreateProfileAsync(db, token, name, gender, mobile, clock, ct)`: the profile of a member just created by identity's `CreateMemberAsync` | `classes` (bulk add) | `db/tests/BulkAddTests.cs` |

## Rules for this domain

- Parity first: PHP's answer, text, order and quirks are copied, never fixed here; a quirk is listed in the capability document and in `php-parity-feedback.md`.
- Slices share only `api/domain/`. Other domains are reached through `UserDirectory`, `Geo`, `Lookups` and `Permissions` only.
- Guardian writes that check then act take `GuardianLock` inside a transaction. "One active link per pair" and "five pending invites" have no key.
- A body is read with `BodyReader` and `JsonBody` (PHP's `api_body`, 1 MiB cap), never with minimal-API binding: a malformed body must be 422 `Invalid JSON body`.
- The 403 text is PHP's (`Refusals.NotPermitted`), not the shared `Problem.Forbidden`.
- Deferred: the search touch of `PATCH /me` (no `outbound_messages` table here), erasure on account deletion.
- Fixtures: `tools/membership-contract.sh` resets its fixture rows before each run (root `CLAUDE.md`); ids, members and sharing rules are in each fixture file's header.

## Settings

| Setting | Meaning |
|---|---|
| `TSR_PUBLIC_WEB_BASE` | configuration; unset means no base, as PHP without `REDIRECT_URI`. Prefixes the invite link of `POST /members/{child_token}/parent-links` |

## Where things are

| Need | File |
|---|---|
| A slice (endpoint, handler) | `api/features/<slice>/` |
| PHP's rules without a database (casts, validation, the form, link rules, views) | `api/domain/` (`ProfileFields`, `PlaceRules`, `RegistrationForm`, `GuardianRules`, `GenderLock`, `LinkRowView`...), tests beside them |
| The lists behind the downloads | `api/domain/WaitingRegistrations.cs`, `AllocatedRegistrations.cs` (rules unit tested), `DonorList.cs` |
| What a capability does today, with every quirk copied | `capabilities/profile.md`, `class-request.md`, `guardian-links.md` |
| Words, contract | `spec/glossary.md`, `spec/api.yaml`, `spec/tests/*.hurl` (the PDF cases of the downloads in `*-new-api.hurl`) |
| Fixtures (the same rows for PHP under the same name in `tools/parity-php/`) | `db/synthetic/membership-fixtures.sql`, `membership-b4b-fixtures.sql`, `membership-b5b-fixtures.sql`, `membership-b5d-fixtures.sql` |
| Database tests | `db/tests/Membership*Tests.cs`, `ProfileTests.cs`, `ProfileSinkTests.cs`, `RegistrationTests.cs`, `GuardianTests.cs`, `ReportsB5bTests.cs`, `ReportsB5dTests.cs` |
| Decisions, findings and notes | `docs/specs/initial-build/phase-3b-notes.md`, `php-parity-feedback.md` ("Membership batch 3b-2"), `fill-b4b-notes.md`, `fill-b5b-notes.md`, `fill-b5d-notes.md` |

## Checks

```
dotnet test domains/membership/api/tests   # the pure rules, with PHP's edge cases (casts, validation, the form, link rules, the gender lock with a fake port)
dotnet test db/tests                       # schema, the sink, the operations through the API as the limited role, the lock, the role's rights (Docker)
tools/membership-contract.sh test          # the Hurl files on the TEST stack (resets the fixtures first); also: parity
tools/parity-php/membership-fixtures.sh    # only the fixture reset on the PHP parity stack (db/synthetic/membership-fixtures.sql holds the same rows for the new API)
```

## Events (outbox, same transaction as the change; none consumed; a refusal or no-op writes none)

| Event | Payload | Written by |
|---|---|---|
| `membership.member_created` | token | `MembershipCommands.CreateProfileAsync` |
| `membership.member_contact_changed` | token, nameChanged | `MembershipCommands.ChangeContactAsync` |
| `membership.parent_invite_created` | inviteId, childToken, createdBy (never the code) | POST /members/{child_token}/parent-links |
| `membership.parent_invite_cancelled` | inviteId, childToken, cancelledBy | DELETE /members/{child_token}/parent-links/{id} |
| `membership.parent_link_added` | linkId, parentToken, childToken, relationship, createdBy | POST /members/{child_token}/parents |
| `membership.registration_rejected` | registrationId, token, rejectedBy | POST /registrations/{id}/reject |

PHP sends no notification for any of them.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_members` | token, user_id, name, mobile, gender (raw text), city, state, country, zip | classes (teacher and student names, contact, gender), assessment (the caller's gender: api_require_identity), assessment reports, platform (access log: names) |
| `v_registrations` | id, token, for_classid, class_level, class_number, preferred_location, status, created_at | classes (waiting list, placement); columns to re-check in B4 |
| `v_guardian_links` | id, parent_token, child_token, status | classes (children routes: active link), assessment (the child scores route) |
